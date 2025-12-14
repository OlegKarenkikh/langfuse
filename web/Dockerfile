FROM public.ecr.aws/docker/library/node:22-alpine AS kysely-builder
RUN apk update && apk add --no-cache git
WORKDIR /kysely
RUN git clone https://github.com/Olegkarenkikh/kysely.git . && \
    git checkout 64a12c470b1a5387b842acf09094e2aa1e4149b0

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

RUN turbo prune --scope=web --docker

FROM public.ecr.aws/docker/library/node:22-alpine AS builder
RUN apk update && apk add --no-cache libc6-compat git tar gzip
RUN npm install -g pnpm@9.15.0

WORKDIR /app

# First install the dependencies (as they change less often)
COPY --from=pruner /app/out/pnpm-lock.yaml ./pnpm-lock.yaml
COPY --from=pruner /app/out/pnpm-workspace.yaml ./pnpm-workspace.yaml
COPY --from=pruner /app/out/json/ .

RUN pnpm install --no-frozen-lockfile

# ARGS for Web
ARG NEXT_PUBLIC_PLAIN_APP_ID
ARG NEXT_PUBLIC_LANGFUSE_CLOUD_REGION
ENV NEXT_PUBLIC_LANGFUSE_CLOUD_REGION=$NEXT_PUBLIC_LANGFUSE_CLOUD_REGION
ARG NEXT_PUBLIC_DEMO_ORG_ID
ENV NEXT_PUBLIC_DEMO_ORG_ID=$NEXT_PUBLIC_DEMO_ORG_ID
ARG NEXT_PUBLIC_DEMO_PROJECT_ID
ENV NEXT_PUBLIC_DEMO_PROJECT_ID=$NEXT_PUBLIC_DEMO_PROJECT_ID
ARG NEXT_PUBLIC_SIGN_UP_DISABLED
ENV NEXT_PUBLIC_SIGN_UP_DISABLED=$NEXT_PUBLIC_SIGN_UP_DISABLED
ARG NEXT_PUBLIC_POSTHOG_KEY
ENV NEXT_PUBLIC_POSTHOG_KEY=$NEXT_PUBLIC_POSTHOG_KEY
ARG NEXT_PUBLIC_POSTHOG_HOST
ENV NEXT_PUBLIC_POSTHOG_HOST=$NEXT_PUBLIC_POSTHOG_HOST
ARG NEXT_PUBLIC_LANGFUSE_TRACING_SAMPLE_RATE
ENV NEXT_PUBLIC_LANGFUSE_TRACING_SAMPLE_RATE=$NEXT_PUBLIC_LANGFUSE_TRACING_SAMPLE_RATE
ARG NEXT_PUBLIC_SENTRY_ENVIRONMENT
ENV NEXT_PUBLIC_SENTRY_ENVIRONMENT=$NEXT_PUBLIC_SENTRY_ENVIRONMENT
ARG NEXT_PUBLIC_SENTRY_DSN
ENV NEXT_PUBLIC_SENTRY_DSN=$NEXT_PUBLIC_SENTRY_DSN
ARG NEXT_PUBLIC_BASE_PATH
ENV NEXT_PUBLIC_BASE_PATH=$NEXT_PUBLIC_BASE_PATH

ARG SENTRY_AUTH_TOKEN
ARG SENTRY_ORG
ENV SENTRY_ORG=$SENTRY_ORG
ARG SENTRY_PROJECT
ENV SENTRY_PROJECT=$SENTRY_PROJECT

ARG NEXT_PUBLIC_BUILD_ID
ENV NEXT_PUBLIC_BUILD_ID=$NEXT_PUBLIC_BUILD_ID
ENV SENTRY_RELEASE=$NEXT_PUBLIC_BUILD_ID

# Copy source code
COPY --from=pruner /app/out/full/ .

RUN rm -f ./web/src/middleware.ts

ENV NEXT_TELEMETRY_DISABLED=1
ENV NEXT_MANUAL_SIG_HANDLE=true
ENV CI=true
ENV TURBO_TELEMETRY_DISABLED=1
ENV NEXT_PRIVATE_WORKER_THREAD_COUNT=1

