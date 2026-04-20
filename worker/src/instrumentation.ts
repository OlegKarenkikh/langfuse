// dd-trace is only available in Cloud (Datadog) deployments.
// Use a safe dynamic require so the worker starts in open-source images too.
let dd: { init: (opts: Record<string, unknown>) => void } = { init: () => {} };
try {
  // eslint-disable-next-line @typescript-eslint/no-require-imports, @typescript-eslint/no-var-requires
  const mod = require("dd-trace");
  if (mod && typeof mod.init === "function") {
    dd = mod;
  }
} catch (_e) {
  // dd-trace is not installed — skip Datadog tracing silently
}

import { NodeSDK } from "@opentelemetry/sdk-node";
import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-proto";
import { IORedisInstrumentation } from "@opentelemetry/instrumentation-ioredis";
import { HttpInstrumentation } from "@opentelemetry/instrumentation-http";
import { ExpressInstrumentation } from "@opentelemetry/instrumentation-express";
import { PrismaInstrumentation } from "@prisma/instrumentation";
import { WinstonInstrumentation } from "@opentelemetry/instrumentation-winston";
import { AwsInstrumentation } from "@opentelemetry/instrumentation-aws-sdk";
import { BullMQInstrumentation } from "@appsignal/opentelemetry-instrumentation-bullmq";
import {
  envDetector,
  processDetector,
  Resource,
} from "@opentelemetry/resources";
import { awsEcsDetectorSync } from "@opentelemetry/resource-detector-aws";
import { containerDetector } from "@opentelemetry/resource-detector-container";
import { env } from "./env";

dd.init({
  runtimeMetrics: true,
  plugins: false,
});

const sdk = new NodeSDK({
  resource: new Resource({
    "service.name": env.OTEL_SERVICE_NAME,
    "service.version": env.BUILD_ID,
  }),
  traceExporter: new OTLPTraceExporter({
    url: `${env.OTEL_EXPORTER_OTLP_ENDPOINT}/v1/traces`,
  }),
  instrumentations: [
    new IORedisInstrumentation(),
    new HttpInstrumentation({
      requireParentforOutgoingSpans: true,
      ignoreIncomingRequestHook: (req) => {
        return ["/api/public/health", "/api/public/ready", "/api/health"].some(
          (path) => req.url?.includes(path),
        );
      },
      ignoreOutgoingRequestHook: (req) => {
        return req.host === "127.0.0.1";
      },
      requestHook: (span, req: any) => {
        const url = "path" in req ? req?.path : req?.url;
        let path = new URL(url, `http://${req?.host ?? "localhost"}`).pathname;
        if (path.startsWith("/_next/static")) {
          path = "/_next/static/*";
        }
        span.updateName(`${req?.method} ${path}`);
      },
    }),
    new ExpressInstrumentation(),
    new PrismaInstrumentation(),
    new AwsInstrumentation(),
    new WinstonInstrumentation({ disableLogSending: true }),
    new BullMQInstrumentation({ useProducerSpanAsConsumerParent: true }),
  ],
  resourceDetectors: [
    envDetector,
    processDetector,
    awsEcsDetectorSync,
    containerDetector,
  ],
});

sdk.start();
