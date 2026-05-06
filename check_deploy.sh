#!/bin/bash
ssh -p 18718 -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no root@95.163.84.219 << 'REMOTE_EOF'
docker buildx ls
REMOTE_EOF
