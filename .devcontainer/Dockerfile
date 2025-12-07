# Dev container Dockerfile
FROM mcr.microsoft.com/vscode/devcontainers/typescript-node:20-bookworm

# Install Go toolchain to compile golang-migrate with a patched stdlib (avoids CVE-2025-61723/61724/61725/61727/61729/47906/47912/58183/58185/58186/58187/58188/58189)
ARG GO_VERSION=1.24.11
RUN curl -fsSL https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz -o /tmp/golang.tar.gz && \
    tar -C /usr/local -xzf /tmp/golang.tar.gz && \
    rm /tmp/golang.tar.gz && \
    /usr/local/go/bin/go version
ENV PATH="/usr/local/go/bin:${PATH}"

# Install golang-migrate for database migrations using the local Go toolchain
RUN /usr/local/go/bin/go install -tags 'postgres clickhouse' github.com/golang-migrate/migrate/v4/cmd/migrate@v4.19.0

# Install pnpm globally
RUN npm install -g pnpm@9.5.0

# Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code
