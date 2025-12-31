# ============================================
# Stage 1: Alpine Base with Security Updates
# ============================================
FROM --platform=${TARGETPLATFORM:-linux/amd64} node:24-alpine AS alpine

RUN apk update && \
    apk upgrade --no-cache \
    libcrypto3 \
    libssl3 \
    libc6-compat \
    busybox \
    ssl_client

# ============================================
# Stage 2: Build Custom Kysely (CVE-free fork)
# ============================================
FROM alpine AS kysely-builder

RUN apk add --no-cache git

WORKDIR /kysely

RUN git clone https://github.com/OlegKarenkikh/kysely.git . && \
    git checkout 64a12c470b1a5387b842acf09094e2aa1e4149b0

RUN sed -i 's|git://github.com/kysely-org/kysely.git|https://github.com/OlegKarenkikh/kysely.git|' package.json

RUN npm install --no-save typescript@~5.9.3 --ignore-scripts

RUN npx tsc -p tsconfig.json && \
    npx tsc -p tsconfig-cjs.json

RUN ls -la dist/cjs/index.js dist/esm/index.js || \
    (echo "❌ Kysely build failed" && exit 1)

RUN rm -rf node_modules test site example docs .github

# ============================================
# Stage 3: Base with Package Managers
# ============================================
FROM alpine AS base

RUN npm install turbo@^2.7.1 --global

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable && \
    corepack prepare pnpm@9.5.0 --activate

# ============================================
# Stage 4: Prune Workspace
# ============================================
FROM base AS pruner

WORKDIR /app

COPY . .

RUN rm -rf packages/kysely
COPY --from=kysely-builder /kysely ./packages/kysely

RUN node -e "try { \
      JSON.parse(require('fs').readFileSync('./packages/kysely/package.json', 'utf8')); \
      console.log('✅ kysely package.json is valid'); \
    } catch(e) { \
      console.error('❌ Invalid kysely package.json:', e.message); \
      process.exit(1); \
    }"

RUN pnpm install --lockfile-only || true

RUN turbo prune --scope=web --docker

# ============================================
# Stage 5: Build Web Application
# ============================================
FROM base AS builder

WORKDIR /app

COPY --from=pruner /app/out/pnpm-lock.yaml ./pnpm-lock.yaml
COPY --from=pruner /app/out/pnpm-workspace.yaml ./pnpm-workspace.yaml
COPY --from=pruner /app/out/json/ .

# Disable preinstall script in Docker (kysely is already installed via multi-stage build)
# Remove preinstall from root package.json to avoid ensure-kysely.sh script error
RUN node -e "const fs=require('fs'); if(fs.existsSync('package.json')) { const pkg=JSON.parse(fs.readFileSync('package.json')); if(pkg.scripts && pkg.scripts.preinstall) { delete pkg.scripts.preinstall; fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2)); } }"

# Limit concurrency to prevent OOM during install
ENV PNPM_CONFIG_NETWORK_CONCURRENCY=3
RUN pnpm install --no-frozen-lockfile

# Docker build flags
ENV DOCKER_BUILD=1
ENV NEXT_MANUAL_SIG_HANDLE=true

# Build-time environment variables for Next.js
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

# Sentry configuration (only for Cloud deployments)
ARG SENTRY_AUTH_TOKEN
ENV SENTRY_AUTH_TOKEN=$SENTRY_AUTH_TOKEN
ARG SENTRY_ORG
ENV SENTRY_ORG=$SENTRY_ORG
ARG SENTRY_PROJECT
ENV SENTRY_PROJECT=$SENTRY_PROJECT

ARG NEXT_PUBLIC_BUILD_ID
ENV NEXT_PUBLIC_BUILD_ID=$NEXT_PUBLIC_BUILD_ID
ENV SENTRY_RELEASE=$NEXT_PUBLIC_BUILD_ID

COPY --from=pruner /app/out/full/ .

# Remove middleware.ts (not needed in self-hosted)
RUN rm -f ./web/src/middleware.ts

# Disable telemetry
ENV NEXT_TELEMETRY_DISABLED=1
ENV NEXT_MANUAL_SIG_HANDLE=true
ENV CI=true

# DATABASE_URL is required by prisma.config.ts for Prisma Client generation
# Set it as ENV so it's available for all commands including turbo tasks
ENV DATABASE_URL="postgresql://dummy:dummy@localhost:5432/dummy"

