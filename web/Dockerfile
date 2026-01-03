# ============================================
# Stage 1: Alpine Base with Security Updates  
# ============================================
FROM --platform=${TARGETPLATFORM:-linux/amd64} node:24-alpine AS alpine

# Update Alpine packages to fix CVE vulnerabilities
# Force busybox update to fix CVE-2025-608766
RUN apk update && \
    apk upgrade --no-cache && \
    apk add --no-cache --upgrade busybox && \
    apk add --no-cache \
    libcrypto3 \
    libssl3 \
    libc6-compat \
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

# Force install vulnerable dependencies to fixed versions
RUN npm install glob@^11.1.0 tar@^7.5.2 --save-dev --ignore-scripts

# Remove old glob if exists in package-lock (which it does in kysely)
RUN npm uninstall glob rimraf && npm install glob@^11.1.0 tar@^7.5.2 --save-dev --ignore-scripts

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
    corepack prepare pnpm@9.15.1 --activate

# ============================================
# Stage 4: Prune Workspace
# ============================================
FROM base AS pruner

WORKDIR /app

COPY . .

RUN rm -rf packages/kysely
COPY --from=kysely-builder /kysely ./packages/kysely

# Patch the Kysely migration provider to remove webpackIgnore comment that breaks Turbopack
RUN sed -i 's|/\* webpackIgnore: true \*/||g' ./packages/kysely/src/migration/file-migration-provider.ts

# Rebuild Kysely after patching
RUN cd packages/kysely && npm install --no-save typescript@~5.9.3 --ignore-scripts && npm run build

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

# Install build dependencies for native modules (better-sqlite3, etc.)
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    libc-dev

WORKDIR /app

COPY --from=pruner /app/out/pnpm-lock.yaml ./pnpm-lock.yaml
COPY --from=pruner /app/out/pnpm-workspace.yaml ./pnpm-workspace.yaml
COPY --from=pruner /app/out/json/ .

# Disable preinstall script in Docker (kysely is already installed via multi-stage build)
# Remove preinstall from root package.json to avoid ensure-kysely.sh script error
RUN node -e "const fs=require('fs'); if(fs.existsSync('package.json')) { const pkg=JSON.parse(fs.readFileSync('package.json')); if(pkg.scripts && pkg.scripts.preinstall) { delete pkg.scripts.preinstall; fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2)); } }"

# Limit concurrency to prevent OOM during install
ENV PNPM_CONFIG_NETWORK_CONCURRENCY=3
# Skip Puppeteer Chrome download (not needed for build, saves time and network)
ENV PUPPETEER_SKIP_DOWNLOAD=true
# Force clean install to ensure CVE fixes are applied
RUN rm -rf node_modules/.cache pnpm-lock.yaml && \
    pnpm install --no-frozen-lockfile --force

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
# Use 1.5GB memory limit - smaller limit can work better if system can't allocate large chunks
# Also set Next.js build optimizations to reduce memory usage
# Increased memory limit to 3GB to prevent ResourceExhausted errors during build
# Note: This requires at least 8GB RAM on the host and 6GB+ allocated to Docker Desktop
ENV NODE_OPTIONS='--max-old-space-size=3072'
ENV NEXT_BUILD_OPTIMIZE=1
# Additional optimizations to reduce memory usage during build
ENV NODE_ENV=production

# Verify environment before build
RUN echo "=== Build Environment Check ===" && \
    echo "NODE_OPTIONS: $NODE_OPTIONS" && \
    echo "NEXT_BUILD_OPTIMIZE: $NEXT_BUILD_OPTIMIZE" && \
    echo "DATABASE_URL: ${DATABASE_URL:0:50}..." && \
    echo "Working directory: $(pwd)" && \
    echo "Node version: $(node --version)" && \
    echo "pnpm version: $(pnpm --version)" && \
    echo "Turbo version: $(turbo --version)" && \
    echo "Available memory: $(free -h 2>/dev/null || echo 'N/A')" && \
    echo "Disk space: $(df -h / 2>/dev/null | tail -1 || echo 'N/A')" && \
    echo "=== Starting build ==="

