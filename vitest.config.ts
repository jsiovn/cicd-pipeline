import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    // examples/ has its own config; keep its tests out of the main suite.
    include: ["src/**/*.test.ts"],
    coverage: {
      provider: "v8",
      include: ["src/**/*.ts"],
      // The level this suite reaches today: a safety net against drops, not a target.
      thresholds: { lines: 45, functions: 40, branches: 59, statements: 46 },
    },
  },
});
