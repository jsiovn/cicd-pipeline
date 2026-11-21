# cicd-pipeline

[![CI](https://github.com/jsiovn/cicd-pipeline/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/jsiovn/cicd-pipeline/actions/workflows/ci.yml)

One small Node.js "orders" API taken through PR checks, tests, Docker images and deploys with GitHub Actions. The app is deliberately tiny: the pipeline around it is the product.

It backs these articles on [JavaScript.io.vn](https://javascript.io.vn/) (in Vietnamese):

- [CI/CD với GitHub Actions cho dự án JavaScript từ đầu](https://javascript.io.vn/2026/11/17/cicd-github-actions-cho-du-an-javascript/)
- [Test cái gì trước? Chiến lược testing pyramid và trophy](https://javascript.io.vn/2026/11/18/chien-luoc-testing-pyramid-trophy-test-gi-truoc/)
- [Docker cho Node.js: multi-stage build và giảm image size](https://javascript.io.vn/2026/11/19/docker-cho-nodejs-multi-stage-build-image-size/)
- [Deploy app JavaScript: static, serverless hay container?](https://javascript.io.vn/2026/11/20/deploy-app-javascript-static-serverless-container/)

## The app

| Path | What it does |
| --- | --- |
| `src/server.ts` | Starts the Express 5 server on `PORT` (default 3000), logs with pino, drains connections on `SIGTERM` |
| `src/app.ts` | `GET /healthz` returns `{"status":"ok","uptime":<seconds>}`; `POST /orders` prices a cart |
| `src/pricing/` | `cartTotal`, `isFreeShipping`, `shippingFee` and their unit tests |
| `src/cart/` | `fetchCart()`: loads the cart from `https://api.example.com/cart` with the global `fetch`; its test intercepts the request with MSW |
| `examples/coverage-trap/` | The Testing post's coverage demo, with its own Vitest config (not part of `npm test`) |

```sh
nvm use            # Node 26 (.nvmrc); Node 22 and 24 are supported too
npm ci
npm run dev        # tsx watch src/server.ts
npm run lint
npm run typecheck  # tsc --noEmit
npm test           # vitest run
npm run test:coverage  # vitest run --coverage, fails below the thresholds in vitest.config.ts
npm run build      # tsc -p tsconfig.build.json -> dist/ (tests excluded)
npm start          # node dist/server.js
```

```sh
curl -s -X POST localhost:3000/orders -H 'content-type: application/json' \
  -d '{"items":[{"sku":"TSHIRT","unitPrice":150000,"quantity":2}]}'
# {"subtotal":300000,"shipping":30000,"total":330000}
```

## Post section -> file -> where to watch it

`.github/workflows/ci.yml` was built one teaching step per commit, so its history is part of the lesson: `git log --oneline -- .github/workflows/ci.yml`. Rows are appended as later steps (PR gate, tests, Docker images, deploys) land.

| Post section | File | Where to watch it |
| --- | --- | --- |
| CI/CD 1 — anatomy of a workflow (minimal workflow) | [`.github/workflows/ci.yml` at 982b006](https://github.com/jsiovn/cicd-pipeline/blob/982b006ff18a6aac56955352601ab650458979dc/.github/workflows/ci.yml) (`ci: minimal workflow`) | [Actions › CI](https://github.com/jsiovn/cicd-pipeline/actions/workflows/ci.yml), commit 982b006 |
| CI/CD 2.1 — sequential pipeline in one job | [`.github/workflows/ci.yml` at 9f71e51](https://github.com/jsiovn/cicd-pipeline/blob/9f71e511e029fd3a53d6fd9f54546f26bdc445fd/.github/workflows/ci.yml) (`ci: full sequential pipeline`) | [Actions › CI](https://github.com/jsiovn/cicd-pipeline/actions/workflows/ci.yml), commit 9f71e51 |
| CI/CD 2.2 — parallel jobs with `needs` | [`.github/workflows/ci.yml` at 80bb44d](https://github.com/jsiovn/cicd-pipeline/blob/80bb44df01fcc7387ec34e0933c3cd7ebc6d4731/.github/workflows/ci.yml) (`ci: split into parallel jobs`) | [Actions › CI](https://github.com/jsiovn/cicd-pipeline/actions/workflows/ci.yml), commit 80bb44d |
| CI/CD 8.1, 8.3, 8.4 — `concurrency`, test matrix [22, 24, 26] with `fail-fast: false`, `timeout-minutes` | [`.github/workflows/ci.yml` at 497165a](https://github.com/jsiovn/cicd-pipeline/blob/497165a10867ad9ff546505955346d0973b4412a/.github/workflows/ci.yml) (`ci: concurrency, matrix, timeouts`; current version: [`ci.yml` on main](https://github.com/jsiovn/cicd-pipeline/blob/main/.github/workflows/ci.yml)) | [Actions › CI](https://github.com/jsiovn/cicd-pipeline/actions/workflows/ci.yml): jobs `lint`, `test (22)`, `test (24)`, `test (26)`, `build` |
| CI/CD 8.2 — `paths` filter | not applied | CI is meant to become a required check, and a `paths` filter would leave PRs outside those paths waiting forever (the trap the post describes) |
| CI/CD 3.1, 3.3 — npm cache built into `actions/setup-node` (`cache: npm`) | [`.github/workflows/ci.yml`](https://github.com/jsiovn/cicd-pipeline/blob/main/.github/workflows/ci.yml) | Miss vs hit timings and the `Cache` log lines: [docs/measurements.md › npm cache: miss vs hit](docs/measurements.md#npm-cache-miss-vs-hit) |
| CI/CD 4 — PR gate: required check + ruleset on `main` | Job `ci-ok` in [`.github/workflows/ci.yml` at 3f4def1](https://github.com/jsiovn/cicd-pipeline/blob/3f4def1b1b070cf81028adadd74c520fa89092b4/.github/workflows/ci.yml) (`ci: add ci-ok, one stable check to require`; current version: [`ci.yml` on main](https://github.com/jsiovn/cicd-pipeline/blob/main/.github/workflows/ci.yml)). It is required instead of the matrix legs `test (22)` …, whose names change with the matrix, and it reports even when a needed job fails or is skipped, so a failing leg or a renamed job cannot leave it pending; ruleset `main`: pull request required, `ci-ok` required with "up to date", no force push, no deletion | [Rulesets page](https://github.com/jsiovn/cicd-pipeline/rules) (opens without a login); exhibits: [#2](https://github.com/jsiovn/cicd-pipeline/pull/2) README-only PR merged through the gate, [#1](https://github.com/jsiovn/cicd-pipeline/pull/1) broken pricing test, merge blocked, kept open |
| CI/CD 7.1 — Dependabot keeps action pins current | [`.github/dependabot.yml` at c24a904](https://github.com/jsiovn/cicd-pipeline/blob/c24a904b7b44fe2e0b9fdbcbd1f8f85c558f83fd/.github/dependabot.yml) (`ci: let Dependabot bump action pins monthly`; current version: [`dependabot.yml` on main](https://github.com/jsiovn/cicd-pipeline/blob/main/.github/dependabot.yml); `github-actions` only, monthly, at most 2 open PRs, `ci` commit prefix) | [Pull requests by Dependabot](https://github.com/jsiovn/cicd-pipeline/pulls?q=is%3Apr+author%3Aapp%2Fdependabot) |
| Testing 3.2 — every combination of three booleans as a `test.each` table | [`src/pricing/pricing.test.ts`](https://github.com/jsiovn/cicd-pipeline/blob/main/src/pricing/pricing.test.ts) (`isFreeShipping: every combination`) | [Actions › CI](https://github.com/jsiovn/cicd-pipeline/actions/workflows/ci.yml): job `test` |
| Testing 3.3 — regression test written red before the fix (bug #412: quantity 0 made the total NaN) | [`src/pricing/pricing.test.ts`](https://github.com/jsiovn/cicd-pipeline/blob/main/src/pricing/pricing.test.ts), fix in [`src/pricing/index.ts`](https://github.com/jsiovn/cicd-pipeline/blob/main/src/pricing/index.ts); history: `git log --oneline -- src/pricing` shows `fix: skip zero-quantity lines…` directly above `test: reproduce bug #412…` (newest first) | Pull request [#4](https://github.com/jsiovn/cicd-pipeline/pull/4) (its first run was red for this test); failure text in [docs/measurements.md › Testing](docs/measurements.md#testing) |
| Testing 5.1, 5.2, 5.3 — 100% coverage that is still wrong, the uncovered lines, a threshold that fails the run | [`examples/coverage-trap/`](https://github.com/jsiovn/cicd-pipeline/blob/main/examples/coverage-trap) (`rating.js`, `rating.test.js`, `shipping.js`, `vitest.config.js` with `thresholds: { lines: 80 }`); `npm run demo:coverage-100`, `demo:coverage-gap`, `demo:coverage-threshold` (exits 1 on purpose) | [Actions › CI](https://github.com/jsiovn/cicd-pipeline/actions/workflows/ci.yml): job `coverage-trap` checks the three exit codes and writes the outputs into its job summary; copies in [docs/measurements.md › Testing](docs/measurements.md#testing) |
| Testing 5.3 — coverage threshold as a safety net for this repo | [`vitest.config.ts`](https://github.com/jsiovn/cicd-pipeline/blob/main/vitest.config.ts) (thresholds at the level the suite reaches) | [Actions › CI](https://github.com/jsiovn/cicd-pipeline/actions/workflows/ci.yml): job `coverage` (table in its job summary) |
| Testing 6.2 — mock at the network level with MSW instead of replacing `fetch` | [`src/cart/fetch-cart.test.ts`](https://github.com/jsiovn/cicd-pipeline/blob/main/src/cart/fetch-cart.test.ts) (MSW 3: `setupServer` from `msw/node`, `http.get`, `HttpResponse.json`) | [Actions › CI](https://github.com/jsiovn/cicd-pipeline/actions/workflows/ci.yml): jobs `test`, `test-shard` |
| Testing 8.1 — tests on every pull request, sharded runs, annotations | Jobs `test-shard` (`vitest run --shard=${{ matrix.shard }}/2`) and `coverage` in [`.github/workflows/ci.yml`](https://github.com/jsiovn/cicd-pipeline/blob/main/.github/workflows/ci.yml); `ci-ok` needs both. No `--reporter=github-actions` (Vitest adds it by itself on GitHub Actions) and no `--bail` | [Actions › CI](https://github.com/jsiovn/cicd-pipeline/actions/workflows/ci.yml): `test-shard (1)`, `test-shard (2)`; why, in [docs/measurements.md › Testing](docs/measurements.md#testing) |

Measured numbers quoted by the posts live in [docs/measurements.md](docs/measurements.md).
