.PHONY: help release-base-images show-git-info build-local test-local-images clean-local-images

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
	TAG_NAME="base-images/v$$VERSION" && \
	echo "New version from git commit: $$VERSION" && \
	echo "Tag to create: $$TAG_NAME" && \
	$(call delete_tag_if_exists,$$TAG_NAME) && \
	echo "Creating base images release tag $$TAG_NAME..." && \
	git tag "$$TAG_NAME" && \
	git push origin "$$TAG_NAME" && \
	echo "Base images release tag $$TAG_NAME pushed. GitHub workflow will handle the Docker image build and publish."


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
	for variant in cpu cuda rocm vulkan musa intel cann; do \
		echo "Building $$variant variant..." && \
		docker buildx build \
			--load \
			--build-arg BUILD_VERSION="$$VERSION" \
			--build-arg BUILD_COMMIT="$$(git rev-parse HEAD)" \
			--build-arg BUILD_TIMESTAMP="$$(git log -1 --format=%ct)" \
			--build-arg BUILD_BRANCH="$$(git branch --show-current)" \
			-f "$$variant.Dockerfile" \
			-t "llama.cpp:$$VERSION-$$variant" \
			../.. || exit 1; \
	done && \
	echo "All variants built successfully with version: $$VERSION"

test-local-images: ## Test locally built images
	@echo "Testing locally built base images..."
	@VERSION=$$($(call create_version_from_git)) && \
	for variant in cpu cuda rocm vulkan musa intel cann; do \
		echo "Testing $$variant variant..." && \
		docker run --rm "llama.cpp:$$VERSION-$$variant" --version || echo "Warning: $$variant test failed" && \
		echo "Testing version metadata for $$variant..." && \
		docker run --rm "llama.cpp:$$VERSION-$$variant" cat /app/version.json 2>/dev/null || echo "Warning: version.json not found in $$variant"; \
	done

clean-local-images: ## Clean up locally built images
	@echo "Cleaning up locally built base images..."
	@VERSION=$$($(call create_version_from_git)) && \
	for variant in cpu cuda rocm vulkan musa intel cann; do \
		docker rmi "llama.cpp:$$VERSION-$$variant" 2>/dev/null || true; \
	done && \
	echo "Cleanup complete"