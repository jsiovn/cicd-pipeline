import js from "@eslint/js";
import { defineConfig } from "eslint/config";
import globals from "globals";
import tseslint from "typescript-eslint";

export default defineConfig(
  // web/ is the Next.js app: its own package, ESLint config and workflow (web.yml).
  { ignores: ["dist/", "coverage/", "playwright-report/", "test-results/", "_site/", "web/"] },
  js.configs.recommended,
  tseslint.configs.recommended,
  {
    languageOptions: {
      globals: globals.node,
    },
  },
);
