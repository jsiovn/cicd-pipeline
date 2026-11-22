import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
  // web/ is not the repository root: without this, Next.js sees the root
  // package-lock.json too, takes the repository root as the workspace root and
  // nests the output at .next/standalone/web/server.js.
  outputFileTracingRoot: __dirname,
};

export default nextConfig;