# Generate Prisma Client for web
# Generate after install to ensure all dependencies are available
RUN cd packages/shared && npx prisma generate

# Verify Prisma Client was generated
RUN if find node_modules -name ".prisma" -type d 2>/dev/null | head -1 | grep -q .; then \
        echo "✅ Prisma Client generated successfully"; \
    else \
        echo "⚠️ Prisma Client verification: .prisma directory not found" && \
        echo "Checking node_modules structure..." && \
        find node_modules -name ".prisma" -type d 2>/dev/null | head -5 || true; \
    fi

# Build web application with optimized memory settings
# Use 4GB memory limit for better compatibility with limited resources
RUN NODE_OPTIONS='--max-old-space-size=4096' \
    turbo run build --filter=web...

# Verify Next.js standalone output
RUN ls -la web/.next/standalone/web/server.js || \
    (echo "❌ Web build failed: standalone output not found" && exit 1)

# Security audit
RUN pnpm audit --audit-level=moderate --production || \
    echo "⚠️ Security vulnerabilities found"

# ============================================
# Stage 6: Production Runtime
# ============================================
FROM base AS runner

ARG TARGETPLATFORM
ARG BUILDPLATFORM

WORKDIR /app

ARG NEXT_PUBLIC_BUILD_ID
ENV BUILD_ID=$NEXT_PUBLIC_BUILD_ID
ARG NEXT_PUBLIC_LANGFUSE_CLOUD_REGION
ENV NEXT_PUBLIC_LANGFUSE_CLOUD_REGION=$NEXT_PUBLIC_LANGFUSE_CLOUD_REGION

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV DOCKER_BUILD=0
ENV NEXT_MANUAL_SIG_HANDLE=true

RUN apk add --no-cache dumb-init tzdata

# Security: Don't run as root
ARG UID=1001
ARG GID=1001
RUN addgroup --system --gid ${GID} nodejs && \
    adduser --system --uid ${UID} nextjs

# Install Prisma CLI for migrations
RUN npm install -g --no-package-lock --no-save prisma@7.2.0

# Install dd-trace only for Cloud deployments
ARG NEXT_PUBLIC_LANGFUSE_CLOUD_REGION
RUN if [ -n "$NEXT_PUBLIC_LANGFUSE_CLOUD_REGION" ]; then \
      npm install --no-package-lock --no-save dd-trace@5.81.0; \
    fi

# Install migrate tool for database migrations
RUN MIGRATE_TARGET_ARCH=$(echo ${TARGETPLATFORM:-linux/amd64} | sed 's/\//-/g') && \
    wget -q -O- https://github.com/golang-migrate/migrate/releases/download/v4.19.0/migrate.$MIGRATE_TARGET_ARCH.tar.gz | tar xvz && \
    mv migrate /usr/bin/migrate

COPY --from=builder --chown=nextjs:nodejs /app/web/next.config.mjs .
COPY --from=builder --chown=nextjs:nodejs /app/web/package.json .

# Copy Next.js standalone output
COPY --from=builder --chown=nextjs:nodejs /app/web/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/web/.next/static ./web/.next/static
COPY --from=builder --chown=nextjs:nodejs /app/web/public ./web/public

# Copy Prisma schema and ClickHouse migrations
COPY --from=builder --chown=nextjs:nodejs /app/packages/shared/prisma ./packages/shared/prisma
COPY --from=builder --chown=nextjs:nodejs /app/packages/shared/clickhouse ./packages/shared/clickhouse

# Copy entrypoint and scripts
COPY --chown=nextjs:nodejs ./web/entrypoint.sh ./web/entrypoint.sh
COPY --chown=nextjs:nodejs ./packages/shared/scripts/cleanup.sql ./packages/shared/scripts/cleanup.sql
RUN chmod +x ./web/entrypoint.sh

USER nextjs

ENV PORT=3000

ENTRYPOINT ["dumb-init", "--", "./web/entrypoint.sh"]

# Start with dd-trace if Cloud deployment
CMD if [ -n "$NEXT_PUBLIC_LANGFUSE_CLOUD_REGION" ]; then \
      node --import dd-trace/initialize.mjs ./web/server.js --keepAliveTimeout 110000; \
    else \
      node ./web/server.js --keepAliveTimeout 110000; \
    fi
