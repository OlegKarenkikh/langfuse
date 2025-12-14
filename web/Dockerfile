FROM public.ecr.aws/almalinux/almalinux:8 AS pruner
RUN dnf install -y --nogpgcheck almalinux-release \
    && dnf upgrade -y \
    && dnf install -y curl git \
    && curl -fsSL https://rpm.nodesource.com/setup_22.x | bash - \
    && dnf install -y nodejs tar gzip \
    && dnf clean all

ARG NPM_FALLBACK_REGISTRY=https://registry.npmmirror.com
ENV NPM_FALLBACK_REGISTRY=$NPM_FALLBACK_REGISTRY
ENV NPM_CONFIG_REGISTRY=$NPM_FALLBACK_REGISTRY

ENV NPM_CONFIG_FETCH_RETRIES=5
ENV NPM_CONFIG_FETCH_RETRY_FACTOR=2
ENV NPM_CONFIG_FETCH_RETRY_MINTIMEOUT=20000
ENV NPM_CONFIG_FETCH_RETRY_MAXTIMEOUT=120000
RUN NPM_CONFIG_STRICT_SSL=false npm install turbo@^2.6.1 --global

WORKDIR /app
COPY . .
# Убедиться что submodule инициализирован корректно
RUN rm -rf ./packages/kysely && \
    git submodule update --init --recursive packages/kysely || \
    ./scripts/ensure-kysely.sh

# FIX: Remove extra closing brace in kysely/site/package.json causing turbo prune failure
RUN sed -i '$d' packages/kysely/site/package.json

RUN if [ ! -f "./package.json" ] || ! grep -q '"packageManager"' ./package.json; then \
    echo "ERROR: Root package.json with packageManager field not found."; \
    echo "Please run docker build from the repository root with: docker build -f ./web/Dockerfile -t <tag> ."; \
    exit 1; \
    fi
RUN turbo prune --scope=web --docker

FROM public.ecr.aws/almalinux/almalinux:8 AS builder
RUN dnf install -y --nogpgcheck almalinux-release \
    && dnf upgrade -y \
    && dnf install -y curl git tar gzip file python39 make gcc-toolset-12-gcc gcc-toolset-12-gcc-c++ \
    && curl -fsSL https://rpm.nodesource.com/setup_22.x | bash - \
    && dnf install -y nodejs \
    && dnf clean all

ENV PYTHON=/usr/bin/python3.9
ENV PATH=/opt/rh/gcc-toolset-12/root/usr/bin:$PATH

ARG NPM_FALLBACK_REGISTRY=https://registry.npmmirror.com
ENV NPM_FALLBACK_REGISTRY=$NPM_FALLBACK_REGISTRY
ENV NPM_CONFIG_REGISTRY=$NPM_FALLBACK_REGISTRY

ENV NPM_CONFIG_FETCH_RETRIES=5
ENV NPM_CONFIG_FETCH_RETRY_FACTOR=2
ENV NPM_CONFIG_FETCH_RETRY_MINTIMEOUT=20000
ENV NPM_CONFIG_FETCH_RETRY_MAXTIMEOUT=120000
ENV NODE_TLS_REJECT_UNAUTHORIZED=0
ENV NPM_CONFIG_STRICT_SSL=false
ENV PNPM_CONFIG_STRICT_SSL=false
RUN NPM_CONFIG_STRICT_SSL=false npm install -g pnpm@9.15.0

ENV NEXT_PRIVATE_WORKER_THREAD_COUNT=2

WORKDIR /app

COPY --from=pruner /app/out/pnpm-lock.yaml ./pnpm-lock.yaml
COPY --from=pruner /app/out/pnpm-workspace.yaml ./pnpm-workspace.yaml
COPY --from=pruner /app/out/json/ .

RUN NPM_CONFIG_STRICT_SSL=false PNPM_CONFIG_STRICT_SSL=false NODE_TLS_REJECT_UNAUTHORIZED=0 pnpm install --frozen-lockfile

ENV DOCKER_BUILD=1
ENV NEXT_MANUAL_SIG_HANDLE=true

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

COPY --from=pruner /app/out/full/ .

RUN rm -f ./web/src/middleware.ts

ENV NEXT_TELEMETRY_DISABLED=1
ENV NEXT_MANUAL_SIG_HANDLE=true
ENV CI=true
ENV TURBO_TELEMETRY_DISABLED=1

RUN ulimit -n 65536 && \
    NODE_OPTIONS='--max-old-space-size=4096' \
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

FROM public.ecr.aws/almalinux/almalinux:8 AS runner
ARG NPM_FALLBACK_REGISTRY=https://registry.npmmirror.com
ENV NPM_FALLBACK_REGISTRY=$NPM_FALLBACK_REGISTRY
ENV NPM_CONFIG_REGISTRY=$NPM_FALLBACK_REGISTRY

WORKDIR /app

ARG NEXT_PUBLIC_BUILD_ID
ENV BUILD_ID=$NEXT_PUBLIC_BUILD_ID
ARG NEXT_PUBLIC_LANGFUSE_CLOUD_REGION
ENV NEXT_PUBLIC_LANGFUSE_CLOUD_REGION=$NEXT_PUBLIC_LANGFUSE_CLOUD_REGION

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV DOCKER_BUILD=0
ENV NEXT_MANUAL_SIG_HANDLE=true

RUN dnf install -y --nogpgcheck almalinux-release \
    && dnf install -y epel-release \
    && dnf upgrade -y \
    && dnf install -y curl shadow-utils dumb-init \
    && curl -fsSL https://rpm.nodesource.com/setup_22.x | bash - \
    && dnf install -y nodejs \
    && npm install -g npm@latest \
    && (rpm -e --nodeps $(rpm -qa | grep -E "^(python3-pip|platform-python-pip|python3-setuptools|platform-python-setuptools)") || true) \
    && dnf clean all

ARG UID=1001
ARG GID=1001
RUN groupadd -g ${GID} nodejs && \
    useradd -u ${UID} -g nodejs -m -s /bin/sh nextjs

RUN NPM_CONFIG_STRICT_SSL=false npm install -g --no-package-lock --no-save \
    prisma@6.17.1 \
    tar@7.5.2 \
    glob@11.1.0 && \
    npm cache clean --force

ARG NEXT_PUBLIC_LANGFUSE_CLOUD_REGION
RUN if [ -n "$NEXT_PUBLIC_LANGFUSE_CLOUD_REGION" ]; then \
    NPM_CONFIG_STRICT_SSL=false npm install --no-package-lock --no-save dd-trace@5.65.0 tar@7.5.2 glob@11.1.0 && npm cache clean --force; \
    fi

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
