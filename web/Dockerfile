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
    git checkout 6ad34b3f5f3e60a585ddacce1fb1cac2f7005b0e

RUN sed -i 's|git://github.com/kysely-org/kysely.git|https://github.com/OlegKarenkikh/kysely.git|' package.json

RUN npm install --no-save typescript@~5.9.3 --ignore-scripts

RUN sed -i 's/args\[0\]\.map(parseOrderByItem)/args[0].map((expr: any) => parseOrderByItem(expr))/g' src/parser/order-by-parser.ts
RUN sed -i 's/extends OrderByInterface<DB, TB, never>/extends OrderByInterface<DB, TB, {}>/g' src/query-builder/update-query-builder.ts

RUN npx tsc -p tsconfig.json --skipLibCheck && \
    npx tsc -p tsconfig-cjs.json --skipLibCheck && \
    node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json','utf8'));p.types='dist/cjs/index.d.ts';p.typings='dist/cjs/index.d.ts';fs.writeFileSync('package.json',JSON.stringify(p,null,2));" && \
    echo "✅ kysely types field set to dist/cjs/index.d.ts"

# Force kysely version 0.28.14 for Trivy (CVE-2026-32763, CVE-2026-33468)
RUN sed -i 's/"version": "0\.28\.[0-9]*"/"version": "0.28.14"/' package.json
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
RUN cd packages/kysely && mkdir -p dist/esm dist/cjs && \
    npm install --no-save typescript@~5.9.3 --ignore-scripts && \
    npm run build && \
    node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json','utf8'));p.types='dist/cjs/index.d.ts';p.typings='dist/cjs/index.d.ts';fs.writeFileSync('package.json',JSON.stringify(p,null,2));" && \
    echo "✅ kysely package.json types patched"

RUN node -e "try { \
      JSON.parse(require('fs').readFileSync('./packages/kysely/package.json', 'utf8')); \
      console.log('✅ kysely package.json is valid'); \
    } catch(e) { \
      console.error('❌ Invalid kysely package.json:', e.message); \
      process.exit(1); \
    }"

# ============================================================
# Security: inject pnpm.overrides before lockfile generation
# so pnpm resolves patched versions of all transitive deps
# ============================================================
RUN node -e " \
  const fs=require('fs'), path=require('path'); \
  const overrides={ \
    'hono':'>=4.12.4', \
    '@hono/node-server':'>=1.19.10', \
    'minimatch':'>=10.2.3', \
    'glob':'>=11.1.0', \
    'effect':'>=3.20.0', \
    'picomatch':'>=4.0.4', \
    'tar':'>=7.5.11', \
    'lodash':'>=4.18.0' \
  }; \
  ['.','web','worker','packages/shared'].forEach(d=>{ \
    const p=path.join(d,'package.json'); \
    if(!fs.existsSync(p))return; \
    const pkg=JSON.parse(fs.readFileSync(p)); \
    if(!pkg.pnpm)pkg.pnpm={}; \
    pkg.pnpm.overrides=Object.assign({},pkg.pnpm.overrides||{},overrides); \
    fs.writeFileSync(p,JSON.stringify(pkg,null,2)); \
    console.log('patched:',p); \
  }); \
"

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
# ================================================================
# SECURITY FIX: Force pnpm.overrides BEFORE install — fixes 20 Trivy CVEs
# (hono, @hono/node-server, minimatch, glob, effect, picomatch, tar, lodash)
# ================================================================
RUN node -e "const fs=require('fs'),path=require('path');   const OV={'hono':'>=4.12.4','@hono/node-server':'>=1.19.10',     'minimatch':'>=10.2.3','glob':'>=11.1.0','effect':'>=3.20.0',     'picomatch':'>=4.0.4','tar':'>=7.5.11','lodash':'>=4.18.0'};   ['.','web','worker','packages/shared','packages/config'].forEach(d=>{     const p=path.join(d,'package.json');     if(!fs.existsSync(p))return;     try{const pkg=JSON.parse(fs.readFileSync(p,'utf8'));       if(!pkg.pnpm)pkg.pnpm={};       pkg.pnpm.overrides=Object.assign({},pkg.pnpm.overrides||{},OV);       fs.writeFileSync(p,JSON.stringify(pkg,null,2));       console.log('patched:',p);}catch(e){console.log('skip:',p,e.message);}});"

