#!/bin/sh

# Run cleanup script before running migrations
# Check if DATABASE_URL is not set
if [ -z "$DATABASE_URL" ]; then
    if [ -n "$DATABASE_HOST" ] && [ -n "$DATABASE_USERNAME" ] && [ -n "$DATABASE_PASSWORD" ]  && [ -n "$DATABASE_NAME" ]; then
        DATABASE_URL="postgresql://${DATABASE_USERNAME}:${DATABASE_PASSWORD}@${DATABASE_HOST}/${DATABASE_NAME}"
        export DATABASE_URL
    else
        echo "Error: Required database environment variables are not set. Provide a postgres url for DATABASE_URL."
        exit 1
    fi
    if [ -n "$DATABASE_ARGS" ]; then
        DATABASE_URL="${DATABASE_URL}?$DATABASE_ARGS"
        export DATABASE_URL
    fi
fi

if [ -z "$CLICKHOUSE_URL" ]; then
    echo "Warning: CLICKHOUSE_URL is not configured. ClickHouse features will be disabled."
    export LANGFUSE_AUTO_CLICKHOUSE_MIGRATION_DISABLED="true"
fi

if [ -z "$DIRECT_URL" ]; then
    export DIRECT_URL="${DATABASE_URL}"
fi

# Prisma 7+: --url flag removed; pass URL via env
export PRISMA_DATABASE_URL="$DIRECT_URL"

if [ "$LANGFUSE_AUTO_POSTGRES_MIGRATION_DISABLED" != "true" ]; then
    # Prisma 7+: --url flag is removed, datasource url read from PRISMA_DATABASE_URL env
    prisma db execute --file "./packages/shared/scripts/cleanup.sql"

    export DATABASE_URL="$DIRECT_URL"
    prisma migrate deploy --schema=./packages/shared/prisma/schema.prisma
fi
status=$?

if [ $status -ne 0 ]; then
    echo "Applying database migrations failed. This is mostly caused by the database being unavailable."
    echo "Exiting..."
    exit $status
fi

if [ "$LANGFUSE_AUTO_CLICKHOUSE_MIGRATION_DISABLED" != "true" ]; then
    cd ./packages/shared
    sh ./clickhouse/scripts/up.sh
    status=$?
    cd ../../
fi

if [ $status -ne 0 ]; then
    echo "Applying clickhouse migrations failed. This is mostly caused by the database being unavailable."
    echo "Exiting..."
    exit $status
fi

exec "$@"
