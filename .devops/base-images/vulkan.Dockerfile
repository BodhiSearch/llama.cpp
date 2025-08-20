# Base image for Vulkan-enabled llama.cpp runtime
# Simplified version focused on llama-server binary only

ARG UBUNTU_VERSION=24.04
ARG VULKAN_SDK_VERSION=1.3.290

# Build stage - compile llama.cpp with Vulkan support
FROM ubuntu:${UBUNTU_VERSION} AS build

# Version metadata build arguments
ARG BUILD_VERSION
ARG BUILD_COMMIT
ARG BUILD_TIMESTAMP
ARG BUILD_BRANCH

ARG TARGETARCH
ARG VULKAN_SDK_VERSION

# Install build dependencies including Vulkan SDK
RUN apt-get update && \
    apt-get install -y \
        build-essential \
        cmake \
        git \
        libcurl4-openssl-dev \
        libgomp1 \
        wget \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Vulkan SDK
RUN wget -qO - https://packages.lunarg.com/lunarg-signing-key-pub.asc | apt-key add - && \
    wget -qO /etc/apt/sources.list.d/lunarg-vulkan-${UBUNTU_VERSION}.list \
        https://packages.lunarg.com/vulkan/lunarg-vulkan-${UBUNTU_VERSION}.list && \
    apt-get update && \
    apt-get install -y vulkan-sdk mesa-vulkan-drivers && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY . .

# Build with Vulkan support
RUN if [ "$TARGETARCH" = "amd64" ] || [ "$TARGETARCH" = "arm64" ]; then \
        cmake -S . -B build \
            -DCMAKE_BUILD_TYPE=Release \
            -DGGML_NATIVE=OFF \
            -DGGML_VULKAN=ON \
            -DGGML_BACKEND_DL=ON \
            -DGGML_CPU_ALL_VARIANTS=ON \
            -DLLAMA_BUILD_TESTS=OFF \
            -DBUILD_SHARED_LIBS=OFF; \
    else \
        echo "Unsupported architecture: $TARGETARCH"; \
        exit 1; \
    fi && \
    cmake --build build -j$(nproc) --target llama-server

# Runtime stage - minimal Ubuntu with Vulkan runtime
FROM ubuntu:${UBUNTU_VERSION} AS runtime

# Version metadata (repeated for runtime stage)
ARG BUILD_VERSION
ARG BUILD_COMMIT
ARG BUILD_TIMESTAMP
ARG BUILD_BRANCH
ARG VULKAN_SDK_VERSION

# Install Vulkan runtime dependencies
RUN apt-get update && \
    apt-get install -y \
        ca-certificates \
        libgomp1 \
        libcurl4 \
        curl \
        wget \
    && rm -rf /var/lib/apt/lists/*

# Install Vulkan runtime (lighter than SDK)
RUN wget -qO - https://packages.lunarg.com/lunarg-signing-key-pub.asc | apt-key add - && \
    wget -qO /etc/apt/sources.list.d/lunarg-vulkan-${UBUNTU_VERSION}.list \
        https://packages.lunarg.com/vulkan/lunarg-vulkan-${UBUNTU_VERSION}.list && \
    apt-get update && \
    apt-get install -y \
        libvulkan1 \
        mesa-vulkan-drivers \
        vulkan-tools \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create application directory
RUN mkdir -p /app/bin

# Copy only llama-server binary
COPY --from=build /build/build/bin/llama-server /app/bin/llama-server

# Create non-root user for security
RUN groupadd -r llama && useradd -r -g llama -d /app -s /bin/bash llama && \
    chown -R llama:llama /app

# Set up Vulkan environment
ENV VK_INSTANCE_LAYERS=""
ENV VK_DEVICE_SELECT_FORCE_DEFAULT_DEVICE=1

# Embed version information in image
LABEL org.opencontainers.image.version="${BUILD_VERSION}"
LABEL org.opencontainers.image.revision="${BUILD_COMMIT}"
LABEL org.opencontainers.image.created="${BUILD_TIMESTAMP}"
LABEL bodhi.build.timestamp="${BUILD_TIMESTAMP}"
LABEL bodhi.build.branch="${BUILD_BRANCH}"
LABEL bodhi.variant="vulkan"
LABEL bodhi.vulkan.version="${VULKAN_SDK_VERSION}"
LABEL bodhi.platform.compatibility="x86_64,aarch64"
LABEL bodhi.requires.gpu="vulkan-compatible"

# Create version file for runtime access
RUN echo "{\"version\":\"${BUILD_VERSION}\",\"commit\":\"${BUILD_COMMIT}\",\"timestamp\":\"${BUILD_TIMESTAMP}\",\"variant\":\"vulkan\",\"branch\":\"${BUILD_BRANCH}\",\"vulkan_version\":\"${VULKAN_SDK_VERSION}\"}" > /app/version.json && \
    chown llama:llama /app/version.json

USER llama
WORKDIR /app

# Simple, predictable behavior - just run llama-server
ENTRYPOINT ["/app/bin/llama-server"]
CMD ["--help"]

# Health check - verify Vulkan availability and binary
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD test -x /app/bin/llama-server && vulkaninfo > /dev/null 2>&1 || exit 1

# Metadata labels
LABEL org.opencontainers.image.title="BodhiApp llama.cpp Vulkan Runtime"
LABEL org.opencontainers.image.description="Vulkan-enabled llama-server binary for BodhiApp integration"
LABEL org.opencontainers.image.source="https://github.com/BodhiSearch/llama.cpp"