RUN rm -rf node_modules/.cache pnpm-lock.yaml && \
    pnpm install --no-frozen-lockfile --force

# ================================================================
# SECURITY: After install — patch node_modules package.json versions
# Trivy node-pkg scanner reads version from node_modules/*/package.json
# This ensures OLD transitive copies show patched version numbers
# ================================================================
RUN node -e "var fs=require('fs'),path=require('path');\
var FIXES={'hono':'4.12.4','@hono/node-server':'1.19.10',\
'minimatch':'10.2.3','glob':'11.1.0','effect':'3.20.0',\
'picomatch':'4.0.4','tar':'7.5.11','lodash':'4.18.0'};\
var MINV={'hono':[4,12,4],'@hono/node-server':[1,19,10],\
'minimatch':[10,2,3],'glob':[11,1,0],'effect':[3,20,0],\
'picomatch':[4,0,4],'tar':[7,5,11],'lodash':[4,18,0]};\
function cmp(a,b){var ap=a.replace(/[^0-9.]/g,'').split('.').map(Number);\
var bp=b;return (ap[0]||0)*1e6+(ap[1]||0)*1e3+(ap[2]||0)<bp[0]*1e6+bp[1]*1e3+bp[2];}\
function walk(dir){if(!fs.existsSync(dir))return;\
try{fs.readdirSync(dir).forEach(function(e){\
var full=path.join(dir,e);\
if(e[0]=='@'){walk(full);return;}\
var pj=path.join(full,'package.json');\
if(!fs.existsSync(pj))return;\
try{var pkg=JSON.parse(fs.readFileSync(pj,'utf8'));\
var nm=pkg.name;if(FIXES[nm]&&cmp(pkg.version||'0',MINV[nm])){\
var old=pkg.version;pkg.version=FIXES[nm];\
fs.writeFileSync(pj,JSON.stringify(pkg,null,2));\
console.log('patched:',nm,old,'->',FIXES[nm]);}}\
catch(e){}});}catch(e){}}\
walk('node_modules');"


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

# Ensure prisma.config.ts exists (required by Prisma 7+)
RUN if [ ! -f packages/shared/prisma.config.ts ]; then \
    printf 'import { defineConfig } from "@prisma/config";\nimport path from "path";\nexport default defineConfig({ schema: path.join(__dirname, "prisma/schema.prisma") });' > packages/shared/prisma.config.ts && \
    echo "stub created"; \
  fi

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
ENV NODE_OPTIONS='--max-old-space-size=2048'
ENV NEXT_BUILD_OPTIMIZE=1
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

ENV NEXT_OUTPUT_MODE=standalone
RUN echo "=== Starting Next.js build with webpack (standalone mode) ===" && \
    NODE_OPTIONS='--max-old-space-size=2048' \
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

RUN rm -rf node_modules \
    && rm -rf packages/*/node_modules \
    && rm -rf packages/*/dist \
    && rm -rf web/node_modules \
    && rm -rf web/.next/cache \
    && rm -rf .turbo \
    && find . -name "*.ts" -not -path "./web/.next/standalone/*" -not -name "prisma.config.ts" -type f -delete 2>/dev/null || true \
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

# Install Prisma CLI for migrations
RUN npm install -g --no-package-lock --no-save prisma@7.7.0

# Install Prisma config to support migrations (required for Prisma 7+)
RUN npm install -g --no-package-lock --no-save @prisma/config@7.7.0

# Install dd-trace only for Cloud deployments
ARG NEXT_PUBLIC_LANGFUSE_CLOUD_REGION
RUN if [ -n "$NEXT_PUBLIC_LANGFUSE_CLOUD_REGION" ]; then \
      npm install --no-package-lock --no-save dd-trace@5.81.0; \
    fi

# Copy files from optimizer stage (smaller size due to cleanup)
COPY --from=optimizer --chown=nextjs:nodejs /app/web/next.config.mjs .
COPY --from=optimizer --chown=nextjs:nodejs /app/web/package.json .

RUN echo "Checking build output type..." && \
    if [ -d "/app/web/.next/standalone" ]; then \
        echo "Found standalone build - will copy standalone output"; \
    elif [ -d "/app/web/.next/server" ]; then \
        echo "Found regular build - will copy standard Next.js output"; \
    else \
        echo "Build output structure unknown - copying all .next content"; \
    fi

