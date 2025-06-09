ARG ONEAPI_VERSION=2025.2.2-0-devel-ubuntu24.04

## Build Image

FROM intel/deep-learning-essentials:$ONEAPI_VERSION AS build

ARG GGML_SYCL_F16=OFF

# BodhiApp: Version metadata build arguments
ARG BUILD_VERSION
ARG BUILD_COMMIT
ARG BUILD_TIMESTAMP
ARG BUILD_BRANCH

RUN apt-get update && \
    apt-get install -y git libcurl4-openssl-dev libgomp1

WORKDIR /app

COPY . .

RUN if [ "${GGML_SYCL_F16}" = "ON" ]; then \
        echo "GGML_SYCL_F16 is set" \
        && export OPT_SYCL_F16="-DGGML_SYCL_F16=ON"; \
    fi && \
    echo "Building with dynamic libs" && \
    cmake -B build -DGGML_NATIVE=OFF -DGGML_SYCL=ON -DCMAKE_C_COMPILER=icx -DCMAKE_CXX_COMPILER=icpx -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON -DLLAMA_BUILD_TESTS=OFF ${OPT_SYCL_F16} -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath,\$ORIGIN" && \
    cmake --build build --config Release -j$(nproc)

RUN mkdir -p /app/lib && \
    find build -name "*.so*" -exec cp -P {} /app/lib \;

# BodhiApp: Create BodhiApp-compatible folder structure (Intel SYCL is x86_64 only)
RUN PLATFORM_TRIPLE="x86_64-unknown-linux-gnu" && \
    mkdir -p /app/bin/$PLATFORM_TRIPLE/intel && \
    cp build/bin/llama-server /app/bin/$PLATFORM_TRIPLE/intel/ && \
    cp /app/lib/*.so /app/bin/$PLATFORM_TRIPLE/intel/ 2>/dev/null || true

FROM intel/deep-learning-essentials:$ONEAPI_VERSION AS base

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
ARG ONEAPI_VERSION
ARG GGML_SYCL_F16

ENV LLAMA_ARG_HOST=0.0.0.0

WORKDIR /app

# BodhiApp: Create non-root user for security
RUN groupadd -r llama && useradd -r -g llama -d /app -s /bin/bash llama && \
    chown -R llama:llama /app

# BodhiApp: Set up Intel GPU environment
ENV NEOReadDebugKeys=1
ENV ClDeviceGlobalMemSizeAvailablePercent=100

# BodhiApp: Embed version information in image
LABEL org.opencontainers.image.version="${BUILD_VERSION}"
LABEL org.opencontainers.image.revision="${BUILD_COMMIT}"
LABEL org.opencontainers.image.created="${BUILD_TIMESTAMP}"
LABEL bodhi.build.timestamp="${BUILD_TIMESTAMP}"
LABEL bodhi.build.branch="${BUILD_BRANCH}"
LABEL bodhi.variant="intel"
LABEL bodhi.oneapi.version="${ONEAPI_VERSION}"
LABEL bodhi.sycl.f16="${GGML_SYCL_F16}"
LABEL bodhi.platform.compatibility="x86_64"
LABEL bodhi.requires.gpu="intel"

# BodhiApp: Create version file for runtime access
RUN echo "{\"version\":\"${BUILD_VERSION}\",\"commit\":\"${BUILD_COMMIT}\",\"timestamp\":\"${BUILD_TIMESTAMP}\",\"variant\":\"intel\",\"branch\":\"${BUILD_BRANCH}\",\"oneapi_version\":\"${ONEAPI_VERSION}\",\"sycl_f16\":\"${GGML_SYCL_F16}\"}" > /app/version.json && \
    chown llama:llama /app/version.json

# BodhiApp: Use non-root user
USER llama

# BodhiApp: Health check - verify Intel GPU availability and binary
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD test -x /app/bin/x86_64-unknown-linux-gnu/intel/llama-server && sycl-ls > /dev/null 2>&1 || exit 1

# BodhiApp: Metadata labels
LABEL org.opencontainers.image.title="BodhiApp llama.cpp Intel Runtime"
LABEL org.opencontainers.image.description="Intel GPU-enabled llama-server binary for BodhiApp integration (SYCL/OneAPI)"
LABEL org.opencontainers.image.source="https://github.com/BodhiSearch/llama.cpp"
