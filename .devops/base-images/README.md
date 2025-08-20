# llama.cpp Base Images for BodhiApp

GPU-accelerated runtime base images containing llama-server binaries, designed for clean integration with BodhiApp.

## Purpose & Design Philosophy

These base images provide **BodhiApp-compatible runtime environments** with GPU-accelerated llama-server binaries. Unlike the official llama.cpp images that include development tools and multiple binaries, these images are **purpose-built for production deployment** as base layers in BodhiApp's containerized architecture.

### Derived from Official Patterns

Our Dockerfiles are **directly adapted from the proven configurations** in llama.cpp's official `.devops/` folder:
- **Source**: `.devops/cpu.Dockerfile`, `.devops/cuda.Dockerfile`, `.devops/vulkan.Dockerfile`, `.devops/rocm.Dockerfile`
- **Approach**: Use identical CMake configurations and multi-stage build patterns
- **Reliability**: Leverage battle-tested compilation flags and dependency management

### Key Similarities with Official Images

| **Aspect**              | **Official .devops/**         | **Our Base Images**            |
| ----------------------- | ----------------------------- | ------------------------------ |
| **Build Configuration** | ✅ Identical CMake flags       | ✅ Same proven settings         |
| **Multi-stage Builds**  | ✅ `build` → `base` → variants | ✅ `build` → `base` → `runtime` |
| **Dynamic Libraries**   | ✅ Extract `.so` files         | ✅ Copy shared libraries        |
| **GPU Runtime Images**  | ✅ Official base containers    | ✅ Same base containers         |
| **Compilation Targets** | ✅ All CPU variants, GPU archs | ✅ Identical target coverage    |

### Key Differences for BodhiApp

| **Aspect**      | **Official Images**                  | **Our Base Images**               |
| --------------- | ------------------------------------ | --------------------------------- |
| **Purpose**     | Development + tools                  | **Production runtime only**       |
| **Binaries**    | Multiple tools (cli, quantize, etc.) | **Single binary**: `llama-server` |
| **Interface**   | `tools.sh` script router             | **Direct binary execution**       |
| **Integration** | Standalone usage                     | **BodhiApp inheritance**          |
| **Versioning**  | Git tags                             | **Timestamp-based + git hash**    |
| **Metadata**    | Basic labels                         | **Rich runtime metadata**         |
| **ENTRYPOINT**  | Flexible tool selection              | **Predictable server behavior**   |

### Architecture Advantages

```
┌─────────────────────────┐    ┌─────────────────────────┐
│   Official .devops/     │    │   Our Base Images       │
│                         │    │                         │
│ Full toolchain          │    │ llama-server only       │
│ Development focus       │ => │ Production optimized    │
│ Multi-tool interface    │    │ Single binary focus     │
│ Generic usage           │    │ BodhiApp integration    │
└─────────────────────────┘    └─────────────────────────┘
```

## Available Images

| Variant    | Platform                     | Acceleration      | Registry                               |
| ---------- | ---------------------------- | ----------------- | -------------------------------------- |
| **CPU**    | `linux/amd64`, `linux/arm64` | CPU optimizations | `ghcr.io/bodhisearch/llama-cpp-cpu`    |
| **CUDA**   | `linux/amd64`                | NVIDIA GPU        | `ghcr.io/bodhisearch/llama-cpp-cuda`   |
| **ROCm**   | `linux/amd64`                | AMD GPU           | `ghcr.io/bodhisearch/llama-cpp-rocm`   |
| **Vulkan** | `linux/amd64`, `linux/arm64` | Cross-vendor GPU  | `ghcr.io/bodhisearch/llama-cpp-vulkan` |

## Versioning Strategy

Images use **timestamp-based versioning** for chronological ordering:
- Format: `yymmddhhmm-githash` (e.g., `2508201420-abc1234`)
- **Benefits**: Easy to see which version is newer, tied to git commits
- **Consistency**: All variants use the same version for unified tracking

## Quick Start

### Pull Images
```bash
# Latest versions
docker pull ghcr.io/bodhisearch/llama-cpp-cpu:latest
docker pull ghcr.io/bodhisearch/llama-cpp-cuda:latest

# Specific versions  
docker pull ghcr.io/bodhisearch/llama-cpp-cpu:2508201420-abc1234
```

### Run llama-server
```bash
# CPU variant
docker run --rm -p 8080:8080 \
  ghcr.io/bodhisearch/llama-cpp-cpu:latest \
  --host 0.0.0.0 --port 8080

# CUDA variant (requires --gpus flag)  
docker run --rm --gpus all -p 8080:8080 \
  ghcr.io/bodhisearch/llama-cpp-cuda:latest \
  --host 0.0.0.0 --port 8080
```

### Use with BodhiApp
```dockerfile
# BodhiApp Dockerfile
ARG BASE_VARIANT=cpu
FROM ghcr.io/bodhisearch/llama-cpp-${BASE_VARIANT}:latest AS runtime-base

# BodhiApp build stage
FROM rust:1.87.0-bookworm AS bodhiapp-build
# ... your BodhiApp build process ...

# Final stage - inherit GPU runtime
FROM runtime-base
COPY --from=bodhiapp-build /build/target/*/bodhi /app/bodhi

