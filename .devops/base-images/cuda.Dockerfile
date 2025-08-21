ARG UBUNTU_VERSION=22.04
# This needs to generally match the container host's environment.
ARG CUDA_VERSION=12.4.0
# Target the CUDA build image
ARG BASE_CUDA_DEV_CONTAINER=nvidia/cuda:${CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION}

ARG BASE_CUDA_RUN_CONTAINER=nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu${UBUNTU_VERSION}

FROM ${BASE_CUDA_DEV_CONTAINER} AS build

# CUDA architecture to build for (defaults to all supported archs)
ARG CUDA_DOCKER_ARCH=default

# BodhiApp: Version metadata build arguments
ARG BUILD_VERSION
ARG BUILD_COMMIT
ARG BUILD_TIMESTAMP
ARG BUILD_BRANCH

RUN apt-get update && \
    apt-get install -y build-essential cmake python3 python3-pip git libcurl4-openssl-dev libgomp1

WORKDIR /app

COPY . .

RUN if [ "${CUDA_DOCKER_ARCH}" != "default" ]; then \
    export CMAKE_ARGS="-DCMAKE_CUDA_ARCHITECTURES=${CUDA_DOCKER_ARCH}"; \
    fi && \
    cmake -B build -DGGML_NATIVE=OFF -DGGML_CUDA=ON -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON -DLLAMA_BUILD_TESTS=OFF ${CMAKE_ARGS} -DCMAKE_EXE_LINKER_FLAGS=-Wl,--allow-shlib-undefined . && \
    cmake --build build --config Release -j$(nproc)

RUN mkdir -p /app/lib && \
    find build -name "*.so" -exec cp {} /app/lib \;

# BodhiApp: Create BodhiApp-compatible folder structure (CUDA is x86_64 only)
RUN PLATFORM_TRIPLE="x86_64-unknown-linux-gnu" && \
    mkdir -p /app/bin/$PLATFORM_TRIPLE/cuda && \
    cp build/bin/llama-server /app/bin/$PLATFORM_TRIPLE/cuda/ && \
    cp /app/lib/*.so /app/bin/$PLATFORM_TRIPLE/cuda/ 2>/dev/null || true

# BodhiApp: Add CPU variant build stage
FROM ubuntu:${UBUNTU_VERSION} AS build-cpu
ARG BUILD_VERSION
ARG BUILD_COMMIT
ARG BUILD_TIMESTAMP
ARG BUILD_BRANCH

RUN apt-get update && apt-get install -y build-essential git cmake libcurl4-openssl-dev

WORKDIR /app
COPY . .

RUN cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DGGML_NATIVE=OFF -DLLAMA_BUILD_TESTS=OFF -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON && \
    cmake --build build -j $(nproc)

# BodhiApp: Create CPU variant folder structure
RUN PLATFORM_TRIPLE="x86_64-unknown-linux-gnu" && \
    mkdir -p /app/bin/$PLATFORM_TRIPLE/cpu && \
    cp build/bin/llama-server /app/bin/$PLATFORM_TRIPLE/cpu/ && \
    find build -name "*.so" -exec cp {} /app/bin/$PLATFORM_TRIPLE/cpu/ \; 2>/dev/null || true

## Base image
FROM ${BASE_CUDA_RUN_CONTAINER} AS base

RUN apt-get update \
    && apt-get install -y libgomp1 curl\
    && apt autoremove -y \
    && apt clean -y \
    && rm -rf /tmp/* /var/tmp/* \
    && find /var/cache/apt/archives /var/lib/apt/lists -not -name lock -type f -delete \
    && find /var/cache -type f -delete

# BodhiApp: Copy BodhiApp-compatible folder structure instead of lib/
COPY --from=build /app/bin/ /app/bin/
# BodhiApp: Copy CPU variant from lightweight build
COPY --from=build-cpu /app/bin/ /app/bin/

### Server, Server only
FROM base AS server

# BodhiApp: Version metadata arguments
ARG BUILD_VERSION
ARG BUILD_COMMIT
ARG BUILD_TIMESTAMP
ARG BUILD_BRANCH
ARG CUDA_DOCKER_ARCH
ARG CUDA_VERSION

ENV LLAMA_ARG_HOST=0.0.0.0

WORKDIR /app

# BodhiApp: Create non-root user for security
RUN groupadd -r llama && useradd -r -g llama -d /app -s /bin/bash llama && \
    chown -R llama:llama /app

# BodhiApp: Set up CUDA environment
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

# BodhiApp: Embed version information in image
LABEL org.opencontainers.image.version="${BUILD_VERSION}"
LABEL org.opencontainers.image.revision="${BUILD_COMMIT}"
LABEL org.opencontainers.image.created="${BUILD_TIMESTAMP}"
LABEL bodhi.build.timestamp="${BUILD_TIMESTAMP}"
LABEL bodhi.build.branch="${BUILD_BRANCH}"
LABEL bodhi.variant="cuda+cpu"
LABEL bodhi.variants.available="cuda,cpu"
LABEL bodhi.variants.primary="cuda"
LABEL bodhi.cuda.version="${CUDA_VERSION}"
LABEL bodhi.cuda.architectures="${CUDA_DOCKER_ARCH}"
LABEL bodhi.platform.compatibility="x86_64"
LABEL bodhi.requires.gpu="nvidia"

# BodhiApp: Create version file for runtime access
RUN echo "{\"version\":\"${BUILD_VERSION}\",\"commit\":\"${BUILD_COMMIT}\",\"timestamp\":\"${BUILD_TIMESTAMP}\",\"variants\":[\"cuda\",\"cpu\"],\"primary_variant\":\"cuda\",\"branch\":\"${BUILD_BRANCH}\",\"cuda_version\":\"${CUDA_VERSION}\"}" > /app/version.json && \
    chown llama:llama /app/version.json

# BodhiApp: Use non-root user
USER llama

# BodhiApp: Health check - verify CUDA availability and binary
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD test -x /app/llama-server && nvidia-smi > /dev/null 2>&1 || exit 1

# BodhiApp: Metadata labels
LABEL org.opencontainers.image.title="BodhiApp llama.cpp CUDA Runtime"
LABEL org.opencontainers.image.description="CUDA-enabled llama-server binary for BodhiApp integration"
LABEL org.opencontainers.image.source="https://github.com/BodhiSearch/llama.cpp"