
import { defineConfig } from '@prisma/config';

export default defineConfig({
  // @ts-ignore
  datasources: {
    db: {
      url: process.env.DATABASE_URL,
    },
  },
});