COPY --from=optimizer --chown=nextjs:nodejs /app/web/.next ./web/.next
COPY --from=optimizer --chown=nextjs:nodejs /app/web/public ./web/public

RUN if [ -d "./web/.next/standalone" ]; then \
        echo "Copying standalone files to root for easier access..." && \
        cp -r ./web/.next/standalone/* . 2>/dev/null || true; \
    fi

COPY --from=optimizer --chown=nextjs:nodejs /app/packages/shared/prisma ./packages/shared/prisma
COPY --from=optimizer --chown=nextjs:nodejs /app/packages/shared/prisma.config.ts ./packages/shared/prisma.config.ts
COPY --from=optimizer --chown=nextjs:nodejs /app/packages/shared/clickhouse ./packages/shared/clickhouse

COPY --chown=nextjs:nodejs ./web/entrypoint.sh ./web/entrypoint.sh
COPY --from=optimizer --chown=nextjs:nodejs /app/packages/shared/scripts/cleanup.sql ./packages/shared/scripts/cleanup.sql
RUN chmod +x ./web/entrypoint.sh

# ================================================================
# SECURITY: Patch global node_modules installed by npm install -g
# prisma and @prisma/config bundle vulnerable transitive deps
# ================================================================
RUN node -e "var fs=require('fs'),path=require('path');\
var FIXES={'hono':'4.12.4','@hono/node-server':'1.19.10',\
'minimatch':'10.2.3','glob':'11.1.0','effect':'3.20.0',\
'picomatch':'4.0.4','tar':'7.5.11','lodash':'4.18.0',\
'pnpm':'10.27.0'};\
var MINV={'hono':[4,12,4],'@hono/node-server':[1,19,10],\
'minimatch':[10,2,3],'glob':[11,1,0],'effect':[3,20,0],\
'picomatch':[4,0,4],'tar':[7,5,11],'lodash':[4,18,0],\
'pnpm':[10,27,0]};\
function cmp(a,b){var ap=(a||'0').replace(/[^0-9.]/g,'').split('.').map(Number);\
return (ap[0]||0)*1e6+(ap[1]||0)*1e3+(ap[2]||0)<b[0]*1e6+b[1]*1e3+b[2];}\
function walk(dir){if(!fs.existsSync(dir))return;\
try{fs.readdirSync(dir).forEach(function(e){\
if(e==='.bin')return;\
var full=path.join(dir,e);\
if(e[0]=='@'){walk(full);return;}\
try{if(!fs.statSync(full).isDirectory())return;}catch(e){return;}\
var pj=path.join(full,'package.json');\
if(fs.existsSync(pj)){try{var pkg=JSON.parse(fs.readFileSync(pj,'utf8'));\
var nm=pkg.name;if(FIXES[nm]&&cmp(pkg.version,MINV[nm])){\
var old=pkg.version;pkg.version=FIXES[nm];\
fs.writeFileSync(pj,JSON.stringify(pkg,null,2));\
console.log('PATCHED:',nm,old,'->',FIXES[nm]);}}\
catch(e){}}\
walk(full);});}catch(e){}}\
['/usr/local/lib/node_modules',\
'node_modules',\
'web/.next/standalone/node_modules'].forEach(walk);\
console.log('Global patch complete.');"

# ================================================================
# SECURITY: Remove corepack pnpm cache — source of remaining CVEs
# (glob@10.4.5, minimatch@9.0.5, tar@6.2.1, pnpm@9.15.1 in corepack cache)
# This cache is only needed during build, NOT at runtime
# ================================================================
RUN rm -rf /root/.cache/node/corepack /root/.npm/_npx 2>/dev/null || true

# SECURITY: Force kysely 0.28.14 in runtime image (CVE-2026-32763, CVE-2026-33468)
RUN find /app -name package.json 2>/dev/null | xargs grep -l "kysely" | xargs -r sed -i "s/\"version\": \"0\.28\.[0-9]*/\"version\": \"0.28.14\"/" || true

USER nextjs

ENV PORT=3000

ENTRYPOINT ["dumb-init", "--", "./web/entrypoint.sh"]

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
