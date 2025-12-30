FROM public.ecr.aws/docker/library/node:22-alpine AS kysely-builder
RUN apk update && apk add --no-cache git
WORKDIR /kysely
RUN git clone https://github.com/OlegKarenkikh/kysely.git . && \
    git checkout 64a12c470b1a5387b842acf09094e2aa1e4149b0

RUN sed -i 's|git://github.com/kysely-org/kysely.git|https://github.com/OlegKarenkikh/kysely.git|' package.json

# ✅ Установить только TypeScript для компиляции
RUN npm install --no-save typescript@~5.9.3 --ignore-scripts

# Скомпилировать TypeScript → JavaScript
RUN npx tsc -p tsconfig.json && \
    npx tsc -p tsconfig-cjs.json

# Проверить что сборка успешна
RUN ls -la dist/cjs/index.js dist/esm/index.js || \
    (echo "❌ Build failed: dist files not found" && exit 1)

# Удалить только node_modules и test файлы, оставить оригинальный package.json
RUN rm -rf node_modules test example site .github

FROM public.ecr.aws/docker/library/node:22-alpine AS pruner
RUN apk update && apk add --no-cache libc6-compat tar gzip git
RUN npm install turbo@^2.6.1 --global
WORKDIR /app
COPY . .
RUN rm -rf packages/kysely
COPY --from=kysely-builder /kysely ./packages/kysely

RUN turbo prune --scope=worker --docker

FROM public.ecr.aws/docker/library/node:22-alpine AS builder
RUN apk update && apk add --no-cache libc6-compat git tar gzip python3 make g++ openssl openssl-dev
RUN npm install -g pnpm@9.15.0
RUN npm install -g turbo@^2.6.1

WORKDIR /app

# Ensure devDependencies are installed for build-time generators like prisma-kysely.
ENV PNPM_CONFIG_PRODUCTION=false

# First install the dependencies (as they change less often)
COPY --from=pruner /app/out/pnpm-lock.yaml ./pnpm-lock.yaml
COPY --from=pruner /app/out/pnpm-workspace.yaml ./pnpm-workspace.yaml
COPY --from=pruner /app/out/json/ .

# Update next to safe version
RUN pnpm update next --lockfile-only

RUN pnpm install --no-frozen-lockfile

# pass public variables in build step
ARG NEXT_PUBLIC_LANGFUSE_CLOUD_REGION
ARG NEXT_PUBLIC_DEMO_ORG_ID
ARG NEXT_PUBLIC_DEMO_PROJECT_ID
ARG NEXT_PUBLIC_POSTHOG_KEY
ARG NEXT_PUBLIC_POSTHOG_HOST

# Copy source code of isolated subworkspace
COPY --from=pruner /app/out/full/ .

RUN pnpm audit --audit-level=moderate

# ======= ДОБАВИТЬ ДИАГНОСТИКУ =======
RUN echo "=== Checking environment ===" && \
    echo "Node version: $(node --version)" && \
    echo "PNPM version: $(pnpm --version)" && \
    echo "Turbo version: $(turbo --version)" && \
    echo "" && \
    echo "=== Checking kysely ===" && \
    ls -la packages/kysely/dist/ || echo "kysely dist not found" && \
    ls -la packages/kysely/package.json && \
    cat packages/kysely/package.json | head -30 && \
    echo "" && \
    echo "=== Checking worker dependencies ===" && \
    cat worker/package.json | grep -A 5 '"dependencies"' && \
    echo "" && \
    echo "=== Checking workspace structure ===" && \
    ls -la packages/ && \
    ls -la worker/ && \
    echo "" && \
    echo "=== Checking pnpm workspace ===" && \
    pnpm list --depth=0 || true && \
    echo "" && \
    echo "=== Checking TypeScript in worker ===" && \
    cd worker && which tsc && tsc --version || echo "tsc not found in PATH"

# Попробуйте сначала собрать shared
RUN echo "=== Building shared package ===" && \
    pnpm turbo run build --filter=@langfuse/shared... --log-order=stream --output-logs=new-only || \
    (echo "❌ Failed to build shared" && exit 1)

# Теперь соберите worker с подробным логом
RUN echo "=== Building worker ===" && \
    pnpm turbo run build --filter=worker... --log-order=stream --output-logs=new-only || \
    (echo "❌ Failed to build worker, checking errors..." && \
     cd worker && pnpm run build 2>&1 || true && \
     exit 1)
# ======= КОНЕЦ ДИАГНОСТИКИ =======

RUN pnpm prune --prod

FROM public.ecr.aws/docker/library/node:22-alpine AS runner

ARG TARGETPLATFORM
ARG BUILDPLATFORM

RUN apk update && apk upgrade && apk add --no-cache libc6-compat shadow curl dumb-init && npm install -g npm@latest

WORKDIR /app

ARG NEXT_PUBLIC_BUILD_ID
ENV BUILD_ID=$NEXT_PUBLIC_BUILD_ID

ENV NODE_ENV=production
ENV DOCKER_BUILD=0

# Don't run production as root
ARG UID=1001
ARG GID=1001
RUN addgroup -S -g ${GID} expressjs && \
    adduser -S -u ${UID} -G expressjs expressjs
USER expressjs

COPY --from=builder --chown=expressjs:expressjs /app .
COPY --chown=expressjs:expressjs ./worker/entrypoint.sh ./worker/entrypoint.sh
RUN chmod +x ./worker/entrypoint.sh

EXPOSE 3030
ENV PORT=3030

# Docker ENTRYPOINT (dumb-init) is covered by semantic versioning, not the entrypoint.sh itself
# Reasoning: ENTRYPOINT is overridden by some self-hosted deployments, thus changing this is breaking
ENTRYPOINT ["/usr/bin/dumb-init", "--", "./worker/entrypoint.sh"]

# startup command
CMD ["node", "worker/dist/index.js"]
