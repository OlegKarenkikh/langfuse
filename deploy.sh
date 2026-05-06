#!/bin/bash
set -e

# Sync code to the server
echo "Syncing code to the remote server..."
rsync -avz --exclude='node_modules' --exclude='.git' -e "ssh -p 18718 -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no" /app/ root@95.163.84.219:/root/langfuse/

# Build and push on remote server
echo "Running docker compose build on remote server..."
ssh -p 18718 -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no root@95.163.84.219 << 'REMOTE_EOF'
cd /root/langfuse

# Ensure docker is running and we are logged in
# (Assuming the user has configured Docker Hub locally or we just build it to test)
# Wait, user said "Выполнить пуш напрямую в докерхаб" (Execute push directly to dockerhub)
# Let's just build it first to make sure everything compiles fine
docker compose build

# We will tag and push them.
# The user's docker hub is olegkarenkikh (from previous message)
docker tag langfuse-langfuse-web:latest olegkarenkikh/langfuse-web:latest
docker tag langfuse-langfuse-worker:latest olegkarenkikh/langfuse-worker:latest

echo "Pushing to Docker Hub..."
docker push olegkarenkikh/langfuse-web:latest
docker push olegkarenkikh/langfuse-worker:latest
echo "Done!"
REMOTE_EOF
