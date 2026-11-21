import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    coverage: {
      provider: "v8",
      include: ["rating.js", "shipping.js"],
      thresholds: { lines: 80 },
    },
  },
});
