# Langfuse without ClickHouse

This document provides instructions for setting up and running Langfuse without a ClickHouse instance. This configuration is intended for users who do not require the advanced analytics and logging features provided by ClickHouse and prefer a more lightweight setup.

## Functional Limitations

When running Langfuse without ClickHouse, the following features will be unavailable:

- **Event Logging**: All event data, including traces, scores, and observations, will not be logged.
- **Analytics**: The analytics dashboard and related features will be disabled.
- **Project Dashboards**: Dashboards that rely on ClickHouse data will not be available.

This setup is suitable for development environments or for users who only need the core data persistence features provided by PostgreSQL.

## Setup Instructions

### 1. Prepare the Environment

First, copy the example environment file to `.env`:

```bash
cp .env.no-clickhouse.example .env
```

This file contains the necessary environment variables for the no-clickhouse setup, including dummy credentials to bypass validation checks.

### 2. Build and Run the Services

Next, build and run the services using the `docker-compose.no-clickhouse.yml` file:

```bash
docker-compose -f docker-compose.no-clickhouse.yml up --build -d
```

This command will build the `langfuse-web` and `langfuse-worker` images from the local Dockerfiles and start all the services in detached mode.

### 3. Verify the Setup

To verify that the services are running correctly, you can check the health endpoints:

**Web Service:**

```bash
curl -f http://localhost:3000/api/public/health
```

**Worker Service:**

```bash
curl -f http://localhost:3030/api/health
```

If both commands return a successful response, the setup is complete. You can now access the Langfuse UI at `http://localhost:3000`.

### 4. Stopping the Services

To stop the services, run the following command:

```bash
docker-compose -f docker-compose.no-clickhouse.yml down
```

This will stop and remove the containers, networks, and volumes created by the `up` command.