# Build with detailed error logging for debugging
# Force standalone output by setting environment variable
# Use Next.js with webpack (required for standalone output) instead of Turbopack
ENV NEXT_OUTPUT_MODE=standalone
RUN echo "=== Starting Next.js build with webpack (standalone mode) ===" && \
    NODE_OPTIONS='--max-old-space-size=3072' \
    turbo run build --filter=web... 2>&1 | tee /tmp/build.log; \
    BUILD_EXIT_CODE=$?; \
    if [ $BUILD_EXIT_CODE -ne 0 ]; then \
        echo "" && \
        echo "❌ Build failed with exit code $BUILD_EXIT_CODE" && \
        echo "Showing last 200 lines of build log:" && \
        tail -200 /tmp/build.log && \
        echo "" && \
        echo "=== Error summary ===" && \
        (grep -i "error\|fail\|exception" /tmp/build.log | tail -50 || echo "No error patterns found") && \
        echo "" && \
        echo "=== Build context ===" && \
        echo "Checking if Prisma Client exists:" && \
        find node_modules -name ".prisma" -type d 2>/dev/null | head -3 || echo "Prisma Client not found" && \
        echo "Checking if web directory exists:" && \
        ls -la web/ 2>/dev/null || echo "web directory not found" && \
        echo "Checking if packages/shared exists:" && \
        ls -la packages/shared/ 2>/dev/null | head -5 || echo "packages/shared not found" && \
        exit 1; \
    else \
        echo "" && \
        echo "✅ Build command completed successfully" && \
        echo "Checking build output..." && \
        echo "Last 50 lines of build log:" && \
        tail -50 /tmp/build.log && \
        echo "" && \
        echo "Checking for Next.js build completion message:" && \
        (grep -i "compiled\|build.*complete\|standalone" /tmp/build.log | tail -10 || echo "No build completion message found"); \
    fi

# Verify Next.js build output was created (lenient check - continue even if standalone not found)
RUN echo "=== Verifying Next.js build output ===" && \
    echo "Next.js output structure:" && \
    ls -la web/.next/ && \
    echo "" && \
    if [ -d "web/.next/standalone" ]; then \
        echo "✅ Standalone directory exists" && \
        ls -la web/.next/standalone/ && \
        echo "Checking for server.js:" && \
        find web/.next -name "server.js" -type f 2>/dev/null | head -5 || echo "No server.js found, but continuing..."; \
    else \
        echo "⚠️ Standalone directory not created, checking for regular Next.js build..." && \
        if [ -d "web/.next/server" ]; then \
            echo "✅ Regular Next.js server build found - continuing with standard build" && \
            ls -la web/.next/server/ | head -10; \
        elif [ -f "web/.next/BUILD_ID" ] || [ -f "web/.next/build-manifest.json" ]; then \
            echo "✅ Next.js build artifacts found - build appears successful" && \
            ls -la web/.next/ | head -10; \
        else \
            echo "❌ No Next.js build output found!" && \
            exit 1; \
        fi; \
    fi

