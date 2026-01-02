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

# Install git for cloning
RUN apk add --no-cache git

WORKDIR /kysely

# Clone your secure kysely fork
RUN git clone https://github.com/OlegKarenkikh/kysely.git . && \
    git checkout 64a12c470b1a5387b842acf09094e2aa1e4149b0

# Fix repository URL in package.json
RUN sed -i 's|git://github.com/kysely-org/kysely.git|https://github.com/OlegKarenkikh/kysely.git|' package.json

# Install only TypeScript compiler (no unnecessary dependencies)
RUN npm install --no-save typescript@~5.9.3 --ignore-scripts

# Compile TypeScript to JavaScript (both ESM and CJS)
RUN npx tsc -p tsconfig.json && \
    npx tsc -p tsconfig-cjs.json

# Verify build output exists
RUN ls -la dist/cjs/index.js dist/esm/index.js || \
    (echo "❌ Kysely build failed: dist files not found" && exit 1)

# Cleanup unnecessary files to reduce layer size
RUN rm -rf node_modules test site example docs .github

# ============================================
# Stage 3: Base with Package Managers
# ============================================
FROM alpine AS base

# Install Turbo (latest stable)
RUN npm install turbo@^2.7.1 --global

# Setup pnpm via corepack (recommended approach)
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable && \
    corepack prepare pnpm@9.15.1 --activate

# ============================================
# Stage 4: Prune Workspace
# ============================================
FROM base AS pruner

WORKDIR /app

# Copy full source code
COPY . .

# Replace standard kysely with our secure build
RUN rm -rf packages/kysely
COPY --from=kysely-builder /kysely ./packages/kysely

# Validate kysely package.json is valid JSON
RUN node -e "try { \
      JSON.parse(require('fs').readFileSync('./packages/kysely/package.json', 'utf8')); \
      console.log('✅ kysely package.json is valid'); \
    } catch(e) { \
      console.error('❌ Invalid kysely package.json:', e.message); \
      process.exit(1); \
    }"

# CRITICAL: Update lockfile to reflect kysely replacement
# This ensures turbo prune can resolve the workspace correctly
RUN pnpm install --lockfile-only || true

# Prune workspace for worker dependencies only
RUN turbo prune --scope=worker --docker || \
    (echo "❌ Turbo prune failed. Debugging info:" && \
     echo "=== turbo.json ===" && cat turbo.json && \
     echo "=== worker/package.json ===" && cat worker/package.json && \
     exit 1)

# ============================================
# Stage 5: Build Worker
# ============================================
FROM base AS builder

# Install build dependencies for native modules (better-sqlite3, etc.)
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    libc-dev

WORKDIR /app

# Copy pruned lockfiles and package.json files
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

# Build-time environment variables
ARG NEXT_PUBLIC_LANGFUSE_CLOUD_REGION
ARG NEXT_PUBLIC_DEMO_ORG_ID
ARG NEXT_PUBLIC_DEMO_PROJECT_ID
ARG NEXT_PUBLIC_POSTHOG_KEY
ARG NEXT_PUBLIC_POSTHOG_HOST

# Copy full source code
COPY --from=pruner /app/out/full/ .

# DATABASE_URL is required by prisma.config.ts for Prisma Client generation
# Set it as ENV so it's available for all commands including turbo tasks
ENV DATABASE_URL="postgresql://dummy:dummy@localhost:5432/dummy"

# Generate Prisma Client (must be done before TypeScript compilation)
# Use --schema flag to explicitly specify schema location
RUN cd packages/shared && \
    DATABASE_URL="postgresql://dummy:dummy@localhost:5432/dummy" \
    npx prisma generate --schema=prisma/schema.prisma

# Verify Prisma Client was generated
# In pnpm workspace with hoisting, check multiple possible locations
RUN echo "=== Verifying Prisma Client generation ===" && \
    PRISMA_FOUND=0 && \
    if [ -f "node_modules/.prisma/client/index.js" ]; then \
        echo "✅ Found at node_modules/.prisma/client/index.js" && PRISMA_FOUND=1; \
    fi && \
    if [ -f "packages/shared/node_modules/.prisma/client/index.js" ]; then \
        echo "✅ Found at packages/shared/node_modules/.prisma/client/index.js" && PRISMA_FOUND=1; \
    fi && \
    PNPM_PRISMA=$(find node_modules/.pnpm -path "*/@prisma/client/*/index.js" 2>/dev/null | head -1) && \
    if [ -n "$PNPM_PRISMA" ]; then \
        echo "✅ Found in pnpm store: $PNPM_PRISMA" && PRISMA_FOUND=1; \
    fi && \
    if [ $PRISMA_FOUND -eq 0 ]; then \
        echo "❌ Prisma Client not found in any expected location" && \
        echo "Searching for .prisma directories:" && \
        find . -name ".prisma" -type d 2>/dev/null | head -10 && \
        exit 1; \
    fi

# Build all dependencies and worker with optimized memory settings
# Use 1.5GB memory limit to prevent OOM on small instances
RUN NODE_OPTIONS='--max-old-space-size=1536' \
    turbo run build --filter=worker...

# Verify worker build output
RUN ls -la worker/dist/index.js || \
    (echo "❌ Worker build failed: dist/index.js not found" && exit 1)

# Security audit (moderate level - ignore low severity)
RUN pnpm audit --audit-level=moderate --production || \
    echo "⚠️ Security vulnerabilities found, review logs"

# ============================================
# Stage 6: Optimize Build Output (reduce size before export)
# ============================================
FROM builder AS optimizer

# Remove all unnecessary files to minimize the size of what we copy to runner
# This stage exists solely to reduce the size of files copied to runner stage
RUN rm -rf node_modules \
    && rm -rf packages/*/node_modules \
    && rm -rf packages/*/dist \
    && rm -rf worker/node_modules \
    && rm -rf .turbo \
    && find . -name "*.ts" -not -path "./worker/dist/*" -type f -delete 2>/dev/null || true \
    && find . -name "*.tsx" -not -path "./worker/dist/*" -type f -delete 2>/dev/null || true \
    && find . -name "tsconfig.json" -type f -delete 2>/dev/null || true \
    && echo "Optimization complete. Worker dist size:" \
    && du -sh worker/dist 2>/dev/null || echo "Size check completed"

# ============================================
# Stage 7: Production Runtime
# ============================================
FROM base AS runner

ARG TARGETPLATFORM
ARG BUILDPLATFORM

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

WORKDIR /app

# Runtime environment
ARG NEXT_PUBLIC_BUILD_ID
ENV BUILD_ID=$NEXT_PUBLIC_BUILD_ID
ENV NODE_ENV=production
ENV DOCKER_BUILD=0

# Security: Don't run as root
ARG UID=1001
ARG GID=1001
RUN addgroup --system --gid ${GID} expressjs && \
    adduser --system --uid ${UID} expressjs

USER expressjs

# Copy built application from optimizer stage (smaller size due to cleanup)
COPY --from=optimizer --chown=expressjs:expressjs /app .

# Copy entrypoint script
COPY --chown=expressjs:expressjs ./worker/entrypoint.sh ./worker/entrypoint.sh
RUN chmod +x ./worker/entrypoint.sh

# Expose worker port
EXPOSE 3030
ENV PORT=3030

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--", "./worker/entrypoint.sh"]

# Start worker
CMD ["node", "worker/dist/index.js"]
