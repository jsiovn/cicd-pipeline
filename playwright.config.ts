import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  // list: "1 passed" / "1 flaky" in the log; html: the report CI uploads on failure.
  reporter: [["list"], ["html", { open: "never" }]],
  use: {
    baseURL: "http://localhost:3000",
    trace: "on-first-retry",
  },
  webServer: {
    command: "npm run build && npm start",
    url: "http://localhost:3000/healthz",
    reuseExistingServer: !process.env.CI,
  },
});
