#!/bin/bash
set -e

# Sync code to the server
echo "Syncing code to the remote server..."
rsync -avz --exclude='node_modules' --exclude='.git' -e "ssh -p 18718 -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no" /app/ root@95.163.84.219:/root/langfuse/

# Build and push on remote server
echo "Running docker build on remote server..."
ssh -p 18718 -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no root@95.163.84.219 << 'REMOTE_EOF'
cd /root/langfuse

echo "Building web..."
docker build -t olegkarenkikh/langfuse-web:latest -f web/Dockerfile . > build_web2.log 2>&1
docker push olegkarenkikh/langfuse-web:latest

REMOTE_EOF
echo "Done!"
