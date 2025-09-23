# BodhiApp Release Management for llama.cpp

This document describes the BodhiApp-specific release process for llama.cpp, which provides standardized Makefile-based releases for both binary builds and Docker base images.

## Overview

We use a tag-based release system where `make` commands create git tags that automatically trigger GitHub workflows. This pattern is consistent across BodhiSearch projects and minimizes merge conflicts with the upstream llama.cpp repository.

## Release Types

### 1. Binary Releases (llama-server)
- **Command**: `make release-server`
- **Creates**:
  - Release branch: `bodhiapp_YYYYMMDD` (e.g., `bodhiapp_20250923`)
  - Release tag: `llama-server/vYYYYMMDD` (e.g., `llama-server/v20250923`)
- **Artifacts**: Binary builds for macOS (ARM64), Ubuntu (x86_64, ARM64), Windows (x86_64)
- **Workflow**: `.github/workflows/llama-server.yml`

### 2. Docker Base Images
- **Command**: `make release-base-images`
- **Creates**:
  - Release branch: `bodhiapp_YYYYMMDD` (e.g., `bodhiapp_20250923`)
  - Release tag: `base-images/vYYYYMMDD` (e.g., `base-images/v20250923`)
- **Artifacts**: Docker images for CPU, CUDA, ROCm, and Vulkan variants
- **Workflow**: `.github/workflows/base-images.yml`

### 3. Upstream Synchronization
- **Check Command**: `make sync-upstream-check`
- **Sync Command**: `make sync-upstream`
- **Purpose**: Rebase master branch on latest upstream changes
- **Safety**: Does not automatically push - user controls when to push

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
│       ├── create-timestamp-version.sh    # Updated for YYYYMMDD format
│       └── sync-upstream.sh               # NEW: Upstream sync automation
└── .devops/
    └── base-images/
        └── Makefile             # Docker base image release logic
```

## Version Numbering

All releases use date-based versioning for chronological ordering:

**Format**: `YYYYMMDD`
- `YYYY`: 4-digit year
- `MM`: 2-digit month
- `DD`: 2-digit day

**Example**: `20250923` = September 23, 2025

This format matches your existing `bodhiapp_` branch naming convention and ensures:
- Clear chronological ordering
- No conflicts between releases on the same day
- Consistent with your current workflow

## Release Process

### Prerequisites

1. **Git Requirements**:
   - Clean working directory
   - On master branch (or confirm to continue on other branches)
   - Synced with origin/master (or confirm to continue out-of-sync)

2. **Permissions**:
   - Push access to create tags
   - GitHub Actions must be enabled

### Step-by-Step Workflow

#### Daily/Weekly Upstream Sync

```bash
# 1. Check what's new upstream (dry-run)
make sync-upstream-check

# 2. Sync with upstream (rebase master)
make sync-upstream

# 3. Review and test the rebased changes
git log --oneline -10

# 4. Push when ready
git push origin master --force-with-lease
```

#### Binary Release (llama-server)

```bash
# 1. Ensure you're on master and clean
git checkout master
git status  # Should be clean

# 2. Check what version would be created
make show-server-git-info

# 3. Create release branch and tag
make release-server
```

#### Docker Base Images Release

```bash
# 1. Ensure you're on master and clean
git checkout master
git status  # Should be clean

# 2. Check what version would be created
make show-server-git-info

# 3. Create release branch and tag
make release-base-images
```

#### Hotfix Old Release

```bash
# 1. Checkout the release branch
git checkout bodhiapp_20250820

# 2. Make your fixes and commit
# ... make changes ...
git commit -m "[Amir] hotfix: description"

# 3. Create hotfix tag
git tag llama-server/v20250820-hotfix1
git push origin llama-server/v20250820-hotfix1
```

### What Happens After Release

1. **Branch Created**: Release branch `bodhiapp_YYYYMMDD` preserves the exact state
2. **Tag Created**: Release tag triggers GitHub workflow automatically
3. **Multi-Platform Builds**: All supported platforms are built in parallel
4. **Artifact Upload**: Build artifacts are uploaded to GitHub release
5. **Back to Master**: You're automatically switched back to master for continued work
6. **Support Ready**: Release branch available for hotfixes anytime

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
# Release Commands
make release-server           # Release llama-server binaries (creates branch + tag)
make release-base-images      # Release Docker base images (creates branch + tag)

# Upstream Sync Commands
make sync-upstream-check      # Check what would be synced (dry-run)
make sync-upstream            # Rebase master on upstream (does not push)

# Utility Commands
make show-server-git-info     # Show version info for releases
make validate-server-release  # Check release prerequisites
make clean-server-release     # Clean local release tags
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

### Automated Upstream Sync

Our new workflow automates upstream integration:

1. **Daily/Weekly Sync**: `make sync-upstream-check` shows what's new
2. **Automated Rebase**: `make sync-upstream` rebases your changes on top
3. **Conflict Handling**: Clear instructions for manual resolution
4. **Safe Push**: User controls when to push rebased changes

### Branch-Based Release Strategy

This approach perfectly supports your rebase workflow:

1. **Release Branches**: `bodhiapp_YYYYMMDD` preserve exact release state
2. **Rebase-Safe**: Can rebase master without affecting old releases
3. **Hotfix Support**: Checkout any release branch for support
4. **Clear History**: `git log gg/master..bodhiapp_20250923` shows your changes

### Minimal Conflicts

Our implementation minimizes merge conflicts with upstream llama.cpp:

1. **Root Makefile**: Only 4 lines changed (commented deprecation + default + include)
2. **Separate Files**: All our logic in dedicated Makefiles
3. **Clean Separation**: Original build system unaffected
4. **Automated Sync**: Reduces manual merge work

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