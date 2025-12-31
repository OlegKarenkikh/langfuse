# ============================================
# Stage 1: Alpine Base with Security Updates
# ============================================
FROM --platform=${TARGETPLATFORM:-linux/amd64} node:24-alpine AS alpine

# Security: Update all Alpine packages to latest versions
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
    corepack prepare pnpm@9.5.0 --activate

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

WORKDIR /app

# Copy pruned lockfiles and package.json files
COPY --from=pruner /app/out/pnpm-lock.yaml ./pnpm-lock.yaml
COPY --from=pruner /app/out/pnpm-workspace.yaml ./pnpm-workspace.yaml
COPY --from=pruner /app/out/json/ .

# Disable preinstall script to avoid running ensure-kysely.sh which requires scripts/ folder
RUN sed -i 's/"preinstall": ".*"/"preinstall": "true"/' package.json

# Install dependencies (no-frozen-lockfile due to kysely modifications)
RUN pnpm install --no-frozen-lockfile

# Build-time environment variables
ARG NEXT_PUBLIC_LANGFUSE_CLOUD_REGION
ARG NEXT_PUBLIC_DEMO_ORG_ID
ARG NEXT_PUBLIC_DEMO_PROJECT_ID
ARG NEXT_PUBLIC_POSTHOG_KEY
ARG NEXT_PUBLIC_POSTHOG_HOST

# Copy full source code
COPY --from=pruner /app/out/full/ .

# Dummy environment variables for build
ENV DATABASE_URL="postgresql://postgres:postgres@localhost:5432/postgres"

# Generate Prisma Client (must be done before TypeScript compilation)
RUN npx prisma generate --schema=packages/shared/prisma/schema.prisma

# Build all dependencies and worker
RUN turbo run build --filter=worker...

# Verify worker build output
RUN ls -la worker/dist/index.js || \
    (echo "❌ Worker build failed: dist/index.js not found" && exit 1)

# Security audit (moderate level - ignore low severity)
RUN pnpm audit --audit-level=moderate --production || \
    echo "⚠️ Security vulnerabilities found, review logs"

# ============================================
# Stage 6: Production Runtime
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

# Copy built application
COPY --from=builder --chown=expressjs:expressjs /app .

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
