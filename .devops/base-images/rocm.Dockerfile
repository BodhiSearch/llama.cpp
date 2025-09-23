ARG UBUNTU_VERSION=24.04

# This needs to generally match the container host's environment.
ARG ROCM_VERSION=6.4
ARG AMDGPU_VERSION=6.4

# Target the ROCm build image
ARG BASE_ROCM_DEV_CONTAINER=rocm/dev-ubuntu-${UBUNTU_VERSION}:${ROCM_VERSION}-complete

### Build image
FROM ${BASE_ROCM_DEV_CONTAINER} AS build

# Unless otherwise specified, we make a fat build.
# List from https://github.com/ggml-org/llama.cpp/pull/1087#issuecomment-1682807878
# This is mostly tied to rocBLAS supported archs.
# gfx803, gfx900, gfx1032, gfx1101, gfx1102,not officialy supported
# gfx906 is deprecated
#check https://rocm.docs.amd.com/projects/install-on-linux/en/docs-6.4.1/reference/system-requirements.html

ARG ROCM_DOCKER_ARCH='gfx803,gfx900,gfx906,gfx908,gfx90a,gfx942,gfx1010,gfx1030,gfx1032,gfx1100,gfx1101,gfx1102'
#ARG ROCM_DOCKER_ARCH=gfx1100

# Set nvcc architectured
ENV AMDGPU_TARGETS=${ROCM_DOCKER_ARCH}
# Enable ROCm
# ENV CC=/opt/rocm/llvm/bin/clang
# ENV CXX=/opt/rocm/llvm/bin/clang++

# BodhiApp: Version metadata build arguments
ARG BUILD_VERSION
ARG BUILD_COMMIT
ARG BUILD_TIMESTAMP
ARG BUILD_BRANCH

RUN apt-get update \
    && apt-get install -y \
    build-essential \
    cmake \
    git \
    libcurl4-openssl-dev \
    curl \
    libgomp1

WORKDIR /app

COPY . .

RUN HIPCXX="$(hipconfig -l)/clang" HIP_PATH="$(hipconfig -R)" \
    cmake -S . -B build -DGGML_HIP=ON -DAMDGPU_TARGETS=$ROCM_DOCKER_ARCH -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON -DCMAKE_BUILD_TYPE=Release -DLLAMA_BUILD_TESTS=OFF -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath,\$ORIGIN" \
    && cmake --build build --config Release -j$(nproc)

RUN mkdir -p /app/lib \
    && find build -name "*.so" -exec cp {} /app/lib \;

# BodhiApp: Create BodhiApp-compatible folder structure (ROCm is x86_64 only)
RUN PLATFORM_TRIPLE="x86_64-unknown-linux-gnu" && \
    mkdir -p /app/bin/$PLATFORM_TRIPLE/rocm && \
    cp build/bin/llama-server /app/bin/$PLATFORM_TRIPLE/rocm/ && \
    cp /app/lib/*.so /app/bin/$PLATFORM_TRIPLE/rocm/ 2>/dev/null || true

## Base image
FROM ${BASE_ROCM_DEV_CONTAINER} AS base

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
ARG ROCM_DOCKER_ARCH
ARG ROCM_VERSION

ENV LLAMA_ARG_HOST=0.0.0.0

WORKDIR /app

# BodhiApp: Create non-root user for security
RUN groupadd -r llama && useradd -r -g llama -d /app -s /bin/bash llama && \
    chown -R llama:llama /app

# BodhiApp: Set up ROCm environment
ENV HIP_VISIBLE_DEVICES=all
ENV ROCR_VISIBLE_DEVICES=all

# BodhiApp: Embed version information in image
LABEL org.opencontainers.image.version="${BUILD_VERSION}"
LABEL org.opencontainers.image.revision="${BUILD_COMMIT}"
LABEL org.opencontainers.image.created="${BUILD_TIMESTAMP}"
LABEL bodhi.build.timestamp="${BUILD_TIMESTAMP}"
LABEL bodhi.build.branch="${BUILD_BRANCH}"
LABEL bodhi.variant="rocm"
LABEL bodhi.rocm.version="${ROCM_VERSION}"
LABEL bodhi.rocm.architectures="${ROCM_DOCKER_ARCH}"
LABEL bodhi.platform.compatibility="x86_64"
LABEL bodhi.requires.gpu="amd"

# BodhiApp: Create version file for runtime access
RUN echo "{\"version\":\"${BUILD_VERSION}\",\"commit\":\"${BUILD_COMMIT}\",\"timestamp\":\"${BUILD_TIMESTAMP}\",\"variant\":\"rocm\",\"branch\":\"${BUILD_BRANCH}\",\"rocm_version\":\"${ROCM_VERSION}\"}" > /app/version.json && \
    chown llama:llama /app/version.json

# BodhiApp: Use non-root user
USER llama

# BodhiApp: Health check - verify ROCm availability and binary
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD test -x /app/llama-server && rocm-smi > /dev/null 2>&1 || exit 1

# BodhiApp: Metadata labels
LABEL org.opencontainers.image.title="BodhiApp llama.cpp ROCm Runtime"
LABEL org.opencontainers.image.description="ROCm-enabled llama-server binary for BodhiApp integration"
LABEL org.opencontainers.image.source="https://github.com/BodhiSearch/llama.cpp"