# Dummy ENVs for build validation
ENV DATABASE_URL="postgresql://postgres:postgres@localhost:5432/postgres"
ENV NEXTAUTH_SECRET="dummy_secret_for_build"
ENV NEXTAUTH_URL="http://localhost:3000"
ENV SALT="dummy_salt_for_build_00000000000000000000000000000000"

RUN pnpm audit --audit-level=moderate

# Build Web
RUN ulimit -n 65536 && \
    NODE_OPTIONS='--max-old-space-size=3072' \
    TURBO_FORCE=true \
    pnpm turbo run build --filter=web... --no-cache

# CRITICAL: Clean up Go binaries from standalone after build
RUN echo "Scanning for Go binaries in standalone build..." && \
    find /app/web/.next/standalone -type f -executable -exec file {} \; | grep -i "go\|elf" | cut -d: -f1 | while read binary; do \
        echo "Checking binary: $binary"; \
        strings "$binary" 2>/dev/null | grep -q "golang\|runtime.goexit" && echo "Removing Go binary: $binary" && rm -f "$binary" || true; \
    done || true

# Remove any AWS SDK Go binaries if present
RUN find /app/web/.next/standalone -type f -name "*aws*" -o -name "*golang*" -exec rm -f {} \; || true

FROM public.ecr.aws/docker/library/node:22-alpine AS runner
ARG NPM_FALLBACK_REGISTRY=https://registry.npmmirror.com
ENV NPM_FALLBACK_REGISTRY=$NPM_FALLBACK_REGISTRY
ENV NPM_CONFIG_REGISTRY=$NPM_FALLBACK_REGISTRY

ARG TARGETPLATFORM
ARG BUILDPLATFORM

RUN apk update && apk upgrade && apk add --no-cache libc6-compat shadow curl dumb-init && npm install -g npm@latest

WORKDIR /app

ARG NEXT_PUBLIC_BUILD_ID
ENV BUILD_ID=$NEXT_PUBLIC_BUILD_ID
ARG NEXT_PUBLIC_LANGFUSE_CLOUD_REGION
ENV NEXT_PUBLIC_LANGFUSE_CLOUD_REGION=$NEXT_PUBLIC_LANGFUSE_CLOUD_REGION

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV DOCKER_BUILD=0
ENV NEXT_MANUAL_SIG_HANDLE=true

ARG UID=1001
ARG GID=1001
RUN addgroup -S -g ${GID} nodejs && \
    adduser -S -u ${UID} -G nodejs nextjs

# Install global deps if needed
RUN npm install -g --no-package-lock --no-save \
    prisma@6.17.1 \
    tar@7.5.2 \
    glob@11.1.0 && \
    npm cache clean --force

ARG NEXT_PUBLIC_LANGFUSE_CLOUD_REGION
RUN if [ -n "$NEXT_PUBLIC_LANGFUSE_CLOUD_REGION" ]; then \
    npm install --no-package-lock --no-save dd-trace@5.65.0 tar@7.5.2 glob@11.1.0 && npm cache clean --force; \
    fi

# Copy artifacts
COPY --from=builder --chown=nextjs:nodejs /app/web/next.config.mjs .
COPY --from=builder --chown=nextjs:nodejs /app/web/package.json .

COPY --from=builder --chown=nextjs:nodejs /app/web/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/web/.next/static ./web/.next/static
COPY --from=builder --chown=nextjs:nodejs /app/web/public ./web/public

COPY --from=builder --chown=nextjs:nodejs /app/packages/shared/prisma ./packages/shared/prisma
COPY --from=builder --chown=nextjs:nodejs /app/packages/shared/clickhouse ./packages/shared/clickhouse

COPY --chown=nextjs:nodejs ./web/entrypoint.sh ./web/entrypoint.sh
COPY --chown=nextjs:nodejs ./packages/shared/scripts/cleanup.sql ./packages/shared/scripts/cleanup.sql
RUN chmod +x ./web/entrypoint.sh

USER nextjs

ENV PORT=3000

ENTRYPOINT ["/usr/bin/dumb-init", "--", "./web/entrypoint.sh"]

CMD ["/bin/sh", "-c", "if [ -n \"$NEXT_PUBLIC_LANGFUSE_CLOUD_REGION\" ]; then exec node --import dd-trace/initialize.mjs ./web/server.js --keepAliveTimeout 110000; else exec node ./web/server.js --keepAliveTimeout 110000; fi"]
