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

RUN if [ "$TARGETARCH" = "amd64" ] || [ "$TARGETARCH" = "arm64" ]; then \
        cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DGGML_NATIVE=OFF -DLLAMA_BUILD_TESTS=OFF -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON; \
    else \
        echo "Unsupported architecture"; \
        exit 1; \
    fi && \
    cmake --build build -j $(nproc)

RUN mkdir -p /app/lib && \
    find build -name "*.so" -exec cp {} /app/lib \;

# BodhiApp: Create minimal server package instead of full package
RUN mkdir -p /app/server \
    && cp build/bin/llama-server /app/server

## Base image
FROM ubuntu:$UBUNTU_VERSION AS base

RUN apt-get update \
    && apt-get install -y libgomp1 curl\
    && apt autoremove -y \
    && apt clean -y \
    && rm -rf /tmp/* /var/tmp/* \
    && find /var/cache/apt/archives /var/lib/apt/lists -not -name lock -type f -delete \
    && find /var/cache -type f -delete

COPY --from=build /app/lib/ /app

### Server, Server only
FROM base AS server

# BodhiApp: Version metadata arguments
ARG BUILD_VERSION
ARG BUILD_COMMIT
ARG BUILD_TIMESTAMP
ARG BUILD_BRANCH

ENV LLAMA_ARG_HOST=0.0.0.0

COPY --from=build /app/server/llama-server /app

WORKDIR /app

# BodhiApp: Create non-root user for security
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

# BodhiApp: Direct server execution instead of curl health check
ENTRYPOINT [ "/app/llama-server" ]

# BodhiApp: Metadata labels
LABEL org.opencontainers.image.title="BodhiApp llama.cpp CPU Runtime"
LABEL org.opencontainers.image.description="CPU-optimized llama-server binary for BodhiApp integration"
LABEL org.opencontainers.image.source="https://github.com/BodhiSearch/llama.cpp"