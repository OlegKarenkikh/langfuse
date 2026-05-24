#!/bin/bash
ssh -o StrictHostKeyChecking=no root@v2202605357946459363.supersrv.de "cd app && docker compose ps && docker compose logs --tail=100 langfuse-web langfuse-worker"
