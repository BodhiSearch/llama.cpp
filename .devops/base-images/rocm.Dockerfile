# Base image for ROCm-enabled llama.cpp runtime
# Simplified version focused on llama-server binary only

ARG UBUNTU_VERSION=24.04
ARG ROCM_VERSION=6.4

# Use AMD's official ROCm development image for building
ARG BASE_ROCM_DEV_CONTAINER=rocm/dev-ubuntu-${UBUNTU_VERSION}:${ROCM_VERSION}-complete

# Build stage - compile llama.cpp with ROCm/HIP support
FROM ${BASE_ROCM_DEV_CONTAINER} AS build

# Version metadata build arguments
ARG BUILD_VERSION
ARG BUILD_COMMIT
ARG BUILD_TIMESTAMP
ARG BUILD_BRANCH

# Default to common AMD GPU architectures
ARG ROCM_DOCKER_ARCH='gfx803,gfx900,gfx906,gfx908,gfx90a,gfx942,gfx1010,gfx1030,gfx1032,gfx1100,gfx1101,gfx1102'

# Set AMD GPU targets for compilation
ENV AMDGPU_TARGETS=${ROCM_DOCKER_ARCH}

RUN apt-get update && \
    apt-get install -y \
        build-essential \
        cmake \
        git \
        libcurl4-openssl-dev \
        libgomp1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY . .

# Build with ROCm/HIP support
RUN HIPCXX="$(hipconfig -l)/clang" HIP_PATH="$(hipconfig -R)" \
    cmake -S . -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DGGML_NATIVE=OFF \
        -DGGML_HIP=ON \
        -DGGML_BACKEND_DL=ON \
        -DGGML_CPU_ALL_VARIANTS=ON \
        -DLLAMA_BUILD_TESTS=OFF \
        -DAMDGPU_TARGETS=${ROCM_DOCKER_ARCH} \
        -DBUILD_SHARED_LIBS=OFF && \
    cmake --build build -j$(nproc) --target llama-server

# Runtime stage - ROCm runtime image
FROM rocm/dev-ubuntu-${UBUNTU_VERSION}:${ROCM_VERSION} AS runtime

# Version metadata (repeated for runtime stage)
ARG BUILD_VERSION
ARG BUILD_COMMIT
ARG BUILD_TIMESTAMP
ARG BUILD_BRANCH
ARG ROCM_DOCKER_ARCH

# Install minimal runtime dependencies
RUN apt-get update && \
    apt-get install -y \
        ca-certificates \
        libgomp1 \
        libcurl4 \
        curl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create application directory
RUN mkdir -p /app/bin

# Copy only llama-server binary
COPY --from=build /build/build/bin/llama-server /app/bin/llama-server

# Create non-root user for security
RUN groupadd -r llama && useradd -r -g llama -d /app -s /bin/bash llama && \
    chown -R llama:llama /app

# Set up ROCm environment
ENV HIP_VISIBLE_DEVICES=all
ENV ROCR_VISIBLE_DEVICES=all

# Embed version information in image
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

# Create version file for runtime access
RUN echo "{\"version\":\"${BUILD_VERSION}\",\"commit\":\"${BUILD_COMMIT}\",\"timestamp\":\"${BUILD_TIMESTAMP}\",\"variant\":\"rocm\",\"branch\":\"${BUILD_BRANCH}\",\"rocm_version\":\"${ROCM_VERSION}\"}" > /app/version.json && \
    chown llama:llama /app/version.json

USER llama
WORKDIR /app

# Simple, predictable behavior - just run llama-server
ENTRYPOINT ["/app/bin/llama-server"]
CMD ["--help"]

# Health check - verify ROCm availability and binary
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD test -x /app/bin/llama-server && rocm-smi > /dev/null 2>&1 || exit 1

# Metadata labels
LABEL org.opencontainers.image.title="BodhiApp llama.cpp ROCm Runtime"
LABEL org.opencontainers.image.description="ROCm-enabled llama-server binary for BodhiApp integration"
LABEL org.opencontainers.image.source="https://github.com/BodhiSearch/llama.cpp"