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

```sh
nvm use            # Node 26 (.nvmrc); Node 22 and 24 are supported too
npm ci
npm run dev        # tsx watch src/server.ts
npm run lint
npm run typecheck  # tsc --noEmit
npm test           # vitest run
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
| CI/CD 4 — PR gate: required check + ruleset on `main` | Job `ci-ok` in [`.github/workflows/ci.yml`](https://github.com/jsiovn/cicd-pipeline/blob/main/.github/workflows/ci.yml) (the only required check: matrix legs `test (22)` … and renamed jobs never leave it pending); ruleset `main`: pull request required, `ci-ok` required with "up to date", no force push, no deletion | [Rulesets page](https://github.com/jsiovn/cicd-pipeline/rules) (opens without a login); exhibits: [#2](https://github.com/jsiovn/cicd-pipeline/pull/2) README-only PR merged through the gate, [#1](https://github.com/jsiovn/cicd-pipeline/pull/1) broken pricing test, merge blocked, kept open |
| CI/CD 7.1 — Dependabot keeps action pins current | [`.github/dependabot.yml`](https://github.com/jsiovn/cicd-pipeline/blob/main/.github/dependabot.yml) (`github-actions` only, monthly, at most 2 open PRs, `ci` commit prefix) | [Pull requests by Dependabot](https://github.com/jsiovn/cicd-pipeline/pulls?q=is%3Apr+author%3Aapp%2Fdependabot) |

Measured numbers quoted by the posts live in [docs/measurements.md](docs/measurements.md).
