# Measurements

Numbers the articles quote about this repo: run times, cache hits, image sizes.

Rule: every entry is dated and copied verbatim from a real run (a GitHub Actions log or a local terminal). Nothing here is estimated or rounded by hand. Each entry names the commit it was measured on.

## npm cache: miss vs hit

Measured 2026-11-21 on commit [`c24a904`](https://github.com/jsiovn/cicd-pipeline/commit/c24a904b7b44fe2e0b9fdbcbd1f8f85c558f83fd) (`ci: let Dependabot bump action pins monthly`), workflow `.github/workflows/ci.yml` with `actions/setup-node@v7` and `cache: npm` in every job.

Method: `gh cache delete --all --repo jsiovn/cicd-pipeline` (the cache list was empty afterwards), then `gh run rerun` of that commit's CI run on `main`, twice. Attempt 2 started with no cache (MISS); attempt 3 found the cache attempt 2 saved (HIT). Durations come from `gh run view <run> --attempt <n> --json jobs` (`completedAt - startedAt`, whole seconds as the API reports them); log lines from `gh run view <run> --attempt <n> --log`.

Run wall clock (`run_started_at` → `updated_at`): attempt 2 (miss) 22:19:51Z → 22:20:29Z = **38s**; attempt 3 (hit) 22:20:40Z → 22:21:17Z = **37s**.

| Job | setup-node step, miss | setup-node step, hit | `npm ci`, miss | `npm ci`, hit | Post setup-node (save), miss | Post setup-node (save), hit | Job total, miss | Job total, hit |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `lint` | 4s | 5s | 3s | 2s | 0s | 1s | 13s | 13s |
| `test (22)` | 3s | 1s | 4s | 3s | 0s | 0s | 12s | 8s |
| `test (24)` | 1s | 2s | 3s | 4s | 2s | 0s | 12s | 12s |
| `test (26)` | 5s | 6s | 3s | 2s | 1s | 0s | 15s | 13s |
| `build` | 4s | 5s | 1s | 2s | 0s | 0s | 12s | 12s |

`build` is not a miss in attempt 2: it starts after `lint` and `test`, and by then `test (24)` had saved the cache, so `build` restored it (see the log lines below).

Cache result lines, attempt 2 (MISS), verbatim (job | step | line; the input echo, `Cache mode` and tar command lines are left out):

```text
lint      | Run actions/setup-node@v7      | npm cache is not found
lint      | Post Run actions/setup-node@v7 | Failed to save: Unable to reserve cache with key node-cache-Linux-x64-npm-69442cf72541798e6d6a3b70c630246b4a18820075ef217749b164b7604c876d, another job may be creating this cache.
test (22) | Run actions/setup-node@v7      | npm cache is not found
test (22) | Post Run actions/setup-node@v7 | Failed to save: Unable to reserve cache with key node-cache-Linux-x64-npm-69442cf72541798e6d6a3b70c630246b4a18820075ef217749b164b7604c876d, another job may be creating this cache.
test (24) | Run actions/setup-node@v7      | npm cache is not found
test (24) | Post Run actions/setup-node@v7 | Cache saved with the key: node-cache-Linux-x64-npm-69442cf72541798e6d6a3b70c630246b4a18820075ef217749b164b7604c876d
test (26) | Run actions/setup-node@v7      | npm cache is not found
test (26) | Post Run actions/setup-node@v7 | Failed to save: Unable to reserve cache with key node-cache-Linux-x64-npm-69442cf72541798e6d6a3b70c630246b4a18820075ef217749b164b7604c876d, another job may be creating this cache.
build     | Run actions/setup-node@v7      | Cache hit for: node-cache-Linux-x64-npm-69442cf72541798e6d6a3b70c630246b4a18820075ef217749b164b7604c876d
build     | Run actions/setup-node@v7      | Cache Size: ~41 MB (42600099 B)
build     | Run actions/setup-node@v7      | Cache restored successfully
build     | Run actions/setup-node@v7      | Cache restored from key: node-cache-Linux-x64-npm-69442cf72541798e6d6a3b70c630246b4a18820075ef217749b164b7604c876d
build     | Post Run actions/setup-node@v7 | Cache hit occurred on the primary key node-cache-Linux-x64-npm-69442cf72541798e6d6a3b70c630246b4a18820075ef217749b164b7604c876d, not saving cache.
```

Attempt 3 (HIT): the same five lines in every job (`lint`, `test (22)`, `test (24)`, `test (26)`, `build`), verbatim:

```text
Cache hit for: node-cache-Linux-x64-npm-69442cf72541798e6d6a3b70c630246b4a18820075ef217749b164b7604c876d
Cache Size: ~41 MB (42600099 B)
Cache restored successfully
Cache restored from key: node-cache-Linux-x64-npm-69442cf72541798e6d6a3b70c630246b4a18820075ef217749b164b7604c876d
Cache hit occurred on the primary key node-cache-Linux-x64-npm-69442cf72541798e6d6a3b70c630246b4a18820075ef217749b164b7604c876d, not saving cache.
```

What the numbers say:

- On this repo the cache changes nothing measurable: `npm ci` takes 1–4s with or without it, and the whole run takes 38s vs 37s. The install is small (one ~41 MB cache archive), so there is little to save.
- The key is `node-cache-<OS>-<arch>-npm-<hash of package-lock.json>`. It has no Node version in it, so all five jobs, across Node 22, 24 and 26, share ONE cache entry.
- On a cold cache, parallel jobs race to save that one key: one wins (`Cache saved with the key`), the others log `Failed to save: Unable to reserve cache ... another job may be creating this cache.` and still succeed.
- The setup-node step also installs Node itself (Node 26 is downloaded, Node 22 and 24 come from the runner's tool cache), so its time is not a pure cache-restore time.

`actions/setup-node` and automatic caching — source: the action's README at tag `v7`, read 2026-11-21 (documentation, not a measurement; latest release `v7.1.0`). From its caching section:

> Caching for npm dependencies is automatically enabled when your `package.json` contains either `devEngines.packageManager` field or top-level `packageManager` field set to `npm`, and no explicit cache input is provided.

> If your `package.json` file does not include a `packageManager` field set to `npm`, caching will be disabled unless you explicitly enable it.

Its "Breaking changes in V6" list repeats this rule as a bullet (V5 had first turned caching on by default with package-manager detection). The switch is the `package-manager-cache` input, default `true`; the setup-node step of every job in the runs above echoes `package-manager-cache: true` among its inputs. This repo's `package.json` has no `packageManager` field, so caching here comes from the explicit `cache: npm` line. Yarn and pnpm are never cached automatically: they need `cache: yarn` / `cache: pnpm`.

## PR gate

Set up 2026-11-21, with `main` at `c24a904` (`3f4def1` added `ci-ok`, `c24a904` added Dependabot). Ruleset `main` (id 27813828), created with `gh api -X POST repos/jsiovn/cicd-pipeline/rulesets --input <file>`: enforcement `active`, target the default branch, no bypass actors.

`gh api repos/jsiovn/cicd-pipeline/rules/branches/main --jq '.[].type'`:

```text
deletion
non_fast_forward
pull_request
required_status_checks
```

`pull_request` requires 0 approvals (one maintainer). `required_status_checks` requires the single check `ci-ok`, with "Require branches to be up to date" (`strict_required_status_checks_policy: true`). `ci-ok` is the job in `ci.yml` that `needs: [lint, test, build]` and runs with `if: always()`, so it reports even when a needed job failed or was skipped: a failing matrix leg or a renamed job cannot leave it "expected". (A pull request that starts no CI run at all — a merge conflict, a `[skip ci]` commit — still leaves it expected.)

A direct push to `main` (an empty commit) after the ruleset was active, verbatim:

```text
remote: - Changes must be made through a pull request.
remote:
remote: - Required status check "ci-ok" is expected.
remote:
To https://github.com/jsiovn/cicd-pipeline.git
 ! [remote rejected] HEAD -> main (push declined due to repository rule violations)
error: failed to push some refs to 'https://github.com/jsiovn/cicd-pipeline.git'
```

Ruleset page without a login: `curl -s -o /dev/null -w "%{http_code}" https://github.com/jsiovn/cicd-pipeline/rules` printed `200` (2026-11-21 22:22 UTC), and the page it returns is titled `Rulesets · cicd-pipeline · GitHub`. Anonymous readers can open it; no login is needed.

Exhibit pull requests (label `exhibit`):

- [#2](https://github.com/jsiovn/cicd-pipeline/pull/2) `docs: show the CI status of main in the README` touches only `README.md`. `gh pr view 2 --json mergeStateStatus,statusCheckRollup` before merging: `CLEAN`; `lint`, `test (22)`, `test (24)`, `test (26)`, `build` and `ci-ok` all `COMPLETED SUCCESS`. Squash-merged through the gate.
- [#1](https://github.com/jsiovn/cicd-pipeline/pull/1) `[exhibit] Raise the free-shipping threshold to 600,000 VND` changes `FREE_SHIPPING_THRESHOLD` in `src/pricing/index.ts` from `500_000` to `600_000`, and is kept open. Snapshot with its head at `a1bc637`, rebased on `main` at `997bf1f`: `mergeStateStatus` `BLOCKED`; `lint` `SUCCESS`; `test (22)`, `test (24)`, `test (26)` `FAILURE`; `build` `SKIPPED`; `ci-ok` `FAILURE`. The failing test, from the log: `FAIL src/pricing/pricing.test.ts > isFreeShipping > is free from 500,000 VND`, `AssertionError: expected false to be true // Object.is equality`, `Tests 1 failed | 8 passed (9)`.
  - Vitest's GitHub Actions annotation (read with `gh api repos/jsiovn/cicd-pipeline/check-runs/<id>/annotations`) sits at `src/pricing/pricing.test.ts:25`, title `src/pricing/pricing.test.ts > isFreeShipping > is free from 500,000 VND`. The PR itself does not touch that file: the annotation points at the test that broke, not at the line that broke it.

## Testing

Measured 2026-11-21 (runs between 22:39Z and 22:43Z) on the commits of pull request [#4](https://github.com/jsiovn/cicd-pipeline/pull/4), before it was rebase-merged (the merge rewrites the SHAs, so commits are named by subject below). Outputs are copied from the GitHub Actions logs with the timestamp prefix removed; the `coverage` and `coverage-trap` jobs run with `NO_COLOR=1`. Where a block is marked as an excerpt, lines were left out (said each time); nothing was reworded.

Versions: `vitest` 5.1.1, `@vitest/coverage-v8` 5.1.1, `msw` 3.0.7; the `coverage`, `coverage-trap` and `test-shard` jobs ran on Node v26.13.1 (`actions/setup-node@v7`, `node-version: 26`); the `test` matrix on 22, 24 and 26.

### Regression test: red, then green

`test: reproduce bug #412, quantity 0 makes the cart total NaN` was pushed alone and its run failed for the stated reason (`test (22)`, `test (24)`, `test (26)` failure, `build` skipped, `ci-ok` failure). Excerpt of the `test (22)` log (the passing tests, the code frame and the timing lines left out):

```text
   × bug #412: quantity = 0 must not break the total 4ms
 FAIL  src/pricing/pricing.test.ts > bug #412: quantity = 0 must not break the total
AssertionError: expected NaN to be +0 // Object.is equality
 Test Files  1 failed (1)
      Tests  1 failed | 17 passed (18)
```

The next commit, `fix: skip zero-quantity lines in cartTotal (bug #412)`, turned it green. The `test.each` table names its eight rows `total=400000 vip=false express=false -> false` … `total=600000 vip=true express=true -> false`.

### Coverage gate (`coverage` job)

`npx vitest run --coverage` with `coverage.include: ["src/**/*.ts"]` and thresholds at the level the suite reaches (`lines: 45, functions: 40, branches: 59, statements: 46`):

```text
 % Coverage report from v8
----------------|---------|----------|---------|---------|-------------------
File            | % Stmts | % Branch | % Funcs | % Lines | Uncovered Line #s 
----------------|---------|----------|---------|---------|-------------------
All files       |   46.51 |    59.09 |      40 |      45 |                   
 src            |       0 |        0 |       0 |       0 |                   
  app.ts        |       0 |        0 |       0 |       0 | 12-27             
  server.ts     |       0 |        0 |       0 |       0 | 4-18              
 src/cart       |     100 |      100 |     100 |     100 |                   
  fetch-cart.ts |     100 |      100 |     100 |     100 |                   
 src/pricing    |     100 |      100 |     100 |     100 |                   
  index.ts      |     100 |      100 |     100 |     100 |                   
----------------|---------|----------|---------|---------|-------------------
```

### Coverage trap (`coverage-trap` job, `examples/coverage-trap/`)

`npm run demo:coverage-100` (only `rating.js` included, `text-summary` reporter), exit code 0:

```text
 % Coverage report from v8

=============================== Coverage summary ===============================
Statements   : 100% ( 3/3 )
Branches     : 100% ( 0/0 )
Functions    : 100% ( 2/2 )
Lines        : 100% ( 2/2 )
================================================================================
```

`npm run demo:coverage-gap` (`rating.js` and `shipping.js`, `text` reporter, threshold switched off with `--coverage.thresholds.lines=0`), exit code 0:

```text
 % Coverage report from v8
-------------|---------|----------|---------|---------|-------------------
File         | % Stmts | % Branch | % Funcs | % Lines | Uncovered Line #s 
-------------|---------|----------|---------|---------|-------------------
All files    |      50 |        0 |   66.66 |      50 |                   
 rating.js   |     100 |      100 |     100 |     100 |                   
 shipping.js |       0 |        0 |       0 |       0 | 2-3               
-------------|---------|----------|---------|---------|-------------------
```

`npm run demo:coverage-threshold` (same files, `thresholds: { lines: 80 }` from `examples/coverage-trap/vitest.config.js`), exit code 1:

```text
 % Coverage report from v8
-------------|---------|----------|---------|---------|-------------------
File         | % Stmts | % Branch | % Funcs | % Lines | Uncovered Line #s 
-------------|---------|----------|---------|---------|-------------------
All files    |      50 |        0 |   66.66 |      50 |                   
 rating.js   |     100 |      100 |     100 |     100 |                   
 shipping.js |       0 |        0 |       0 |       0 | 2-3               
-------------|---------|----------|---------|---------|-------------------
ERROR: Coverage for lines (50%) does not meet global threshold (80%)
```

Each demo also prints Vitest's run header (`RUN  v5.1.1 …/examples/coverage-trap`, `Coverage enabled with v8`, `✓ rating.test.js (1 test)`, `Tests  1 passed (1)`) before the coverage block.

### Shards (`test-shard` job)

`npx vitest run --shard=${{ matrix.shard }}/2` splits by test file, not by test: with two files, each leg runs one file. Which leg gets which file is decided by Vitest, not by this repo. On this run, `test-shard (1)` (excerpt: ANSI colour codes stripped, `Start at` and `Duration` lines left out):

```text
 RUN  v5.1.1 /home/runner/work/cicd-pipeline/cicd-pipeline

 ✓ src/cart/fetch-cart.test.ts (2 tests) 41ms

 Test Files  1 passed (1)
      Tests  2 passed (2)
```

`test-shard (2)` (same excerpt rules):

```text
 RUN  v5.1.1 /home/runner/work/cicd-pipeline/cicd-pipeline

 ✓ src/pricing/pricing.test.ts (18 tests) 4ms

 Test Files  1 passed (1)
      Tests  18 passed (18)
```

Asking for more shards than there are test files is an error, not an empty leg (unless `--passWithNoTests` is set: Vitest skips this check then). Local run, 2026-11-22, Node v22.23.1, `npx vitest run --shard=1/4` (the same for 2/4, 3/4 and 4/4), exit code 1:

```text
⎯⎯⎯⎯⎯⎯ Unhandled Error ⎯⎯⎯⎯⎯⎯⎯
Error: --shard <count> must be a smaller than count of test files. Resolved 2 test files for --shard=1/4.
```

(`--shard=2/2`, a count equal to the number of files, runs fine, as the CI legs above show.)

### CI flags (Testing post 8.1)

- `--reporter=github-actions` does not have to be passed. Vitest 5 docs (guide › Reporters › Default Configuration): with no `reporters` configured, `github-actions` is added when `process.env.GITHUB_ACTIONS === 'true'`; configuring reporters replaces that default list, so `--reporter=github-actions` alone drops the normal terminal output. Local check, 2026-11-22, Node v22.23.1: `GITHUB_ACTIONS=true NO_COLOR=1 npx vitest run --reporter=github-actions` on this suite (all 20 tests passing) printed nothing at all and exited 0. Real run: the red commit's `test (22)` job ran plain `vitest run` (`npm test`, no flag) and its check run carries the annotation `src/pricing/pricing.test.ts:70`, title `src/pricing/pricing.test.ts > bug #412: quantity = 0 must not break the total`, message `AssertionError: expected NaN to be +0 // Object.is equality` (read with `gh api repos/jsiovn/cicd-pipeline/check-runs/<id>/annotations`); the log shows it as `##[error]AssertionError: expected NaN to be +0 // Object.is equality`.
- `--bail=1` is not used here. `vitest --help`: "Stop test execution when given number of tests have failed (default: 0)". A pull-request run should list every failure at once, and this suite finishes in under a second; bail only pays off on long suites where the first failure is enough to reject the change.
- Local runs differ from CI: Vitest 5 detects AI coding agents (`std-env` `isAgent`) and then uses the `minimal` reporter and adds `skipFull` plus `text-summary` to the `text` coverage reporter. All outputs above come from GitHub Actions, where neither applies. With an agent variable set (`CLAUDECODE=1 npm run demo:coverage-gap`, local, 2026-11-22) the `rating.js` row disappears from the table and a `Coverage summary` block (Lines 50% ( 2/4 )) follows it.

### Post says / reality

The teaching points hold on Vitest 5 and MSW 3: one test gives 100% coverage while `averageRating([])` is still `NaN`, the table lists the never-run lines, and the threshold fails the run with exit code 1. Differences, all in details:

| Post section | Post says | Reality (Vitest 5.1.1 / MSW 3.0.7) |
| --- | --- | --- |
| 5.1 | Run with Vitest 4.1.10 | Vitest 5.1.1 prints the same `Coverage summary` block, numbers identical (3/3, 0/0, 2/2, 2/2). That block is the `text-summary` reporter; the default `text` reporter prints a table instead, so the demo passes `--coverage.reporter=text-summary`. A ` % Coverage report from v8` line precedes it |
| 5.2 | Table has `All files` and `shipping.js` rows only | In a normal terminal and on CI the table also has a `rating.js` row (100 / 100 / 100 / 100) between them; the `All files` (50 / 0 / 66.66 / 50) and `shipping.js` (`2-3`) rows match. The post's exact table is what Vitest 5 prints when it detects an AI coding agent (`skipFull` hides files at 100%; see CI flags above) |
| 5.3 | `ERROR: Coverage for lines (50%) does not meet global threshold (80%)`, exit code 1 | Identical text and exit code 1 |
| 3.3 | `cartTotal([{ price: 100_000, quantity: 0 }])`, `import { cartTotal } from "./cart"` | The repo's line item is `{ sku, unitPrice, quantity }` and the import is `./index.js` (ESM with `nodenext` needs the extension); the defect really produced `NaN` (`expected NaN to be +0`) |
| 6.2 | MSW 2.15.0; `http`, `HttpResponse` from `"msw"`, `setupServer` from `"msw/node"`, `server.listen()` | Unchanged in MSW 3.0.7: the same imports work. MSW 3 also exports `msw/http` (used in its README); 2.15.0 exported `msw/core/http` instead. The `listen()` option is renamed: `onUnhandledRequest` is now `onUnhandledFrame` (the old name is a TypeScript error, TS2353). The post does not pass the option, so its snippet runs as printed |
| 8.1 | Enable `vitest run --reporter=github-actions` on CI | Already active under GitHub Actions without the flag; passing it replaces the default reporter (see CI flags above) |
| 8.1 | `vitest run --bail=1` is worth enabling on CI | Not a sensible default for pull-request runs (see CI flags above) |
| 8.1 | `vitest run --shard=1/4` | Shards split by test file, and the count may not exceed the number of test files: in this repo (2 test files) `--shard=1/4` fails with exit code 1 (see Shards above). Fine on a suite with 4 or more files |
