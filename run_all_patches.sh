#!/bin/bash
set -e

# 1. Update Package Overrides
cat << 'PY_EOF' > patch_pkg.py
import json
with open('package.json', 'r') as f:
    data = json.load(f)
data['pnpm']['overrides']['bullmq'] = "^5.34.10"
data['pnpm']['overrides']['ioredis'] = "^5.8.2"
with open('package.json', 'w') as f:
    json.dump(data, f, indent=2)
PY_EOF
python3 patch_pkg.py && rm patch_pkg.py

sed -i 's/"bullmq": "5.66.4"/"bullmq": "^5.34.10"/g' web/package.json
sed -i 's/"bullmq": "5.66.4"/"bullmq": "^5.34.10"/g' worker/package.json
sed -i 's/"bullmq": "5.66.4"/"bullmq": "^5.34.10"/g' packages/shared/package.json
sed -i 's/"ioredis": "^5.4.1"/"ioredis": "^5.8.2"/g' web/package.json
sed -i 's/"ioredis": "^5.4.1"/"ioredis": "^5.8.2"/g' worker/package.json
sed -i 's/"ioredis": "^5.4.1"/"ioredis": "^5.8.2"/g' packages/shared/package.json

# 2. Add dependencies
pnpm --filter @langfuse/shared add pg @prisma/adapter-pg
pnpm --filter web add pg @prisma/adapter-pg
pnpm -w add -D @types/pg
rm -rf pnpm-lock.yaml node_modules packages/*/node_modules web/node_modules worker/node_modules
pnpm install

# 3. Patch Next.js Config
cat << 'PY_EOF' > patch_next.py
import re
with open('web/next.config.mjs', 'r') as f:
    content = f.read()
content = content.replace("""  webpack(config, { isServer }) {
    // Exclude Datadog packages from webpack bundling to avoid issues
    // see: https://docs.datadoghq.com/tracing/trace_collection/automatic_instrumentation/dd_libraries/nodejs/#bundling-with-nextjs
    config.externals.push("@datadog/pprof", "dd-trace");

    // Disable minification completely to avoid webpack constructor issues
    config.optimization = config.optimization || {};
    config.optimization.minimize = false;
    config.optimization.minimizer = [];

    // Server-side Prisma resolution is handled automatically by Next.js serverExternalPackages

    return config;
  },""", """  webpack(config, { isServer }) {
    // Exclude Datadog packages from webpack bundling to avoid issues
    // see: https://docs.datadoghq.com/tracing/trace_collection/automatic_instrumentation/dd_libraries/nodejs/#bundling-with-nextjs
    config.externals.push("@datadog/pprof", "dd-trace");

    // Disable minification completely to avoid webpack constructor issues
    config.optimization = config.optimization || {};
    config.optimization.minimize = false;
    config.optimization.minimizer = [];

    // Fix Prisma Client resolution in pnpm workspace
    if (!isServer) {
      // For client-side builds, exclude Prisma Client completely
      config.resolve.alias = {
        ...config.resolve.alias,
        ".prisma/client/index-browser": false,
        "@prisma/client/index-browser": false,
        "@prisma/client": false,
        ".prisma/client": false,
        ".prisma/client/default": false
      };
      // Add to externals to prevent bundling
      config.externals = config.externals || [];
      config.externals.push(".prisma/client", "@prisma/client");
    }
    // Server-side Prisma resolution is handled automatically by Next.js serverExternalPackages

    return config;
  },""")
with open('web/next.config.mjs', 'w') as f:
    f.write(content)
PY_EOF
python3 patch_next.py && rm patch_next.py

# 4. Patch Prisma DB client
cat << 'PY_EOF' > patch_db.py
import re
with open('packages/shared/src/db.ts', 'r') as f:
    content = f.read()
replacement = """import { DB } from ".";
import { Pool } from "pg";
import { PrismaPg } from "@prisma/adapter-pg";
import { logger } from "./server";

// Keep a single global pool to prevent connection leaks during Next.js Hot Module Replacement (HMR)
const globalForPrisma = globalThis as unknown as {
  prismaGlobal: PrismaClient | undefined;
  kyselyPrismaGlobal: { $kysely: Kysely<DB> } | undefined;
  pgPoolGlobal: Pool | undefined;
};

// Initialize pool outside createPrismaInstance
const pool = globalForPrisma.pgPoolGlobal ?? new Pool({ connectionString: process.env.DATABASE_URL });
if (process.env.NODE_ENV !== "production") globalForPrisma.pgPoolGlobal = pool;
const adapter = new PrismaPg(pool);"""
content = content.replace("""import { DB } from ".";
import { logger } from "./server";""", replacement)
content = content.replace("""const createPrismaInstance = () => {
  // @ts-ignore - Prisma 7 type issue with datasources in monorepo
  const client = new PrismaClient({
    // datasources: {
    //   db: {
    //     url: process.env.DATABASE_URL,
    //   },
    // },
    log: [
      { emit: "event", level: "query" },
      { emit: "event", level: "error" },
      { emit: "event", level: "warn" },
    ],
  } as any);""", """const createPrismaInstance = () => {
  // @ts-ignore - Prisma 7 type issue with datasources in monorepo
  const client = new PrismaClient({
    adapter,
    log: [
      { emit: "event", level: "query" },
      { emit: "event", level: "error" },
      { emit: "event", level: "warn" },
    ],
  } as any);""")
with open('packages/shared/src/db.ts', 'w') as f:
    f.write(content)
PY_EOF
python3 patch_db.py && rm patch_db.py

# 5. Patch Client Imports
cat << 'PY_EOF' > patch_client_imports.py
import re
files_to_patch = [
    'web/src/features/organizations/components/NewOrganizationForm.tsx',
    'web/src/features/playground/page/components/PlaygroundTools/index.tsx'
]
for file_path in files_to_patch:
    with open(file_path, 'r') as f:
        content = f.read()
    if "NewOrganizationForm.tsx" in file_path:
        content = content.replace('import { SurveyName } from "@prisma/client";', 'import type { SurveyName } from "@langfuse/shared";')
        content = content.replace('SurveyName.USER_ONBOARDING', '"USER_ONBOARDING" as any')
    else:
        content = content.replace('import { type LlmTool } from "@prisma/client";', 'import type { LlmTool } from "@langfuse/shared";')
    with open(file_path, 'w') as f:
        f.write(content)
PY_EOF
python3 patch_client_imports.py && rm patch_client_imports.py

# 6. Rebuild shared prisma generated client
cd packages/shared && DATABASE_URL="postgresql://dummy" pnpm run db:generate
