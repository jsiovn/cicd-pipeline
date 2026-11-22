// DELIBERATELY WRONG: do not copy this pattern.
//
// `count` lives in module scope, so it is shared by every request that reaches
// this process and lost when the process goes away. On one long-running server
// (`node server.js`, a container) it looks like a working counter. On
// serverless it is not a store: each instance has its own copy, instances are
// created, reused and thrown away whenever the platform decides, so requests
// see different, resetting numbers. `processStartedAt` shows which process
// answered. Shared state belongs in an external store (Redis, a database, the
// platform's KV), not in the memory of an instance.
let count = 0;

const processStartedAt = new Date(
  Date.now() - process.uptime() * 1000,
).toISOString();

export function GET() {
  count += 1;
  return Response.json({ count, processStartedAt });
}
