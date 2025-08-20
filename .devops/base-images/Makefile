.PHONY: help release-base-images check-base-images-version

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Base Images Release Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9._-]+:.*?## / {printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Function to check git branch status - borrowed from BodhiApp
define check_git_branch
	@CURRENT_BRANCH=$$(git branch --show-current) && \
	if [ "$$CURRENT_BRANCH" != "master" ]; then \
		read -p "Warning: You are not on master branch (current: $$CURRENT_BRANCH). Continue? [y/N] " confirm && \
		if [ "$$confirm" != "y" ]; then \
			echo "Aborting release." && exit 1; \
		fi \
	fi && \
	echo "Fetching latest changes from remote..." && \
	git fetch origin master && \
	LOCAL_HEAD=$$(git rev-parse HEAD) && \
	REMOTE_HEAD=$$(git rev-parse origin/master) && \
	if [ "$$LOCAL_HEAD" != "$$REMOTE_HEAD" ]; then \
		echo "Warning: Your local master branch is different from origin/master" && \
		echo "Local:  $$LOCAL_HEAD" && \
		echo "Remote: $$REMOTE_HEAD" && \
		read -p "Continue anyway? [y/N] " confirm && \
		if [ "$$confirm" != "y" ]; then \
			echo "Aborting release." && exit 1; \
		fi \
	fi
endef

# Function to safely delete existing tag - borrowed from BodhiApp
define delete_tag_if_exists
	echo "Checking for existing tag $(1)..." && \
	if git rev-parse "$(1)" >/dev/null 2>&1; then \
		read -p "Tag $(1) already exists. Delete and recreate? [y/N] " confirm && \
		if [ "$$confirm" = "y" ]; then \
			echo "Deleting existing tag $(1)..." && \
			git tag -d "$(1)" 2>/dev/null || true && \
			git push --delete origin "$(1)" 2>/dev/null || true; \
		else \
			echo "Aborting release." && exit 1; \
		fi \
	fi
endef

# Function to get current version from GHCR for base images
# Usage: $(call get_ghcr_base_images_version)
define get_ghcr_base_images_version
	REPO_OWNER=BodhiSearch && \
	PACKAGE_NAME=llama-cpp-cpu && \
	GHCR_RESPONSE=$$(gh api "/orgs/$$REPO_OWNER/packages/container/$$PACKAGE_NAME/versions" 2>/dev/null || echo "Package not found") && \
	if echo "$$GHCR_RESPONSE" | grep -q "Package not found"; then \
		echo "0.0.0"; \
	else \
		echo "$$GHCR_RESPONSE" | jq -r '[.[] | select(.metadata.container.tags[]? | test("^[0-9]{10}-[a-f0-9]{7}$$"))] | sort_by(.created_at) | last | .metadata.container.tags[] | select(test("^[0-9]{10}-[a-f0-9]{7}$$"))' 2>/dev/null || echo "0.0.0"; \
	fi
endef

# Function to create timestamp-based version from git commit
define create_version_from_git
	COMMIT_TIMESTAMP=$$(git log -1 --format=%ct) && \
	COMMIT_HASH=$$(git rev-parse --short=7 HEAD) && \
	if [ "$$(uname)" = "Darwin" ]; then \
		VERSION="$$(date -r $$COMMIT_TIMESTAMP +%y%m%d%H%M)-$$COMMIT_HASH"; \
	else \
		VERSION="$$(date -d @$$COMMIT_TIMESTAMP +%y%m%d%H%M)-$$COMMIT_HASH"; \
	fi && \
	echo "$$VERSION"
endef

release-base-images: ## Create and push tag for base images release (timestamp-based versioning)
	@echo "Preparing to release llama.cpp base images..."
	$(call check_git_branch)
	@echo "Creating version from current git commit..."
	@VERSION=$$($(call create_version_from_git)) && \
	CURRENT_VERSION=$$($(call get_ghcr_base_images_version)) && \
	TAG_NAME="base-images/v$$VERSION" && \
	echo "Current latest version (from GHCR): $$CURRENT_VERSION" && \
	echo "New version from git commit: $$VERSION" && \
	echo "Tag to create: $$TAG_NAME" && \
	if [ "$$VERSION" = "$$CURRENT_VERSION" ]; then \
		echo "Error: Version $$VERSION already exists in registry. No changes to commit since last release."; \
		echo "Please make a new commit or use a different commit."; \
		exit 1; \
	fi && \
	$(call delete_tag_if_exists,$$TAG_NAME) && \
	echo "Creating base images release tag $$TAG_NAME..." && \
	git tag "$$TAG_NAME" && \
	git push origin "$$TAG_NAME" && \
	echo "Base images release tag $$TAG_NAME pushed. GitHub workflow will handle the Docker image build and publish."

