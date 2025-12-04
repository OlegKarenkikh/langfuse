#!/bin/bash
set -e

# Usage: ./scripts/build-and-push.sh <docker_token>

USER="olegkarenkikh"
REPO="langfuse"
TOKEN=$1

if [ -z "$TOKEN" ]; then
  echo "Usage: $0 <docker_token>"
  echo "Example: $0 dckr_pat_..."
  exit 1
fi

echo "Logging in to Docker Hub..."
echo "$TOKEN" | docker login -u "$USER" --password-stdin

echo "Building web image from root context..."
# Check if running from root
if [ ! -f "pnpm-workspace.yaml" ]; then
  echo "Error: This script must be run from the repository root."
  exit 1
fi

docker build -f web/Dockerfile -t "$USER/$REPO:web" .

echo "Building worker image from root context..."
docker build -f worker/Dockerfile -t "$USER/$REPO:worker" .

echo "Pushing web image..."
docker push "$USER/$REPO:web"

echo "Pushing worker image..."
docker push "$USER/$REPO:worker"

echo "Done."
