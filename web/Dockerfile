FROM almalinux:8-minimal AS pruner
RUN microdnf install -y curl ca-certificates tar gzip \
    && curl -fsSL https://rpm.nodesource.com/setup_24.x | bash - \
    && microdnf install -y nodejs \
    && microdnf clean all
RUN npm install turbo@^2.6.1 --global
WORKDIR /app
COPY . .
# Verify that pnpm-workspace.yaml exists
# This ensures the build context is the repository root, not the web/ directory
RUN if [ ! -f "./pnpm-workspace.yaml" ]; then \
    echo "ERROR: pnpm-workspace.yaml not found."; \
    echo "Please run docker build from the repository root with: docker build -f ./web/Dockerfile -t <tag> ."; \
    exit 1; \
    fi
RUN turbo prune --scope=web --docker

FROM almalinux:8-minimal AS builder
RUN microdnf install -y curl ca-certificates tar gzip git \
    && curl -fsSL https://rpm.nodesource.com/setup_24.x | bash - \
    && microdnf install -y nodejs \
    && microdnf clean all
RUN npm install -g pnpm@9.15.0

WORKDIR /app

# First install the dependencies (as they change less often)
COPY --from=pruner /app/out/pnpm-lock.yaml ./pnpm-lock.yaml
COPY --from=pruner /app/out/pnpm-workspace.yaml ./pnpm-workspace.yaml
COPY --from=pruner /app/out/json/ .

RUN pnpm install --frozen-lockfile

ENV DOCKER_BUILD 1
ENV NEXT_MANUAL_SIG_HANDLE true

# pass public variables in build step
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

# Sentry already needs to be set on build time to upload sourcemaps
# This must not be set for OSS releases as we would share our Sentry secret.
ARG SENTRY_AUTH_TOKEN
ENV SENTRY_AUTH_TOKEN=$SENTRY_AUTH_TOKEN
ARG SENTRY_ORG
ENV SENTRY_ORG=$SENTRY_ORG
ARG SENTRY_PROJECT
ENV SENTRY_PROJECT=$SENTRY_PROJECT

# Accept build id as NEXT_PUBLIC_BUILD_ID
ARG NEXT_PUBLIC_BUILD_ID
ENV NEXT_PUBLIC_BUILD_ID=$NEXT_PUBLIC_BUILD_ID
ENV SENTRY_RELEASE=$NEXT_PUBLIC_BUILD_ID

# Copy source code of isolated subworkspace
COPY --from=pruner /app/out/full/ .

# remove middleware.ts if it exists - not needed in self-hosted environments
RUN rm -f ./web/src/middleware.ts

# Next.js collects completely anonymous telemetry data about general usage.
# Learn more here: https://nextjs.org/telemetry
# Uncomment the following line in case you want to disable telemetry during the build.
ENV NEXT_TELEMETRY_DISABLED 1
ENV NEXT_MANUAL_SIG_HANDLE true
# set the CI flag to true to get CI specific logs
ENV CI true

RUN NODE_OPTIONS='--max-old-space-size-percentage=75' pnpm turbo run build --filter=web...

# Production image, copy all the files and run next
FROM almalinux:8-minimal AS runner

ARG TARGETPLATFORM
ARG BUILDPLATFORM

WORKDIR /app

ARG NEXT_PUBLIC_BUILD_ID
ENV BUILD_ID=$NEXT_PUBLIC_BUILD_ID
ARG NEXT_PUBLIC_LANGFUSE_CLOUD_REGION
ENV NEXT_PUBLIC_LANGFUSE_CLOUD_REGION=$NEXT_PUBLIC_LANGFUSE_CLOUD_REGION

ENV NODE_ENV production
# Uncomment the following line in case you want to disable telemetry during runtime.
ENV NEXT_TELEMETRY_DISABLED 1
# Needed to re-enable validation of environment variables during runtime
ENV DOCKER_BUILD 0
# Set NEXT_MANUAL_SIG_HANDLE for runtime
ENV NEXT_MANUAL_SIG_HANDLE true

RUN microdnf install -y curl ca-certificates tar gzip shadow-utils \
    && curl -fsSL https://rpm.nodesource.com/setup_24.x | bash - \
    && microdnf install -y nodejs \
    && microdnf clean all

# Install dumb-init
ARG TARGETPLATFORM
RUN DUMB_INIT_ARCH=$(echo ${TARGETPLATFORM:-linux/amd64} | sed 's/linux\///') && \
    if [ "$DUMB_INIT_ARCH" = "amd64" ]; then \
      DUMB_INIT_URL="https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_x86_64"; \
    elif [ "$DUMB_INIT_ARCH" = "arm64" ]; then \
      DUMB_INIT_URL="https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_aarch64"; \
    else \
      echo "Unsupported architecture: $DUMB_INIT_ARCH"; exit 1; \
    fi && \
    curl -L -o /usr/local/bin/dumb-init "$DUMB_INIT_URL" && \
    chmod +x /usr/local/bin/dumb-init

# Don't run production as root
ARG UID=1001
ARG GID=1001
RUN groupadd --system --gid ${GID} nodejs
RUN useradd --system --uid ${UID} --gid nodejs nextjs

RUN npm install -g --no-package-lock --no-save prisma@6.17.1

# Install dd-trace only if NEXT_PUBLIC_LANGFUSE_CLOUD_REGION is configured
ARG NEXT_PUBLIC_LANGFUSE_CLOUD_REGION
RUN if [ -n "$NEXT_PUBLIC_LANGFUSE_CLOUD_REGION" ]; then \
    npm install --no-package-lock --no-save dd-trace@5.65.0; \
    fi

RUN MIGRATE_TARGET_ARCH=$(echo ${TARGETPLATFORM:-linux/amd64} | sed 's/\//-/g') && \
    curl -L https://github.com/golang-migrate/migrate/releases/download/v4.19.1/migrate.$MIGRATE_TARGET_ARCH.tar.gz | tar xvz && \
    mv migrate /usr/bin/migrate

COPY --from=builder --chown=nextjs:nodejs /app/web/next.config.mjs .
COPY --from=builder --chown=nextjs:nodejs /app/web/package.json .

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/web/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/web/.next/static ./web/.next/static
COPY --from=builder --chown=nextjs:nodejs /app/web/public ./web/public

COPY --from=builder --chown=nextjs:nodejs /app/packages/shared/prisma ./packages/shared/prisma
COPY --from=builder --chown=nextjs:nodejs /app/packages/shared/clickhouse ./packages/shared/clickhouse

COPY --chown=nextjs:nodejs ./web/entrypoint.sh ./web/entrypoint.sh
COPY --chown=nextjs:nodejs ./packages/shared/scripts/cleanup.sql ./packages/shared/scripts/cleanup.sql
RUN chmod +x ./web/entrypoint.sh

USER nextjs

# Default port to 3000
ENV PORT 3000

# Docker ENTRYPOINT (dumb-init) is covered by semantic versioning, not the entrypoint.sh itself
# Reasoning: ENTRYPOINT is overridden by some self-hosted deployments, thus changing this is breaking
ENTRYPOINT ["/usr/local/bin/dumb-init", "--", "./web/entrypoint.sh"]

# startup command - use dd-trace if NEXT_PUBLIC_LANGFUSE_CLOUD_REGION is configured
CMD if [ -n "$NEXT_PUBLIC_LANGFUSE_CLOUD_REGION" ]; then \
    node --import dd-trace/initialize.mjs ./web/server.js --keepAliveTimeout 110000; \
    else \
    node ./web/server.js --keepAliveTimeout 110000; \
    fi