check-base-images-version: ## Check latest version of base images from GHCR
	@echo "=== Latest Base Images Release Version (from GHCR) ==="
	@echo "Base Images (llama-cpp variants):"
	@LATEST_VERSION=$$($(call get_ghcr_base_images_version)) && \
	if [ "$$LATEST_VERSION" = "0.0.0" ]; then \
		echo "  Latest: No releases found"; \
	else \
		echo "  Latest: $$LATEST_VERSION"; \
		COMMIT_HASH=$$(echo "$$LATEST_VERSION" | cut -d'-' -f2) && \
		TIMESTAMP=$$(echo "$$LATEST_VERSION" | cut -d'-' -f1) && \
		if [ "$$(uname)" = "Darwin" ]; then \
			READABLE_DATE=$$(date -j -f "%y%m%d%H%M" "$$TIMESTAMP" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "Invalid timestamp"); \
		else \
			READABLE_DATE=$$(date -d "20$$TIMESTAMP" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "Invalid timestamp"); \
		fi && \
		echo "  Timestamp: $$READABLE_DATE ($$TIMESTAMP)" && \
		echo "  Git commit: $$COMMIT_HASH"; \
	fi
	@echo ""
	@echo "Next version would be:"
	@NEXT_VERSION=$$($(call create_version_from_git)) && \
	NEXT_COMMIT_HASH=$$(echo "$$NEXT_VERSION" | cut -d'-' -f2) && \
	NEXT_TIMESTAMP=$$(echo "$$NEXT_VERSION" | cut -d'-' -f1) && \
	if [ "$$(uname)" = "Darwin" ]; then \
		NEXT_READABLE_DATE=$$(date -j -f "%y%m%d%H%M" "$$NEXT_TIMESTAMP" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "Invalid timestamp"); \
	else \
		NEXT_READABLE_DATE=$$(date -d "20$$NEXT_TIMESTAMP" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "Invalid timestamp"); \
	fi && \
	echo "  Version: $$NEXT_VERSION" && \
	echo "  Timestamp: $$NEXT_READABLE_DATE ($$NEXT_TIMESTAMP)" && \
	echo "  Git commit: $$NEXT_COMMIT_HASH"
	@echo "==============================="

show-git-info: ## Show current git commit information for version generation
	@echo "=== Git Information for Version Generation ==="
	@COMMIT_TIMESTAMP=$$(git log -1 --format=%ct) && \
	COMMIT_HASH=$$(git rev-parse --short=7 HEAD) && \
	if [ "$$(uname)" = "Darwin" ]; then \
		READABLE_DATE=$$(date -r $$COMMIT_TIMESTAMP "+%Y-%m-%d %H:%M:%S") && \
		VERSION="$$(date -r $$COMMIT_TIMESTAMP +%y%m%d%H%M)-$$COMMIT_HASH"; \
	else \
		READABLE_DATE=$$(date -d @$$COMMIT_TIMESTAMP "+%Y-%m-%d %H:%M:%S") && \
		VERSION="$$(date -d @$$COMMIT_TIMESTAMP +%y%m%d%H%M)-$$COMMIT_HASH"; \
	fi && \
	echo "Current commit: $$COMMIT_HASH" && \
	echo "Commit timestamp: $$COMMIT_TIMESTAMP" && \
	echo "Readable date: $$READABLE_DATE" && \
	echo "Generated version: $$VERSION" && \
	echo "Tag would be: base-images/v$$VERSION"
	@echo "============================================="

build-local: ## Build base images locally for testing (requires Docker Buildx)
	@echo "Building base images locally for testing..."
	@if ! command -v docker >/dev/null 2>&1; then \
		echo "Error: Docker is required but not installed"; \
		exit 1; \
	fi
	@if ! docker buildx version >/dev/null 2>&1; then \
		echo "Error: Docker Buildx is required but not available"; \
		exit 1; \
	fi
	@VERSION=$$($(call create_version_from_git)) && \
	echo "Building with version: $$VERSION" && \
	for variant in cpu cuda rocm vulkan; do \
		echo "Building $$variant variant..." && \
		docker buildx build \
			--load \
			--build-arg BUILD_VERSION="$$VERSION" \
			--build-arg BUILD_COMMIT="$$(git rev-parse HEAD)" \
			--build-arg BUILD_TIMESTAMP="$$(git log -1 --format=%ct)" \
			--build-arg BUILD_BRANCH="$$(git branch --show-current)" \
			-f "$$variant.Dockerfile" \
			-t "llama-cpp-$$variant:$$VERSION" \
			../.. || exit 1; \
	done && \
	echo "All variants built successfully with version: $$VERSION"

test-local-images: ## Test locally built images
	@echo "Testing locally built base images..."
	@VERSION=$$($(call create_version_from_git)) && \
	for variant in cpu cuda rocm vulkan; do \
		echo "Testing $$variant variant..." && \
		docker run --rm "llama-cpp-$$variant:$$VERSION" --version || echo "Warning: $$variant test failed" && \
		echo "Testing version metadata for $$variant..." && \
		docker run --rm "llama-cpp-$$variant:$$VERSION" cat /app/version.json 2>/dev/null || echo "Warning: version.json not found in $$variant"; \
	done

clean-local-images: ## Clean up locally built images
	@echo "Cleaning up locally built base images..."
	@VERSION=$$($(call create_version_from_git)) && \
	for variant in cpu cuda rocm vulkan; do \
		docker rmi "llama-cpp-$$variant:$$VERSION" 2>/dev/null || true; \
	done && \
	echo "Cleanup complete"