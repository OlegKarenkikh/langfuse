import { defineConfig } from "@prisma/config";

/**
 * Prisma 7+ requires datasource.url to be configured here.
 * The --url CLI flag was removed in v7.
 * DATABASE_URL is injected at runtime via Docker environment variables.
 */
export default defineConfig({
  schema: "./prisma/schema.prisma",
  datasource: {
    url: process.env.DATABASE_URL ?? process.env.DIRECT_URL ?? "",
  },
});
