ARG UBUNTU_VERSION=24.04

FROM ubuntu:$UBUNTU_VERSION AS build

# BodhiApp: Version metadata build arguments
ARG BUILD_VERSION
ARG BUILD_COMMIT
ARG BUILD_TIMESTAMP
ARG BUILD_BRANCH
ARG VULKAN_SDK_VERSION

# Install build tools
RUN apt update && apt install -y git build-essential cmake wget

# Install Vulkan SDK and cURL
RUN wget -qO /usr/share/keyrings/lunarg-archive-keyring.gpg \
        https://packages.lunarg.com/lunarg-signing-key-pub.asc && \
    echo "deb [signed-by=/usr/share/keyrings/lunarg-archive-keyring.gpg] https://packages.lunarg.com/vulkan noble main" > \
        /etc/apt/sources.list.d/lunarg-vulkan-noble.list && \
    apt update -y && \
    apt-get install -y vulkan-sdk libcurl4-openssl-dev curl

# Build it
WORKDIR /app

COPY . .

RUN cmake -B build -DGGML_NATIVE=OFF -DGGML_VULKAN=1  -DLLAMA_BUILD_TESTS=OFF -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON && \
    cmake --build build --config Release -j$(nproc)

RUN mkdir -p /app/lib && \
    find build -name "*.so" -exec cp {} /app/lib \;

# BodhiApp: Create BodhiApp-compatible folder structure with platform detection
RUN TARGETARCH=$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/') && \
    if [ "$TARGETARCH" = "amd64" ]; then \
        PLATFORM_TRIPLE="x86_64-unknown-linux-gnu"; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
        PLATFORM_TRIPLE="aarch64-unknown-linux-gnu"; \
    else \
        echo "Unsupported architecture: $TARGETARCH"; exit 1; \
    fi && \
    mkdir -p /app/bin/$PLATFORM_TRIPLE/vulkan && \
    cp build/bin/llama-server /app/bin/$PLATFORM_TRIPLE/vulkan/ && \
    cp /app/lib/*.so /app/bin/$PLATFORM_TRIPLE/vulkan/ 2>/dev/null || true

## Base image
FROM ubuntu:$UBUNTU_VERSION AS base

RUN apt-get update \
    && apt-get install -y libgomp1 curl libvulkan-dev \
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
ARG VULKAN_SDK_VERSION

ENV LLAMA_ARG_HOST=0.0.0.0

WORKDIR /app

# BodhiApp: Create non-root user for security
RUN groupadd -r llama && useradd -r -g llama -d /app -s /bin/bash llama && \
    chown -R llama:llama /app

# BodhiApp: Set up Vulkan environment
ENV VK_INSTANCE_LAYERS=""
ENV VK_DEVICE_SELECT_FORCE_DEFAULT_DEVICE=1

# BodhiApp: Embed version information in image
LABEL org.opencontainers.image.version="${BUILD_VERSION}"
LABEL org.opencontainers.image.revision="${BUILD_COMMIT}"
LABEL org.opencontainers.image.created="${BUILD_TIMESTAMP}"
LABEL bodhi.build.timestamp="${BUILD_TIMESTAMP}"
LABEL bodhi.build.branch="${BUILD_BRANCH}"
LABEL bodhi.variant="vulkan"
LABEL bodhi.vulkan.version="${VULKAN_SDK_VERSION}"
LABEL bodhi.platform.compatibility="x86_64,aarch64"
LABEL bodhi.requires.gpu="vulkan-compatible"

# BodhiApp: Create version file for runtime access
RUN echo "{\"version\":\"${BUILD_VERSION}\",\"commit\":\"${BUILD_COMMIT}\",\"timestamp\":\"${BUILD_TIMESTAMP}\",\"variant\":\"vulkan\",\"branch\":\"${BUILD_BRANCH}\",\"vulkan_version\":\"${VULKAN_SDK_VERSION}\"}" > /app/version.json && \
    chown llama:llama /app/version.json

# BodhiApp: Use non-root user
USER llama

# BodhiApp: Health check - verify Vulkan availability and binary
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD test -x /app/llama-server && vulkaninfo > /dev/null 2>&1 || exit 1

# BodhiApp: Metadata labels
LABEL org.opencontainers.image.title="BodhiApp llama.cpp Vulkan Runtime"
LABEL org.opencontainers.image.description="Vulkan-enabled llama-server binary for BodhiApp integration"
LABEL org.opencontainers.image.source="https://github.com/BodhiSearch/llama.cpp"