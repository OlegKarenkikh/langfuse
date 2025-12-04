FROM almalinux:8-minimal AS pruner
RUN microdnf install -y curl ca-certificates tar gzip \
    && curl -fsSL https://rpm.nodesource.com/setup_24.x | bash - \
    && microdnf install -y nodejs \
    && microdnf clean all
RUN npm install turbo@^2.6.1 --global
WORKDIR /app
COPY . .
RUN turbo prune --scope=worker --docker

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

# pass public variables in build step
ARG NEXT_PUBLIC_LANGFUSE_CLOUD_REGION
ARG NEXT_PUBLIC_DEMO_ORG_ID
ARG NEXT_PUBLIC_DEMO_PROJECT_ID
ARG NEXT_PUBLIC_POSTHOG_KEY
ARG NEXT_PUBLIC_POSTHOG_HOST

# Copy source code of isolated subworkspace
COPY --from=pruner /app/out/full/ .

RUN pnpm turbo run build --filter=worker...

FROM almalinux:8-minimal AS runner

ARG TARGETPLATFORM
ARG BUILDPLATFORM

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

WORKDIR /app

ARG NEXT_PUBLIC_BUILD_ID
ENV BUILD_ID=$NEXT_PUBLIC_BUILD_ID

ENV NODE_ENV production
ENV DOCKER_BUILD 0

# Don't run production as root
ARG UID=1001
ARG GID=1001
RUN groupadd --system --gid ${GID} expressjs
RUN useradd --system --uid ${UID} --gid expressjs expressjs
USER expressjs

COPY --from=builder --chown=expressjs:expressjs /app .
COPY --chown=expressjs:expressjs ./worker/entrypoint.sh ./worker/entrypoint.sh
RUN chmod +x ./worker/entrypoint.sh

EXPOSE 3030
ENV PORT=3030

# Docker ENTRYPOINT (dumb-init) is covered by semantic versioning, not the entrypoint.sh itself
# Reasoning: ENTRYPOINT is overridden by some self-hosted deployments, thus changing this is breaking
ENTRYPOINT ["/usr/local/bin/dumb-init", "--", "./worker/entrypoint.sh"]

# startup command
CMD ["node", "worker/dist/index.js"]
