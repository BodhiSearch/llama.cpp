ARG UBUNTU_VERSION=26.04

FROM ubuntu:$UBUNTU_VERSION AS build

# BodhiApp: Version metadata build arguments
ARG BUILD_VERSION
ARG BUILD_COMMIT
ARG BUILD_TIMESTAMP
ARG BUILD_BRANCH

# Install build tools
RUN apt update && apt install -y git build-essential cmake wget xz-utils

# Install cURL and Vulkan SDK dependencies
RUN apt install -y libcurl4-openssl-dev curl \
    libxcb-xinput0 libxcb-xinerama0 libxcb-cursor-dev libvulkan-dev glslc

# Build it
WORKDIR /app

COPY . .

RUN cmake -B build -DGGML_NATIVE=OFF -DGGML_VULKAN=ON -DLLAMA_BUILD_TESTS=OFF -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath,\$ORIGIN" && \
    cmake --build build --config Release -j$(nproc)

RUN mkdir -p /app/lib && \
    find build -name "*.so*" -exec cp -P {} /app/lib \;

# BodhiApp: Create BodhiApp-compatible folder structure (x86_64 only)
RUN mkdir -p /app/bin/x86_64-unknown-linux-gnu/vulkan && \
    cp build/bin/llama-server /app/bin/x86_64-unknown-linux-gnu/vulkan/ && \
    cp /app/lib/*.so /app/bin/x86_64-unknown-linux-gnu/vulkan/ 2>/dev/null || true

## Base image
FROM ubuntu:$UBUNTU_VERSION AS base

RUN apt-get update \
    && apt-get install -y libgomp1 curl libvulkan1 mesa-vulkan-drivers \
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
LABEL bodhi.platform.compatibility="x86_64"
LABEL bodhi.requires.gpu="vulkan-compatible"

# BodhiApp: Create version file for runtime access
RUN echo "{\"version\":\"${BUILD_VERSION}\",\"commit\":\"${BUILD_COMMIT}\",\"timestamp\":\"${BUILD_TIMESTAMP}\",\"variant\":\"vulkan\",\"branch\":\"${BUILD_BRANCH}\"}" > /app/version.json && \
    chown llama:llama /app/version.json

# BodhiApp: Use non-root user
USER llama

# BodhiApp: Health check - verify Vulkan availability and binary (x86_64 only)
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD test -x /app/bin/x86_64-unknown-linux-gnu/vulkan/llama-server && \
        vulkaninfo > /dev/null 2>&1 || exit 1

# BodhiApp: Metadata labels
LABEL org.opencontainers.image.title="BodhiApp llama.cpp Vulkan Runtime"
LABEL org.opencontainers.image.description="Vulkan-enabled llama-server binary for BodhiApp integration"
LABEL org.opencontainers.image.source="https://github.com/BodhiSearch/llama.cpp"
