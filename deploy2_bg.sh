#!/bin/bash
ssh -p 18718 -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no root@95.163.84.219 << 'REMOTE_EOF'
cd /root/langfuse

# Build with progress plain to avoid filling up the buffer and making SSH hang
echo "Building worker..."
docker build --progress=plain -t olegkarenkikh/langfuse-worker:latest -f worker/Dockerfile . > build_worker.log 2>&1

echo "Building web..."
docker build --progress=plain -t olegkarenkikh/langfuse-web:latest -f web/Dockerfile . > build_web.log 2>&1

echo "Pushing..."
docker push olegkarenkikh/langfuse-worker:latest
docker push olegkarenkikh/langfuse-web:latest
REMOTE_EOF
