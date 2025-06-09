ARG UBUNTU_VERSION=22.04

FROM ubuntu:$UBUNTU_VERSION AS build

ARG TARGETARCH

# BodhiApp: Version metadata build arguments
ARG BUILD_VERSION
ARG BUILD_COMMIT
ARG BUILD_TIMESTAMP
ARG BUILD_BRANCH

RUN apt-get update && \
    apt-get install -y build-essential git cmake libcurl4-openssl-dev

WORKDIR /app

COPY . .

RUN if [ "$TARGETARCH" = "amd64" ]; then \
        cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DGGML_NATIVE=OFF -DLLAMA_BUILD_TESTS=OFF -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath,\$ORIGIN"; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
        cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DGGML_NATIVE=OFF -DLLAMA_BUILD_TESTS=OFF -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=OFF -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath,\$ORIGIN"; \
    else \
        echo "Unsupported architecture"; \
        exit 1; \
    fi && \
    cmake --build build -j $(nproc)

RUN mkdir -p /app/lib && \
    find build -name "*.so*" -exec cp -P {} /app/lib \;

# BodhiApp: Create BodhiApp-compatible folder structure with platform-triple
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        PLATFORM_TRIPLE="x86_64-unknown-linux-gnu"; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
        PLATFORM_TRIPLE="aarch64-unknown-linux-gnu"; \
    else \
        echo "Unsupported architecture: $TARGETARCH"; exit 1; \
    fi && \
    mkdir -p /app/bin/$PLATFORM_TRIPLE/cpu && \
    cp build/bin/llama-server /app/bin/$PLATFORM_TRIPLE/cpu/ && \
    find /app/lib -name "*.so*" -exec cp -P {} /app/bin/$PLATFORM_TRIPLE/cpu/ \; 2>/dev/null || true

## Base image
FROM ubuntu:$UBUNTU_VERSION AS base

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
ARG TARGETARCH

ENV LLAMA_ARG_HOST=0.0.0.0

WORKDIR /app

# BodhiApp: Create non-root user for security and set LD_LIBRARY_PATH
RUN groupadd -r llama && useradd -r -g llama -d /app -s /bin/bash llama && \
    chown -R llama:llama /app

# BodhiApp: Embed version information in image
LABEL org.opencontainers.image.version="${BUILD_VERSION}"
LABEL org.opencontainers.image.revision="${BUILD_COMMIT}"
LABEL org.opencontainers.image.created="${BUILD_TIMESTAMP}"
LABEL bodhi.build.timestamp="${BUILD_TIMESTAMP}"
LABEL bodhi.build.branch="${BUILD_BRANCH}"
LABEL bodhi.variant="cpu"
LABEL bodhi.platform.compatibility="x86_64,aarch64"
LABEL bodhi.acceleration="cpu-optimized"

# BodhiApp: Create version file for runtime access
RUN echo "{\"version\":\"${BUILD_VERSION}\",\"commit\":\"${BUILD_COMMIT}\",\"timestamp\":\"${BUILD_TIMESTAMP}\",\"variant\":\"cpu\",\"branch\":\"${BUILD_BRANCH}\"}" > /app/version.json && \
    chown llama:llama /app/version.json

# BodhiApp: Use non-root user
USER llama

# BodhiApp: Health check for binary existence
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD test -x /app/llama-server || exit 1

# BodhiApp: Metadata labels
LABEL org.opencontainers.image.title="BodhiApp llama.cpp CPU Runtime"
LABEL org.opencontainers.image.description="CPU-optimized llama-server binary for BodhiApp integration"
LABEL org.opencontainers.image.source="https://github.com/BodhiSearch/llama.cpp"