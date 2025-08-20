# Base image for CPU-only llama.cpp runtime
# Simplified version focused on llama-server binary only

ARG UBUNTU_VERSION=24.04

# Build stage - compile llama.cpp with CPU optimizations
FROM ubuntu:${UBUNTU_VERSION} AS build

# Version metadata build arguments
ARG BUILD_VERSION
ARG BUILD_COMMIT
ARG BUILD_TIMESTAMP
ARG BUILD_BRANCH

ARG TARGETARCH

RUN apt-get update && \
    apt-get install -y build-essential git cmake libcurl4-openssl-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY . .

# Build with CPU optimizations, all variants enabled for maximum compatibility
RUN if [ "$TARGETARCH" = "amd64" ] || [ "$TARGETARCH" = "arm64" ]; then \
        cmake -S . -B build \
            -DCMAKE_BUILD_TYPE=Release \
            -DGGML_NATIVE=OFF \
            -DGGML_CPU_ALL_VARIANTS=ON \
            -DGGML_BACKEND_DL=ON \
            -DLLAMA_BUILD_TESTS=OFF \
            -DBUILD_SHARED_LIBS=OFF; \
    else \
        echo "Unsupported architecture: $TARGETARCH"; \
        exit 1; \
    fi && \
    cmake --build build -j$(nproc) --target llama-server

# Runtime stage - minimal image with only runtime dependencies
FROM ubuntu:${UBUNTU_VERSION} AS runtime

# Version metadata (repeated for runtime stage)
ARG BUILD_VERSION
ARG BUILD_COMMIT
ARG BUILD_TIMESTAMP
ARG BUILD_BRANCH

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

# Embed version information in image
LABEL org.opencontainers.image.version="${BUILD_VERSION}"
LABEL org.opencontainers.image.revision="${BUILD_COMMIT}"
LABEL org.opencontainers.image.created="${BUILD_TIMESTAMP}"
LABEL bodhi.build.timestamp="${BUILD_TIMESTAMP}"
LABEL bodhi.build.branch="${BUILD_BRANCH}"
LABEL bodhi.variant="cpu"
LABEL bodhi.platform.compatibility="x86_64,aarch64"

# Create version file for runtime access
RUN echo "{\"version\":\"${BUILD_VERSION}\",\"commit\":\"${BUILD_COMMIT}\",\"timestamp\":\"${BUILD_TIMESTAMP}\",\"variant\":\"cpu\",\"branch\":\"${BUILD_BRANCH}\"}" > /app/version.json && \
    chown llama:llama /app/version.json

USER llama
WORKDIR /app

# Simple, predictable behavior - just run llama-server
ENTRYPOINT ["/app/bin/llama-server"]
CMD ["--help"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD test -x /app/bin/llama-server || exit 1

# Metadata labels
LABEL org.opencontainers.image.title="BodhiApp llama.cpp CPU Runtime"
LABEL org.opencontainers.image.description="CPU-optimized llama-server binary for BodhiApp integration"
LABEL org.opencontainers.image.source="https://github.com/BodhiSearch/llama.cpp"