# llama-server available at /app/bin/llama-server
ENV BODHI_LLAMA_SERVER_PATH=/app/bin/llama-server
ENTRYPOINT ["/app/bodhi"]
CMD ["serve"]
```

## Version Metadata

Each image embeds comprehensive version information:

### Docker Labels (via `docker inspect`)
```bash
docker inspect ghcr.io/bodhisearch/llama-cpp-cpu:2508201420-abc1234 | \
  jq '.[0].Config.Labels'
```

### Runtime Version File
```bash
# Check version info at runtime
docker run --rm ghcr.io/bodhisearch/llama-cpp-cpu:latest cat /app/version.json

# Example output:
{
  "version": "2508201420-abc1234",
  "commit": "abc1234567890abcdef1234567890abcdef123456", 
  "timestamp": "2508201420",
  "variant": "cpu",
  "branch": "master"
}
```

## Release Process

### Using Makefile (Recommended)

```bash
# Check current versions
make check-base-images-version

# Show what version would be created
make show-git-info  

# Create and push release tag
make release-base-images
```

### Manual Process

```bash
# Generate timestamp-based version
TIMESTAMP=$(git log -1 --format=%ct | xargs -I {} date -d @{} +%y%m%d%H%M)
COMMIT=$(git rev-parse --short=7 HEAD)
VERSION="$TIMESTAMP-$COMMIT"

# Create and push tag
git tag "base-images/v$VERSION"
git push origin "base-images/v$VERSION"

# GitHub workflow automatically builds and publishes all variants
```

## Image Contents

Each base image contains the minimal components needed for production deployment:

```
/app/
├── bin/llama-server       # GPU-accelerated llama-server binary
├── lib*.so               # Dynamic backend libraries (CPU variants, CUDA, etc.)
└── version.json          # Runtime-accessible version metadata
```

**Key Features:**
- ✅ **Single binary focus**: Only llama-server (no cli/quantize tools)
- ✅ **Dynamic backend loading**: GPU libraries loaded at runtime
- ✅ **Embedded metadata**: Version info accessible via labels and files
- ✅ **Non-root execution**: Runs as `llama` user for security
- ✅ **Health checks**: GPU-aware health verification
- ✅ **Clean inheritance**: Simple ENTRYPOINT/CMD pattern

### Configuration Validation

Our build process validates that the CMake configuration matches the official patterns:

```bash
# Proven configuration (identical to official .devops/)
-DGGML_NATIVE=OFF                    # Portable builds
-DGGML_CPU_ALL_VARIANTS=ON          # All CPU optimizations
-DGGML_BACKEND_DL=ON                # Dynamic backend loading
-DGGML_CUDA=ON                      # GPU acceleration (variant-specific)
-DLLAMA_BUILD_TESTS=OFF             # Skip tests for production
```

This ensures **maximum compatibility** with hardware while maintaining **production reliability**.

## Local Development

### Build Images Locally
```bash
# Build all variants with current git version
make build-local

# Test built images
make test-local-images

# Clean up
make clean-local-images
```

### Manual Build
```bash
# Build specific variant
docker buildx build \
  --build-arg BUILD_VERSION="$(git log -1 --format=%ct | xargs -I {} date -d @{} +%y%m%d%H%M)-$(git rev-parse --short=7 HEAD)" \
  --build-arg BUILD_COMMIT="$(git rev-parse HEAD)" \
  --build-arg BUILD_TIMESTAMP="$(git log -1 --format=%ct)" \
  --build-arg BUILD_BRANCH="$(git branch --show-current)" \
  -f cpu.Dockerfile \
  -t llama-cpp-cpu:local \
  ../..
