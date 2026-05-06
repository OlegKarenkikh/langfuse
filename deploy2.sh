#!/bin/bash
set -e

echo "Running docker build on remote server..."
ssh -p 18718 -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no root@95.163.84.219 << 'REMOTE_EOF'
cd /root/langfuse

# Clean up memory
docker builder prune -f
echo "Building worker..."
docker build -t olegkarenkikh/langfuse-worker:latest -f worker/Dockerfile .
echo "Building web..."
docker build -t olegkarenkikh/langfuse-web:latest -f web/Dockerfile .

echo "Pushing to Docker Hub..."
docker push olegkarenkikh/langfuse-worker:latest
docker push olegkarenkikh/langfuse-web:latest
echo "Done!"
REMOTE_EOF
