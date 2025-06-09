# ==============================================================================
# ARGUMENTS
# ==============================================================================

# Define the CANN base image for easier version updates later
ARG CHIP_TYPE=910b
ARG CANN_BASE_IMAGE=quay.io/ascend/cann:8.3.rc2-${CHIP_TYPE}-openeuler24.03-py3.11

# ==============================================================================
# BUILD STAGE
# Compile all binary files and libraries
# ==============================================================================
FROM ${CANN_BASE_IMAGE} AS build

# BodhiApp: Version metadata build arguments
ARG BUILD_VERSION
ARG BUILD_COMMIT
ARG BUILD_TIMESTAMP
ARG BUILD_BRANCH

# -- Install build dependencies --
RUN yum install -y gcc g++ cmake make git libcurl-devel python3 python3-pip && \
    yum clean all && \
    rm -rf /var/cache/yum

# -- Set the working directory --
WORKDIR /app

# -- Copy project files --
COPY . .

# -- Set CANN environment variables (required for compilation) --
# Using ENV instead of `source` allows environment variables to persist across the entire image layer
ENV ASCEND_TOOLKIT_HOME=/usr/local/Ascend/ascend-toolkit/latest
ENV LD_LIBRARY_PATH=${ASCEND_TOOLKIT_HOME}/lib64:${LD_LIBRARY_PATH}
ENV PATH=${ASCEND_TOOLKIT_HOME}/bin:${PATH}
ENV ASCEND_OPP_PATH=${ASCEND_TOOLKIT_HOME}/opp
ENV LD_LIBRARY_PATH=${ASCEND_TOOLKIT_HOME}/runtime/lib64/stub:$LD_LIBRARY_PATH

# -- Build llama.cpp --
# Use the passed CHIP_TYPE argument and add general build options
# Note: GGML_CPU_ALL_VARIANTS causes build failures on CANN, matches upstream config
ARG CHIP_TYPE
RUN source /usr/local/Ascend/ascend-toolkit/set_env.sh --force \
    && \
    cmake -B build \
        -DGGML_CANN=ON \
        -DCMAKE_BUILD_TYPE=Release \
        -DSOC_TYPE=ascend${CHIP_TYPE} \
        -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath,\$ORIGIN" \
        . && \
    cmake --build build --config Release -j$(nproc)

# -- Organize build artifacts for copying in later stages --
# Create a lib directory to store all .so files
RUN mkdir -p /app/lib && \
    find build -name "*.so*" -exec cp -P {} /app/lib \;

# BodhiApp: Create BodhiApp-compatible folder structure
# CANN supports both x86_64 and aarch64
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        PLATFORM_TRIPLE="x86_64-unknown-linux-gnu"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        PLATFORM_TRIPLE="aarch64-unknown-linux-gnu"; \
    else \
        echo "Unsupported architecture: $ARCH" && exit 1; \
    fi && \
    mkdir -p /app/bin/$PLATFORM_TRIPLE/cann && \
    cp build/bin/llama-server /app/bin/$PLATFORM_TRIPLE/cann/ && \
    find /app/lib -name "*.so*" -exec cp -P {} /app/bin/$PLATFORM_TRIPLE/cann/ \; 2>/dev/null || true

# ==============================================================================
# BASE STAGE
# Create a minimal base image with CANN runtime and common libraries
# ==============================================================================
FROM ${CANN_BASE_IMAGE} AS base

# -- Install runtime dependencies --
RUN yum install -y libgomp curl && \
    yum clean all && \
    rm -rf /var/cache/yum

# -- Set CANN environment variables (required for runtime) --
ENV ASCEND_TOOLKIT_HOME=/usr/local/Ascend/ascend-toolkit/latest
ENV LD_LIBRARY_PATH=/app:${ASCEND_TOOLKIT_HOME}/lib64:${LD_LIBRARY_PATH}
ENV PATH=${ASCEND_TOOLKIT_HOME}/bin:${PATH}
ENV ASCEND_OPP_PATH=${ASCEND_TOOLKIT_HOME}/opp

WORKDIR /app

# BodhiApp: Copy BodhiApp-compatible folder structure instead of lib/
COPY --from=build /app/bin/ /app/bin/

# ==============================================================================
# SERVER STAGE
# Dedicated server image containing only llama-server
# ==============================================================================
FROM base AS server

# BodhiApp: Version metadata arguments
ARG BUILD_VERSION
ARG BUILD_COMMIT
ARG BUILD_TIMESTAMP
ARG BUILD_BRANCH
ARG CHIP_TYPE
ARG CANN_BASE_IMAGE

ENV LLAMA_ARG_HOST=0.0.0.0

# BodhiApp: Create non-root user for security
RUN groupadd -r llama && useradd -r -g llama -d /app -s /bin/bash llama && \
    chown -R llama:llama /app

# BodhiApp: Set up Ascend NPU environment
ENV ASCEND_VISIBLE_DEVICES=all

# BodhiApp: Embed version information in image
LABEL org.opencontainers.image.version="${BUILD_VERSION}"
LABEL org.opencontainers.image.revision="${BUILD_COMMIT}"
LABEL org.opencontainers.image.created="${BUILD_TIMESTAMP}"
LABEL bodhi.build.timestamp="${BUILD_TIMESTAMP}"
LABEL bodhi.build.branch="${BUILD_BRANCH}"
LABEL bodhi.variant="cann"
LABEL bodhi.cann.base_image="${CANN_BASE_IMAGE}"
LABEL bodhi.cann.chip_type="${CHIP_TYPE}"
LABEL bodhi.platform.compatibility="x86_64,aarch64"
LABEL bodhi.requires.gpu="huawei_ascend"

# BodhiApp: Create version file for runtime access
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        PLATFORM_TRIPLE="x86_64-unknown-linux-gnu"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        PLATFORM_TRIPLE="aarch64-unknown-linux-gnu"; \
    else \
        PLATFORM_TRIPLE="unknown"; \
    fi && \
    echo "{\"version\":\"${BUILD_VERSION}\",\"commit\":\"${BUILD_COMMIT}\",\"timestamp\":\"${BUILD_TIMESTAMP}\",\"variant\":\"cann\",\"branch\":\"${BUILD_BRANCH}\",\"cann_base_image\":\"${CANN_BASE_IMAGE}\",\"chip_type\":\"${CHIP_TYPE}\",\"platform\":\"$PLATFORM_TRIPLE\"}" > /app/version.json && \
    chown llama:llama /app/version.json

# BodhiApp: Use non-root user
USER llama

# BodhiApp: Health check - verify Ascend NPU availability and binary
# Note: npu-smi requires root, so we just check binary exists
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD ARCH=$(uname -m) && \
        if [ "$ARCH" = "x86_64" ]; then \
            test -x /app/bin/x86_64-unknown-linux-gnu/cann/llama-server; \
        elif [ "$ARCH" = "aarch64" ]; then \
            test -x /app/bin/aarch64-unknown-linux-gnu/cann/llama-server; \
        else \
            exit 1; \
        fi

# BodhiApp: Metadata labels
LABEL org.opencontainers.image.title="BodhiApp llama.cpp CANN Runtime"
LABEL org.opencontainers.image.description="CANN-enabled llama-server binary for BodhiApp integration (Huawei Ascend NPUs)"
LABEL org.opencontainers.image.source="https://github.com/BodhiSearch/llama.cpp"