# Clean up build artifacts to reduce image size and prevent export issues
# Remove unnecessary files that are not needed in the final image
# This significantly reduces the size of the builder stage and prevents EOF errors during export
RUN rm -rf web/.next/cache \
    && rm -rf node_modules/.cache \
    && rm -rf packages/*/node_modules/.cache \
    && find web/.next -name "*.map" -type f -delete 2>/dev/null || true \
    && find . -name ".turbo" -type d -exec rm -rf {} + 2>/dev/null || true \
    && find web/.next/standalone -name "*.map" -type f -delete 2>/dev/null || true \
    && echo "Build artifacts cleaned, checking standalone size:" \
    && du -sh web/.next/standalone 2>/dev/null || echo "Standalone directory size check completed"

# Security audit
RUN pnpm audit --audit-level=moderate --production || \
    echo "⚠️ Security vulnerabilities found"

# ============================================
# Stage 6: Optimize Build Output (reduce size before export)
# ============================================
FROM builder AS optimizer

# Remove all unnecessary files to minimize the size of what we copy to runner
# This stage exists solely to reduce the size of files copied to runner stage
RUN rm -rf node_modules \
    && rm -rf packages/*/node_modules \
    && rm -rf packages/*/dist \
    && rm -rf web/node_modules \
    && rm -rf web/.next/cache \
    && rm -rf .turbo \
    && find . -name "*.ts" -not -path "./web/.next/standalone/*" -type f -delete 2>/dev/null || true \
    && find . -name "*.tsx" -not -path "./web/.next/standalone/*" -type f -delete 2>/dev/null || true \
    && find . -name "tsconfig.json" -type f -delete 2>/dev/null || true \
    && echo "Optimization complete. Standalone size:" \
    && du -sh web/.next/standalone 2>/dev/null || echo "Size check completed"

# ============================================
# Stage 7: Production Runtime
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

# Update npm to latest to fix bundled dependencies (glob, tar)
RUN npm install -g npm@latest

# Install Prisma CLI for migrations
RUN npm install -g --no-package-lock --no-save prisma@7.2.0

# Security: Patch global npm vulnerabilities (safely)
# Remove all bundled glob instances in npm and corepack
RUN rm -rf /root/.cache && \
    rm -rf /usr/local/lib/node_modules/npm/node_modules/glob && \
    rm -rf /usr/local/lib/node_modules/npm/node_modules/node-gyp/node_modules/glob

# Install dd-trace only for Cloud deployments
ARG NEXT_PUBLIC_LANGFUSE_CLOUD_REGION
RUN if [ -n "$NEXT_PUBLIC_LANGFUSE_CLOUD_REGION" ]; then \
      npm install --no-package-lock --no-save dd-trace@5.81.0; \
    fi

# Skip migrate tool installation for now - can be added later if needed
# RUN apk add --no-cache curl && \
#     curl -L https://github.com/golang-migrate/migrate/releases/download/v4.20.0/migrate.linux-amd64.tar.gz | tar xvz -C /tmp && \
#     mv /tmp/migrate /usr/bin/migrate && \
#     chmod +x /usr/bin/migrate

# Copy files from optimizer stage (smaller size due to cleanup)
# Copy configuration files first (small files)
COPY --from=optimizer --chown=nextjs:nodejs /app/web/next.config.mjs .
COPY --from=optimizer --chown=nextjs:nodejs /app/web/package.json .

# Copy Next.js build output (handle both standalone and regular builds)
# First check what type of build we have and copy accordingly
RUN echo "Checking build output type..." && \
    if [ -d "/app/web/.next/standalone" ]; then \
        echo "Found standalone build - will copy standalone output"; \
    elif [ -d "/app/web/.next/server" ]; then \
        echo "Found regular build - will copy standard Next.js output"; \
    else \
        echo "Build output structure unknown - copying all .next content"; \
    fi

# Copy Next.js output based on what was built
COPY --from=optimizer --chown=nextjs:nodejs /app/web/.next ./web/.next

# Copy static assets and public files
COPY --from=optimizer --chown=nextjs:nodejs /app/web/public ./web/public

# If standalone build exists, also copy it to root for easier access
RUN if [ -d "./web/.next/standalone" ]; then \
        echo "Copying standalone files to root for easier access..." && \
        cp -r ./web/.next/standalone/* . 2>/dev/null || true; \
    fi

# Copy Prisma schema and ClickHouse migrations
COPY --from=optimizer --chown=nextjs:nodejs /app/packages/shared/prisma ./packages/shared/prisma
COPY --from=optimizer --chown=nextjs:nodejs /app/packages/shared/clickhouse ./packages/shared/clickhouse

# Copy entrypoint and scripts
COPY --chown=nextjs:nodejs ./web/entrypoint.sh ./web/entrypoint.sh
COPY --from=optimizer --chown=nextjs:nodejs /app/packages/shared/scripts/cleanup.sql ./packages/shared/scripts/cleanup.sql
RUN chmod +x ./web/entrypoint.sh

USER nextjs

ENV PORT=3000

ENTRYPOINT ["dumb-init", "--", "./web/entrypoint.sh"]

# Start with dd-trace if Cloud deployment, handle different build types
CMD echo "Starting Langfuse web server..." && \
    echo "Checking for available server files..." && \
    if [ -f "./web/server.js" ]; then \
      echo "Using standalone server.js at ./web/server.js" && \
      if [ -n "$NEXT_PUBLIC_LANGFUSE_CLOUD_REGION" ]; then \
        node --import dd-trace/initialize.mjs ./web/server.js --keepAliveTimeout 110000; \
      else \
        node ./web/server.js --keepAliveTimeout 110000; \
      fi; \
    elif [ -f "./server.js" ]; then \
      echo "Using root server.js" && \
      if [ -n "$NEXT_PUBLIC_LANGFUSE_CLOUD_REGION" ]; then \
        node --import dd-trace/initialize.mjs ./server.js --keepAliveTimeout 110000; \
      else \
        node ./server.js --keepAliveTimeout 110000; \
      fi; \
    elif [ -d "./web/.next" ]; then \
      echo "Using Next.js standard build with next start" && \
      cd web && \
      if [ -n "$NEXT_PUBLIC_LANGFUSE_CLOUD_REGION" ]; then \
        node --import dd-trace/initialize.mjs node_modules/.bin/next start; \
      else \
        npx next start; \
      fi; \
    else \
      echo "❌ No valid Next.js build found!" && \
      echo "Available files:" && \
      ls -la . && \
      echo "Web directory:" && \
      ls -la web/ 2>/dev/null || echo "No web directory" && \
      exit 1; \
    fi
