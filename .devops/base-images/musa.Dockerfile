ARG UBUNTU_VERSION=22.04
# This needs to generally match the container host's environment.
ARG MUSA_VERSION=rc4.3.0
# Target the MUSA build image
ARG BASE_MUSA_DEV_CONTAINER=mthreads/musa:${MUSA_VERSION}-devel-ubuntu${UBUNTU_VERSION}-amd64

ARG BASE_MUSA_RUN_CONTAINER=mthreads/musa:${MUSA_VERSION}-runtime-ubuntu${UBUNTU_VERSION}-amd64

FROM ${BASE_MUSA_DEV_CONTAINER} AS build

# MUSA architecture to build for (defaults to all supported archs)
ARG MUSA_DOCKER_ARCH=default

# BodhiApp: Version metadata build arguments
ARG BUILD_VERSION
ARG BUILD_COMMIT
ARG BUILD_TIMESTAMP
ARG BUILD_BRANCH

RUN apt-get update && \
    apt-get install -y \
    build-essential \
    cmake \
    python3 \
    python3-pip \
    git \
    libcurl4-openssl-dev \
    libgomp1

WORKDIR /app

COPY . .

RUN if [ "${MUSA_DOCKER_ARCH}" != "default" ]; then \
        export CMAKE_ARGS="-DMUSA_ARCHITECTURES=${MUSA_DOCKER_ARCH}"; \
    fi && \
    cmake -B build -DGGML_NATIVE=OFF -DGGML_MUSA=ON -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON -DLLAMA_BUILD_TESTS=OFF ${CMAKE_ARGS} -DCMAKE_EXE_LINKER_FLAGS="-Wl,--allow-shlib-undefined -Wl,-rpath,\$ORIGIN" . && \
    cmake --build build --config Release -j$(nproc)

RUN mkdir -p /app/lib && \
    find build -name "*.so" -exec cp {} /app/lib \;

# BodhiApp: Create BodhiApp-compatible folder structure (MUSA is x86_64 only)
RUN PLATFORM_TRIPLE="x86_64-unknown-linux-gnu" && \
    mkdir -p /app/bin/$PLATFORM_TRIPLE/musa && \
    cp build/bin/llama-server /app/bin/$PLATFORM_TRIPLE/musa/ && \
    cp /app/lib/*.so /app/bin/$PLATFORM_TRIPLE/musa/ 2>/dev/null || true

## Base image
FROM ${BASE_MUSA_RUN_CONTAINER} AS base

RUN apt-get update \
    && apt-get install -y libgomp1 curl\
    && apt autoremove -y \
    && apt clean -y \
    && rm -rf /tmp/* /var/tmp/* \
    && find /var/cache/apt/archives /var/lib/apt/lists -not -name lock -type f -delete \
    && find /var/cache -type f -delete

# BodhiApp: Copy BodhiApp-compatible folder structure instead of lib/
COPY --from=build /app/bin/ /app/bin/

### Server, Server only
FROM base AS server

# BodhiApp: Version metadata arguments
ARG BUILD_VERSION
ARG BUILD_COMMIT
ARG BUILD_TIMESTAMP
ARG BUILD_BRANCH
ARG MUSA_DOCKER_ARCH
ARG MUSA_VERSION

ENV LLAMA_ARG_HOST=0.0.0.0

WORKDIR /app

# BodhiApp: Create non-root user for security
RUN groupadd -r llama && useradd -r -g llama -d /app -s /bin/bash llama && \
    chown -R llama:llama /app

# BodhiApp: Set up MUSA environment
ENV MUSA_VISIBLE_DEVICES=all

# BodhiApp: Embed version information in image
LABEL org.opencontainers.image.version="${BUILD_VERSION}"
LABEL org.opencontainers.image.revision="${BUILD_COMMIT}"
LABEL org.opencontainers.image.created="${BUILD_TIMESTAMP}"
LABEL bodhi.build.timestamp="${BUILD_TIMESTAMP}"
LABEL bodhi.build.branch="${BUILD_BRANCH}"
LABEL bodhi.variant="musa"
LABEL bodhi.musa.version="${MUSA_VERSION}"
LABEL bodhi.musa.architectures="${MUSA_DOCKER_ARCH}"
LABEL bodhi.platform.compatibility="x86_64"
LABEL bodhi.requires.gpu="mthreads"

# BodhiApp: Create version file for runtime access
RUN echo "{\"version\":\"${BUILD_VERSION}\",\"commit\":\"${BUILD_COMMIT}\",\"timestamp\":\"${BUILD_TIMESTAMP}\",\"variant\":\"musa\",\"branch\":\"${BUILD_BRANCH}\",\"musa_version\":\"${MUSA_VERSION}\"}" > /app/version.json && \
    chown llama:llama /app/version.json

# BodhiApp: Use non-root user
USER llama

# BodhiApp: Health check - verify MUSA availability and binary
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD test -x /app/bin/x86_64-unknown-linux-gnu/musa/llama-server || exit 1

# BodhiApp: Metadata labels
LABEL org.opencontainers.image.title="BodhiApp llama.cpp MUSA Runtime"
LABEL org.opencontainers.image.description="MUSA-enabled llama-server binary for BodhiApp integration (Moore Threads GPUs)"
LABEL org.opencontainers.image.source="https://github.com/BodhiSearch/llama.cpp"
