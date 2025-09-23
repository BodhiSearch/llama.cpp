# BodhiApp Release Management for llama.cpp

This document describes the BodhiApp-specific release process for llama.cpp, which provides standardized Makefile-based releases for both binary builds and Docker base images.

## Overview

We use a tag-based release system where `make` commands create git tags that automatically trigger GitHub workflows. This pattern is consistent across BodhiSearch projects and minimizes merge conflicts with the upstream llama.cpp repository.

## Release Types

### 1. Binary Releases (llama-server)
- **Command**: `make release-server`
- **Tag Pattern**: `llama-server/v{timestamp}-{hash}` (e.g., `llama-server/v2508201420-abc1234`)
- **Artifacts**: Binary builds for macOS (ARM64), Ubuntu (x86_64, ARM64), Windows (x86_64)
- **Workflow**: `.github/workflows/llama-server.yml`

### 2. Docker Base Images
- **Command**: `make release-base-images`
- **Tag Pattern**: `base-images/v{timestamp}-{hash}` (e.g., `base-images/v2508201420-abc1234`)
- **Artifacts**: Docker images for CPU, CUDA, ROCm, and Vulkan variants
- **Workflow**: `.github/workflows/base-images.yml`

## File Structure

```
/
├── Makefile                      # Original Makefile with minimal BodhiApp additions
├── Makefile.bodhiapp            # llama-server release logic + delegation to base-images
├── README-bodhiapp.md           # This documentation
├── scripts/
│   └── release/                 # Release helper scripts
│       ├── git-check-branch.sh
│       ├── git-check-sync.sh
│       ├── delete-tag-if-exists.sh
│       └── create-timestamp-version.sh
└── .devops/
    └── base-images/
        └── Makefile             # Docker base image release logic
```

## Version Numbering

All releases use timestamp-based versioning for chronological ordering:

**Format**: `YYMMDDHHmm-githash`
- `YYMMDD`: Year, month, day (2-digit year)
- `HHmm`: Hour, minute (24-hour format)
- `githash`: 7-character git commit hash

**Example**: `2508201420-abc1234` = August 20, 2025, 2:20 PM, commit abc1234

## Release Process

### Prerequisites

1. **Git Requirements**:
   - Clean working directory
   - On master branch (or confirm to continue on other branches)
   - Synced with origin/master (or confirm to continue out-of-sync)

2. **Permissions**:
   - Push access to create tags
   - GitHub Actions must be enabled

### Step-by-Step Release

#### Binary Release (llama-server)

```bash
# 1. Ensure you're on master and synced
git checkout master
git pull origin master

# 2. Check what version would be created
make show-server-git-info

# 3. Create and push the release tag
make release-server
```

#### Docker Base Images Release

```bash
# 1. Ensure you're on master and synced
git checkout master
git pull origin master

# 2. Check what version would be created
make -C .devops/base-images show-git-info

# 3. Create and push the release tag
make release-base-images
```

### What Happens After Tag Push

1. **GitHub Workflow Triggers**: The appropriate workflow starts automatically
2. **Version Extraction**: Version information is extracted from the tag
3. **Multi-Platform Builds**: All supported platforms are built in parallel
4. **Artifact Upload**: Build artifacts are uploaded with version-tagged names
5. **GitHub Release**: A release is created with all artifacts

## Troubleshooting

### Tag Already Exists

The release scripts will detect existing tags and prompt for deletion:

```bash
Warning: Tag llama-server/v2508201420-abc1234 already exists.
Delete and recreate tag llama-server/v2508201420-abc1234? [y/N]
```

### Build Failures

If a platform build fails:
- The workflow continues with other platforms
- Failed builds are reported in the release summary
- Release is still created with successful artifacts

### Manual Workflow Trigger

Both workflows support manual triggering as a fallback:
1. Go to GitHub Actions tab
2. Select the appropriate workflow
3. Click "Run workflow"
4. Artifacts will use current commit for versioning

## Local Development

### Validation

Check release prerequisites without creating tags:

```bash
# Validate llama-server release setup
make validate-server-release

# Show version that would be created
make show-server-git-info
```

### Testing Base Images

Build and test Docker images locally:

```bash
# Build all variants locally
make -C .devops/base-images build-local

# Test the built images
make -C .devops/base-images test-local-images

# Clean up local images
make -C .devops/base-images clean-local-images
```

## Available Make Targets

### BodhiApp Targets (Makefile.bodhiapp)

```bash
make release-server           # Release llama-server binaries
make release-base-images      # Release Docker base images
make show-server-git-info     # Show llama-server version info
make validate-server-release  # Check llama-server prerequisites
make clean-server-release     # Clean local llama-server tags
make help-bodhiapp           # Show BodhiApp-specific help
```

### Base Images Specific (.devops/base-images/Makefile)

```bash
make -C .devops/base-images release-base-images  # Create release tag
make -C .devops/base-images show-git-info        # Show version info
make -C .devops/base-images build-local          # Build locally
make -C .devops/base-images test-local-images    # Test local builds
```

## Integration with Upstream

### Minimal Conflicts

Our implementation minimizes merge conflicts with upstream llama.cpp:

1. **Root Makefile**: Only 3 lines changed (commented deprecation + include)
2. **Separate Files**: All our logic in dedicated Makefiles
3. **Clean Separation**: Original build system unaffected

### Handling Upstream Updates

When merging upstream changes:

1. **Root Makefile**: Usually no conflicts (our changes at the end)
2. **Workflows**: May need updates if upstream changes workflow structure
3. **Scripts**: Isolated in our `scripts/release/` directory

## Release Artifacts

### Binary Releases

Artifacts follow this naming pattern:
```
llama-server--{platform}--{variant}
```

Examples:
- `llama-server--aarch64-apple-darwin--metal`
- `llama-server--x86_64-unknown-linux-gnu--cpu`
- `llama-server--x86_64-pc-windows-msvc--cpu`

Version information is embedded in the GitHub release name and tag.

### Docker Images

Images are pushed to `ghcr.io/bodhisearch/llama.cpp` with tags:
```
ghcr.io/bodhisearch/llama.cpp:{variant}-{version}
ghcr.io/bodhisearch/llama.cpp:latest-{variant}
```

Examples:
- `ghcr.io/bodhisearch/llama.cpp:cpu-2508201420-abc1234`
- `ghcr.io/bodhisearch/llama.cpp:cuda-2508201420-abc1234`
- `ghcr.io/bodhisearch/llama.cpp:latest-cpu`

## Support and Issues

For questions or issues with the BodhiApp release process:

1. Check this documentation first
2. Validate your setup with the validation targets
3. Look at recent successful releases for reference
4. Create an issue in the project repository

The release system is designed to be robust and provide clear feedback when issues occur.