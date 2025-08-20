# Base image for CUDA-enabled llama.cpp runtime
# Simplified version focused on llama-server binary only

ARG UBUNTU_VERSION=24.04
ARG CUDA_VERSION=12.6.2

# Use NVIDIA's official CUDA development image for building
ARG BASE_CUDA_DEV_CONTAINER=nvidia/cuda:${CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION}
ARG BASE_CUDA_RUN_CONTAINER=nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu${UBUNTU_VERSION}

# Build stage - compile llama.cpp with CUDA support
FROM ${BASE_CUDA_DEV_CONTAINER} AS build

# Version metadata build arguments
ARG BUILD_VERSION
ARG BUILD_COMMIT
ARG BUILD_TIMESTAMP
ARG BUILD_BRANCH

# CUDA architecture to build for (defaults to common architectures)
ARG CUDA_DOCKER_ARCH="70;75;80;86;89;90"

RUN apt-get update && \
    apt-get install -y build-essential cmake git libcurl4-openssl-dev libgomp1 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY . .

# Build with CUDA support and optimizations
RUN cmake -S . -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DGGML_NATIVE=OFF \
        -DGGML_CUDA=ON \
        -DGGML_BACKEND_DL=ON \
        -DGGML_CPU_ALL_VARIANTS=ON \
        -DLLAMA_BUILD_TESTS=OFF \
        -DCMAKE_CUDA_ARCHITECTURES="${CUDA_DOCKER_ARCH}" \
        -DCMAKE_EXE_LINKER_FLAGS=-Wl,--allow-shlib-undefined \
        -DBUILD_SHARED_LIBS=OFF && \
    cmake --build build -j$(nproc) --target llama-server

# Runtime stage - NVIDIA runtime image with minimal footprint
FROM ${BASE_CUDA_RUN_CONTAINER} AS runtime

# Version metadata (repeated for runtime stage)
ARG BUILD_VERSION
ARG BUILD_COMMIT
ARG BUILD_TIMESTAMP
ARG BUILD_BRANCH
ARG CUDA_DOCKER_ARCH

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

# Set up CUDA environment
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

# Embed version information in image
LABEL org.opencontainers.image.version="${BUILD_VERSION}"
LABEL org.opencontainers.image.revision="${BUILD_COMMIT}"
LABEL org.opencontainers.image.created="${BUILD_TIMESTAMP}"
LABEL bodhi.build.timestamp="${BUILD_TIMESTAMP}"
LABEL bodhi.build.branch="${BUILD_BRANCH}"
LABEL bodhi.variant="cuda"
LABEL bodhi.cuda.version="${CUDA_VERSION}"
LABEL bodhi.cuda.architectures="${CUDA_DOCKER_ARCH}"
LABEL bodhi.platform.compatibility="x86_64"
LABEL bodhi.requires.gpu="nvidia"

# Create version file for runtime access
RUN echo "{\"version\":\"${BUILD_VERSION}\",\"commit\":\"${BUILD_COMMIT}\",\"timestamp\":\"${BUILD_TIMESTAMP}\",\"variant\":\"cuda\",\"branch\":\"${BUILD_BRANCH}\",\"cuda_version\":\"${CUDA_VERSION}\"}" > /app/version.json && \
    chown llama:llama /app/version.json

USER llama
WORKDIR /app

# Simple, predictable behavior - just run llama-server
ENTRYPOINT ["/app/bin/llama-server"]
CMD ["--help"]

# Health check - verify CUDA availability and binary
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD test -x /app/bin/llama-server && nvidia-smi > /dev/null 2>&1 || exit 1

# Metadata labels
LABEL org.opencontainers.image.title="BodhiApp llama.cpp CUDA Runtime"
LABEL org.opencontainers.image.description="CUDA-enabled llama-server binary for BodhiApp integration"
LABEL org.opencontainers.image.source="https://github.com/BodhiSearch/llama.cpp"