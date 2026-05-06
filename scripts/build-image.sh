#!/bin/bash
# Build release images locally or in CI/CD pipeline
# Usage: ./scripts/build-image.sh [ENVIRONMENT] [TAG]

set -e

ENVIRONMENT="${1:-development}"
TAG="${2:-latest}"
IMAGE_NAME="mmio:${TAG}"
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
VCS_REF=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
VERSION="${TAG}"

# Validate environment
case "$ENVIRONMENT" in
  development|staging|production)
    echo "Building for environment: $ENVIRONMENT"
    ;;
  *)
    echo "Error: Invalid environment '$ENVIRONMENT'"
    echo "Valid options: development, staging, production"
    exit 1
    ;;
esac

# Load environment-specific settings
ENV_FILE=".env.${ENVIRONMENT}"
if [ -f "$ENV_FILE" ]; then
  echo "Loading environment from $ENV_FILE"
  export $(cat "$ENV_FILE" | grep -v '^#' | xargs)
else
  echo "Warning: $ENV_FILE not found, using defaults"
fi

echo "Building Docker image: $IMAGE_NAME"
echo "  Environment: $ENVIRONMENT"
echo "  Build Date: $BUILD_DATE"
echo "  VCS Ref: $VCS_REF"
echo "  Version: $VERSION"

docker build \
  --build-arg "BUILD_DATE=$BUILD_DATE" \
  --build-arg "VCS_REF=$VCS_REF" \
  --build-arg "VERSION=$VERSION" \
  --tag "$IMAGE_NAME" \
  --label "environment=$ENVIRONMENT" \
  .

echo "✓ Image built successfully: $IMAGE_NAME"
