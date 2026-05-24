#!/bin/bash

sudo rm -rf /var/lib/containerd
sudo rm -rf /var/lib/docker
sudo mkdir -p /etc/docker
sudo su -c 'cat << JSON > /etc/docker/daemon.json
{
  "storage-driver": "vfs"
}
JSON'
sudo systemctl restart containerd docker

docker run --rm -d --name test_worker mirror.gcr.io/library/node:24-alpine tail -f /dev/null
docker exec test_worker sh -c "rm -rf /root/.cache/node/corepack /root/.npm/_npx /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/corepack /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack 2>/dev/null || true"
docker commit test_worker worker_patched
docker stop test_worker

docker run --rm -v /var/run/docker.sock:/var/run/docker.sock mirror.gcr.io/aquasec/trivy:latest image --scanners vuln worker_patched

docker run --rm -d --name test_web mirror.gcr.io/library/node:24-alpine tail -f /dev/null
docker exec test_web sh -c "rm -rf /root/.cache/node/corepack /root/.npm/_npx /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/corepack /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack 2>/dev/null || true"
docker commit test_web web_patched
docker stop test_web

docker run --rm -v /var/run/docker.sock:/var/run/docker.sock mirror.gcr.io/aquasec/trivy:latest image --scanners vuln web_patched
