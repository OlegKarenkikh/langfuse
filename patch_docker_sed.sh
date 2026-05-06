#!/bin/bash
sed -i '/RUN npx tsc -p tsconfig.json/i \
RUN sed -i '"'"'s/args\\[0\\]\\.map(parseOrderByItem)/args[0].map((expr: any) => parseOrderByItem(expr))/g'"'"' src/parser/order-by-parser.ts\nRUN sed -i '"'"'s/extends OrderByInterface<DB, TB, never>/extends OrderByInterface<DB, TB, {}>/g'"'"' src/query-builder/update-query-builder.ts\n' web/Dockerfile

sed -i '/RUN npx tsc -p tsconfig.json/i \
RUN sed -i '"'"'s/args\\[0\\]\\.map(parseOrderByItem)/args[0].map((expr: any) => parseOrderByItem(expr))/g'"'"' src/parser/order-by-parser.ts\nRUN sed -i '"'"'s/extends OrderByInterface<DB, TB, never>/extends OrderByInterface<DB, TB, {}>/g'"'"' src/query-builder/update-query-builder.ts\n' worker/Dockerfile