```

## Architecture

### Simple Inheritance Pattern
```
┌─────────────────────────┐    ┌─────────────────────────┐
│     Base Image          │    │      BodhiApp           │
│                         │    │                         │
│ /app/bin/llama-server   │◄───┤ /app/bodhi              │
│ /app/version.json       │    │                         │
│ GPU Runtime Libraries   │    │ Uses base image's       │
│ (CUDA/ROCm/Vulkan/CPU)  │    │ llama-server binary     │
└─────────────────────────┘    └─────────────────────────┘
```

### ENTRYPOINT/CMD Behavior
```dockerfile  
# Base image
ENTRYPOINT ["/app/bin/llama-server"]
CMD ["--help"]

# Usage examples:
docker run image                    # → /app/bin/llama-server --help
docker run image --host 0.0.0.0    # → /app/bin/llama-server --host 0.0.0.0

# BodhiApp overrides completely:
ENTRYPOINT ["/app/bodhi"]           # → /app/bodhi serve
CMD ["serve"]
```

## GPU Requirements

### NVIDIA CUDA
- **Driver**: NVIDIA Driver 470+ required on host
- **Runtime**: Use `--gpus all` flag or Docker Compose GPU config
- **Architectures**: Supports compute capability 7.0+ (V100, RTX 20xx+)

### AMD ROCm  
- **Driver**: ROCm 6.x drivers required on host
- **Devices**: Mount `/dev/kfd` and `/dev/dri` 
- **GPUs**: RDNA/CDNA architectures (RX 6000+, MI series)

### Vulkan
- **Drivers**: Vulkan-compatible drivers (NVIDIA, AMD, Intel)
- **Devices**: Mount `/dev/dri` for hardware access
- **Cross-vendor**: Works with any Vulkan 1.3+ compatible GPU

## Troubleshooting

### Version Information
```bash
# Check what version is running
docker run --rm image cat /app/version.json

# Compare with git history  
git log --oneline --since="$(date -d '2025-08-20 14:20' '+%Y-%m-%d %H:%M')"
```

### GPU Access Issues
```bash
# NVIDIA: Verify GPU access
docker run --rm --gpus all nvidia/cuda:12.6.2-base-ubuntu24.04 nvidia-smi

# AMD: Verify ROCm access  
docker run --rm --device=/dev/kfd --device=/dev/dri rocm/dev-ubuntu-24.04:6.4 rocm-smi

# Vulkan: Verify Vulkan access
docker run --rm --device=/dev/dri ubuntu:24.04 vulkaninfo
```

### Build Issues
```bash
# Check build logs
docker buildx build --progress=plain -f cpu.Dockerfile ../..

# Verify build arguments
make show-git-info
```

## Development & Contributing

### Maintaining Compatibility with Official Patterns

When updating these images, **always derive from the official `.devops/` configurations**:

1. **Check upstream changes** in llama.cpp's `.devops/` folder
2. **Adapt CMake flags** - keep build configuration identical to official
3. **Preserve multi-stage structure** - maintain `build` → `base` → `runtime` pattern
4. **Test compatibility** - ensure builds work with official dependency chain

### Contributing Process

1. **Make changes** to Dockerfiles or Makefile
2. **Validate against official patterns** - compare with `.devops/` configurations
3. **Test locally** with `make build-local`
4. **Create release** with `make release-base-images`
5. **GitHub workflow** automatically builds and publishes all variants
6. **Verify release** at https://github.com/orgs/BodhiSearch/packages

### Configuration Updates

When llama.cpp updates their build configuration:

```bash
# Compare our configuration with upstream
diff .devops/base-images/cpu.Dockerfile .devops/cpu.Dockerfile

# Update to match official CMake flags
# Maintain BodhiApp-specific adaptations (single binary, metadata, etc.)
```

## Integration Examples

### Direct Usage
```bash
# Run inference server
docker run -d --name llama-server --gpus all -p 8080:8080 \
  ghcr.io/bodhisearch/llama-cpp-cuda:latest \
  --host 0.0.0.0 --port 8080 --model /models/model.gguf
```

### BodhiApp Integration  
```dockerfile
FROM ghcr.io/bodhisearch/llama-cpp-cuda:2508201420-abc1234 AS runtime-base
FROM bodhiapp-build AS build
FROM runtime-base
COPY --from=build /app/bodhi /app/bodhi
ENV BODHI_LLAMA_SERVER_PATH=/app/bin/llama-server
ENTRYPOINT ["/app/bodhi"] 
```

This architecture provides BodhiApp with GPU-accelerated llama-server binaries while maintaining clean separation and predictable integration patterns.