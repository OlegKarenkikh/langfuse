FROM public.ecr.aws/docker/library/node:22-alpine AS kysely-builder
RUN apk update && apk add --no-cache git
WORKDIR /kysely
RUN git clone https://github.com/Olegkarenkikh/kysely.git . && \
    git checkout 64a12c470b1a5387b842acf09094e2aa1e4149b0 && \
    npm install --legacy-peer-deps && \
    npm run build

FROM public.ecr.aws/docker/library/node:22-alpine AS pruner
RUN apk update && apk add --no-cache libc6-compat tar gzip git
RUN npm install turbo@^2.6.1 --global
WORKDIR /app
COPY . .
COPY --from=kysely-builder /kysely ./packages/kysely

# FIX: Remove extra closing brace in kysely/site/package.json causing turbo prune failure
RUN sed -i '$d' packages/kysely/site/package.json

RUN turbo prune --scope=worker --docker

FROM public.ecr.aws/docker/library/node:22-alpine AS builder
RUN apk update && apk add --no-cache libc6-compat git tar gzip
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

RUN pnpm audit --audit-level=moderate

RUN pnpm turbo run build --filter=worker...

RUN pnpm prune --prod

FROM public.ecr.aws/docker/library/node:22-alpine AS runner

ARG TARGETPLATFORM
ARG BUILDPLATFORM

RUN apk update && apk upgrade && apk add --no-cache libc6-compat shadow curl dumb-init && npm install -g npm@latest

WORKDIR /app

ARG NEXT_PUBLIC_BUILD_ID
ENV BUILD_ID=$NEXT_PUBLIC_BUILD_ID

ENV NODE_ENV production
ENV DOCKER_BUILD 0

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
