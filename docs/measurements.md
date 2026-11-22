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

## E2E

Measured 2026-11-21 (UTC) on pull request [#5](https://github.com/jsiovn/cicd-pipeline/pull/5), on its head commit `ci: e2e job with a hand-written Playwright browser cache key` (`f0f683a`, a SHA that only the pull request keeps once it is squash-merged). Job `e2e` in `.github/workflows/ci.yml`: Node 26 (v26.13.1), `npm ci`, `actions/cache@v6` on `~/.cache/ms-playwright`, `npx playwright install --with-deps chromium`, `npx playwright test`. Log lines are verbatim with the timestamp prefix removed.

Versions: `@playwright/test` 1.65.1 (`npx playwright --version` prints `Version 1.65.1`); it installs Chrome for Testing 159.0.8154.6 (playwright chromium v1255), Chrome Headless Shell 159.0.8154.6 (chromium-headless-shell v1255) and FFmpeg (v1013).

Method: before the first push `gh cache list --repo jsiovn/cicd-pipeline` had no `Linux-playwright-` entry, so the PR's first run was a real MISS. `gh run rerun` of that run gave attempt 2, which restored the cache attempt 1 had saved (HIT; a pull request's caches are visible to later runs of the same pull request). Durations come from `gh run view <run> --attempt <n> --json jobs` (`completedAt - startedAt`, whole seconds as the API reports them).

Run wall clock (`run_started_at` → `updated_at`): attempt 1 (miss) 23:00:13Z → 23:01:03Z = **50s**; attempt 2 (hit) 23:01:26Z → 23:02:06Z = **40s**.

| Step of job `e2e` | Miss | Hit |
| --- | --- | --- |
| `Cache Playwright browsers` (restore) | 1s | 3s |
| `npx playwright install --with-deps chromium` | 17s | 10s |
| `npx playwright test` | 6s | 4s |
| `Post Cache Playwright browsers` (save) | 4s | 0s |
| **Job total** | **42s** | **30s** |

Cache lines, attempt 1 (MISS) (step | line):

```text
Cache Playwright browsers      | key: Linux-playwright-1.65.1
Cache Playwright browsers      | restore-keys: Linux-playwright-
Cache Playwright browsers      | Cache not found for input keys: Linux-playwright-1.65.1, Linux-playwright-
Run npx playwright install ... | Chrome for Testing 159.0.8154.6 (playwright chromium v1255) downloaded to /home/runner/.cache/ms-playwright/chromium-1255
Run npx playwright install ... | FFmpeg (playwright ffmpeg v1013) downloaded to /home/runner/.cache/ms-playwright/ffmpeg-1013
Run npx playwright install ... | Chrome Headless Shell 159.0.8154.6 (playwright chromium-headless-shell v1255) downloaded to /home/runner/.cache/ms-playwright/chromium_headless_shell-1255
Post Cache Playwright browsers | Sent 307324571 of 307324571 (100.0%), 183.1 MBs/sec
Post Cache Playwright browsers | Cache saved with key: Linux-playwright-1.65.1
```

Cache lines, attempt 2 (HIT); the install step printed no `Downloading` line:

```text
Cache Playwright browsers      | Cache hit for: Linux-playwright-1.65.1
Cache Playwright browsers      | Received 307324571 of 307324571 (100.0%), 175.5 MBs/sec
Cache Playwright browsers      | Cache Size: ~293 MB (307324571 B)
Cache Playwright browsers      | Cache restored successfully
Cache Playwright browsers      | Cache restored from key: Linux-playwright-1.65.1
Post Cache Playwright browsers | Cache hit occurred on the primary key Linux-playwright-1.65.1, not saving cache.
```

Test result, both attempts: `Running 1 test using 1 worker`, then `1 passed (4.7s)` (miss) and `1 passed (3.0s)` (hit). No `flaky` and no retry: the test passed on its first try both times, so `retries: 2` never ran.

What the numbers say:

- Job total 42s → 30s, of which about 9s comes from the cache (one run each): the install step loses the three downloads (17s → 10s; the downloads took about 8s, first `Downloading` line 23:00:37.7Z → last `downloaded to` 23:00:45.9Z), the restore step grows from 1s to 3s for the 293 MB archive, and a hit skips the 4s save. The remaining ~3s is the test step (6s → 4s) and setup noise, not the cache.
- `--with-deps` still runs on a hit: the install step keeps about 8.5s of `apt-get` work (23:01:43.9Z → 23:01:52.4Z), because system packages are not part of the cache. On the `ubuntu-latest` image every package was already present (`... is already the newest version`).
- The key holds the Playwright version, read from the installed package, so upgrading `@playwright/test` changes the key. Not measured (neither run above used `restore-keys`), expected from the code of `playwright-core` 1.65.1: `restore-keys: Linux-playwright-` restores the previous version's browsers, `playwright install` first deletes the browser directories the new version does not use (log line `Removing unused browser at ...`, skipped only with `PLAYWRIGHT_SKIP_BROWSER_GC`), downloads the new revisions, and the job saves a new entry under the new key. So after a Chromium bump the prefix match mostly restores files that are deleted right away; it pays off only for parts whose revision did not change (such as FFmpeg). With a package-manager cache like the post's Bun example, a prefix match restores packages that are reused.
- Caches written by a pull request are scoped to that pull request (GitHub docs, "Restrictions for accessing a cache"; not measured here), so the first run on `main` after the merge is expected to miss and save the entry that `main` and later pull requests use.

Playwright's own advice — source: the Playwright docs, "Continuous Integration › Caching browsers", read 2026-11-22 through Context7 (documentation, not a measurement):

> Caching browser binaries is not recommended, since the amount of time it takes to restore the cache is comparable to the time it takes to download the binaries. Especially under Linux, operating system dependencies need to be installed, which are not cacheable.

Here the restore was clearly faster than the download (3s vs about 8s), so the first half did not hold on this run; the second half did (the apt step stays). The cache is kept here because it is the CI/CD post's example of a key written by hand.

### Post says / reality (E2E)

| Post section | Post says | Reality (Playwright 1.65.1, docs read 2026-11-22) |
| --- | --- | --- |
| Testing 7.2 | Playwright 1.61.1 | 1.65.1 is current; [`e2e/checkout.spec.ts`](../e2e/checkout.spec.ts) is the post's snippet unchanged and passes against `GET /checkout` |
| Testing 7.2 | Config: `fullyParallel: true`, `forbidOnly: !!process.env.CI`, `retries: process.env.CI ? 2 : 0`, `use.trace: "on-first-retry"` | All four are written exactly so in the current docs. The docs' CI page also sets `workers: process.env.CI ? 1 : undefined` (left out here: one test), and the config `npm init playwright` generates sets `reporter: "html"`. A runnable config also needs `baseURL` (for `page.goto("/checkout")`) and `webServer` (to start the app): [`playwright.config.ts`](../playwright.config.ts) adds both, plus a `list` reporter so the log shows `1 passed` / `1 flaky` |
| CI/CD 3.2 | `actions/cache@v6`, `key: ${{ runner.OS }}-…`, `restore-keys` prefix | Exact `key` match measured above (`Cache hit for: Linux-playwright-1.65.1`). The `restore-keys` fallback (newest entry matching the prefix) is the behaviour the `actions/cache` README (latest v6.1.0) describes; no run here exercised it. The job writes `runner.os`; expressions are case-insensitive, so `runner.OS` gives the same `Linux` |

## Docker images

Measured 2026-11-21 (job start 23:22 UTC) by job `sizes` of [`.github/workflows/image.yml`](../.github/workflows/image.yml) on pull request [#6](https://github.com/jsiovn/cicd-pipeline/pull/6), head commit `dfb866b` (`build: measure unpacked image size from the docker history layers`; `GITHUB_SHA` = test merge commit `190a165`). The job runs [`docker/sizes.sh`](../docker/sizes.sh); the numbers below are copied from the `sizes.json` artifact it uploaded.

Runner: `ubuntu-latest`, Docker `29.4.2` (server), `github.com/docker/buildx v0.39.0 360040a78d6113dc84e5d4dcdf0f438e1be7a41f`, Buildx `docker-container` driver from `docker/setup-buildx-action@v4`, `linux/amd64`.

Node major: **26** for every variant. Node 26 is the Active LTS since 2026-10-28, and every base image exists for it: `node:26`, `node:26-slim` (Debian 13 trixie), `node:26-alpine` and `gcr.io/distroless/nodejs26-debian13`. Distroless has no Debian 12 image for Node 26 (`gcr.io/distroless/nodejs26-debian12` lists no tags), so the distroless variant uses Debian 13 — the same Debian release as the `-slim` stages that install its `node_modules`, so the glibc that the bcrypt prebuild links against matches. `docker history` of the production image shows `ENV NODE_VERSION=26.13.1`.

### Sizes

"Size" is the unpacked size: the sum of the layer sizes `docker history --human=false` reports, which is the number the classic `docker images` SIZE column showed. Docker 29 on the runner uses the containerd image store, where the SIZE column of `docker image ls` is disk usage (unpacked layers plus the compressed blobs) and `docker image inspect .Size` is the compressed content size; both are recorded too. "Compressed" is what `docker pull` downloads.

| Variant | Dockerfile | Base image | Base size | Final size | Base compressed | Final compressed | `docker image ls` SIZE (base / final) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| naive | [`docker/Dockerfile.naive`](../docker/Dockerfile.naive) | `node:26` | 1.34GB | 1.59GB | 445MB | 547MB | 1.8GB / 2.14GB |
| ordered | [`docker/Dockerfile.ordered`](../docker/Dockerfile.ordered) | `node:26` | 1.34GB | 1.59GB | 445MB | 547MB | 1.8GB / 2.13GB |
| multi-stage slim (production) | [`Dockerfile`](../Dockerfile) | `node:26-slim` | 267MB | 277MB | 85.8MB | 87.4MB | 355MB / 365MB |
| alpine | [`docker/Dockerfile.alpine`](../docker/Dockerfile.alpine) | `node:26-alpine` | 188MB | 198MB | 63MB | 64.6MB | 252MB / 263MB |
| distroless | [`docker/Dockerfile.distroless`](../docker/Dockerfile.distroless) | `gcr.io/distroless/nodejs26-debian13` | 183MB | 193MB | 60.3MB | 61.9MB | 243MB / 255MB |

Exact bytes (unpacked final / compressed final): naive 1588006912 / 546996529; ordered 1587855360 / 546956620; multi 277229568 / 87370638; alpine 198365184 / 64572268; distroless 192839680 / 61891085. Bases (unpacked / compressed): `node:26` 1337987072 / 444907171; `node:26-slim` 267239424 / 85764794; `node:26-alpine` 188375040 / 62963592; distroless 182849536 / 60282348.

What the numbers say:

- Multi-stage on `-slim` is 1.59GB → 277MB unpacked against the naive image (5.7 times smaller), 547MB → 87.4MB compressed.
- naive and ordered are the same size: the order of `COPY` changes cache reuse, not the content.
- On top of its base, the production image adds 10MB (277MB − 267MB): production `node_modules`, `dist/` and `package.json`. The naive image adds 250MB on top of `node:26`: all dependencies with devDependencies, the source and the build output.
- alpine and distroless are 79MB and 84MB smaller than slim, all of it base image; the app layers are the same 10MB.

### node_modules

From the two install stages of [`Dockerfile`](../Dockerfile), built on their own (`--target deps`, `--target prod-deps`) and measured with `du -sh /app/node_modules`:

| Stage | `npm ci` line (from the build log) | `du -sh node_modules` |
| --- | --- | --- |
| `deps` (`npm ci`, with devDependencies) | `added 299 packages, and audited 300 packages in 4s` | 181M |
| `prod-deps` (`npm ci --omit=dev`) | `added 94 packages, and audited 95 packages in 1s` | 9.5M |

The production `node_modules` layer in `docker history` below is 9.93MB (the history column counts the layer on disk, so it is a little larger than `du`).

### docker history of the production image

`docker history --format '{{.Size}}\t{{.CreatedBy}}' orders-api:multi`, verbatim (the `CREATED BY` column is truncated by Docker):

```text
0B	CMD ["node" "dist/server.js"]
0B	HEALTHCHECK {Test:[CMD-SHELL node -e "fetch(…
0B	EXPOSE 3000/tcp
0B	USER node
12.3kB	COPY --chown=node:node package.json ./ # bui…
41kB	COPY --chown=node:node /app/dist ./dist # bu…
9.93MB	COPY --chown=node:node /app/node_modules ./n…
8.19kB	WORKDIR /app
0B	ENV NODE_ENV=production
0B	CMD ["node"]
0B	ENTRYPOINT ["docker-entrypoint.sh"]
20.5kB	COPY docker-entrypoint.sh /usr/local/bin/ # …
179MB	RUN /bin/sh -c ARCH= OPENSSL_ARCH= && dpkgAr…
0B	ENV NODE_VERSION=26.13.1
69.6kB	RUN /bin/sh -c groupadd --gid 1000 node   &&…
87.7MB	# debian.sh --arch 'amd64' out/ 'trixie' '@1…
```

Read from the bottom: Debian 13 base 87.7MB, Node runtime 179MB, then this repo's layers: `node_modules` 9.93MB, `dist` 41kB, `package.json` 12.3kB (small files are rounded up to whole filesystem blocks in this column). The same script started the image and got `{"status":"ok","uptime":0}` from `GET /healthz`.

### Post says / reality (Docker images)

| Post section | Post says (written for Node 24) | Reality (Node 26, this run) |
| --- | --- | --- |
| Docker 1.1 | 221 packages | `npm ci` adds 299 packages (this repo also carries Vitest, Playwright, MSW, ESLint and TypeScript as devDependencies) |
| Docker 2.2 | naive 1.26GB, multi 275MB; `node:24` 1.13GB, `node:24-slim` 227MB | naive 1.59GB, multi 277MB; `node:26` 1.34GB, `node:26-slim` 267MB |
| Docker 2.2 | `node_modules` 48.5MB production, 132MB with devDependencies; `dist` 1.27kB | 9.93MB layer (9.5M `du`) production, 181M with devDependencies; `dist` 41kB |
| Docker 3 | alpine base 164MB / final 213MB; distroless (`nodejs24-debian12`) 146MB / 195MB | alpine 188MB / 198MB; distroless (`nodejs26-debian13`) 183MB / 193MB |

### Published image

Job `publish` of the same workflow pushes the production image (root `Dockerfile`) to `ghcr.io/jsiovn/cicd-pipeline` with the tags `main` and `sha-<short>` on every push to `main` (and on a manual run on `main`); pull requests only run `sizes`. Package page: [github.com/jsiovn/cicd-pipeline/pkgs/container/cicd-pipeline](https://github.com/jsiovn/cicd-pipeline/pkgs/container/cicd-pipeline). A GHCR package starts private; until it is made public, `docker pull ghcr.io/jsiovn/cicd-pipeline:main` needs a login with access to it.

## Docker lab (build-time)

Measured 2026-11-21 (jobs started 23:42 UTC) by run `44963084906` of [`.github/workflows/docker-lab.yml`](../.github/workflows/docker-lab.yml) on pull request [#7](https://github.com/jsiovn/cicd-pipeline/pull/7), head commit `78481cf` (`ci: keep lab logs out of the build context, strip colour codes, one line per build step`). Each job runs one script in [`docker/lab/`](../docker/lab) (the next commit, `ci: tighten the lab assertions`, only adds checks to the scripts; the outputs are unchanged); everything below is copied from the artifacts it uploaded (`lab-layer-cache`, `lab-build-context`, `lab-base-images`, `lab-secrets`, `lab-dive`). Lines starting with `$` are the commands, `# ----` lines are the script's own headings, `[exit N]` marks a non-zero exit code. Terminal colour codes are stripped.

Runner: `ubuntu-latest`, `Docker server 29.4.2, client 29.4.2`, `github.com/docker/buildx v0.39.0 360040a78d6113dc84e5d4dcdf0f438e1be7a41f`, `Driver: docker`, `BuildKit version: v0.29.0` (the BuildKit built into dockerd; this workflow does not use `setup-buildx-action`), `linux/amd64`, the Node 26 base images of [Docker images](#docker-images).

### Layer cache: one-line change, then rebuild (post 1.1, 1.2)

Job `layer-cache`, [`docker/lab/layer-cache.sh`](../docker/lab/layer-cache.sh). Each Dockerfile is built once to fill the cache, then one line of `src/server.ts` changes and it is rebuilt with `--progress=plain`. The script prints each `[n/m]` step with its final `DONE` / `CACHED` line; `TOTAL` is the wall time of the whole `docker build` command (the full plain logs are in the artifact).

The change:

```text
$ git diff -U0 -- src/server.ts
diff --git a/src/server.ts b/src/server.ts
index 08afdbf..368593d 100644
--- a/src/server.ts
+++ b/src/server.ts
@@ -13 +13 @@ const server = app.listen(port, (error) => {
-  logger.info(`listening on ${port}`);
+  logger.info(`listening on port ${port}`);
```

[`docker/Dockerfile.naive`](../docker/Dockerfile.naive), rebuild:

```text
# ---- naive: rebuild after the one-line change ----
$ docker build --progress=plain -f docker/Dockerfile.naive -t lab:naive .
#4 [1/5] FROM docker.io/library/node:26@sha256:e18c3ccdf7d71619990b0e85639f506e2028a95410999cab24cc373cbd10e0ac
#4 DONE 0.0s
#6 [2/5] WORKDIR /app
#6 CACHED
#7 [3/5] COPY . .
#7 DONE 1.5s
#8 [4/5] RUN npm install
#8 DONE 3.3s
#9 [5/5] RUN npm run build
#9 DONE 2.5s
TOTAL 16.13 s (wall time of docker build)
```

[`docker/Dockerfile.ordered`](../docker/Dockerfile.ordered), rebuild:

```text
# ---- ordered: rebuild after the one-line change ----
$ docker build --progress=plain -f docker/Dockerfile.ordered -t lab:ordered .
#4 [1/6] FROM docker.io/library/node:26@sha256:e18c3ccdf7d71619990b0e85639f506e2028a95410999cab24cc373cbd10e0ac
#4 DONE 0.0s
#6 [2/6] WORKDIR /app
#6 CACHED
#7 [3/6] COPY package.json package-lock.json ./
#7 CACHED
#8 [4/6] RUN npm ci
#8 CACHED
#9 [5/6] COPY . .
#9 DONE 1.3s
#10 [6/6] RUN npm run build
#10 DONE 0.8s
TOTAL 2.66 s (wall time of docker build)
```

The first (cache-filling) builds, for reference:

```text
# ---- naive (docker/Dockerfile.naive): first build, fills the cache ----
$ docker build --progress=plain -f docker/Dockerfile.naive -t lab:naive .
#6 [1/5] FROM docker.io/library/node:26@sha256:e18c3ccdf7d71619990b0e85639f506e2028a95410999cab24cc373cbd10e0ac
#6 DONE 10.8s
#7 [2/5] WORKDIR /app
#7 DONE 8.6s
#8 [3/5] COPY . .
#8 DONE 0.0s
#9 [4/5] RUN npm install
#9 DONE 5.1s
#10 [5/5] RUN npm run build
#10 DONE 1.1s
TOTAL 36.28 s (wall time of docker build)

# ---- ordered (docker/Dockerfile.ordered): first build, fills the cache ----
$ docker build --progress=plain -f docker/Dockerfile.ordered -t lab:ordered .
#4 [1/6] FROM docker.io/library/node:26@sha256:e18c3ccdf7d71619990b0e85639f506e2028a95410999cab24cc373cbd10e0ac
#4 DONE 0.0s
#5 [2/6] WORKDIR /app
#5 CACHED
#7 [3/6] COPY package.json package-lock.json ./
#7 DONE 1.8s
#8 [4/6] RUN npm ci
#8 DONE 4.4s
#9 [5/6] COPY . .
#9 DONE 0.1s
#10 [6/6] RUN npm run build
#10 DONE 0.8s
TOTAL 15.63 s (wall time of docker build)
```

What it shows: the naive rebuild re-runs `RUN npm install` (`DONE 3.3s`) because `COPY . .` above it changed; the ordered rebuild reports `COPY package.json package-lock.json ./` and `RUN npm ci` as `CACHED` and re-runs only `COPY . .` and the build. Wall time 16.13 s against 2.66 s (6.1 times). Most of the naive 16.13 s is not the install step but writing the image: its full log shows `exporting layers 6.8s done` and `unpacking to docker.io/library/lab:naive 1.5s done`, because every layer from `COPY . .` down, including the reinstalled `node_modules`, is new. The ordered rebuild's export takes `0.1s`.

### Build context with and without `.dockerignore` (post 1.3)

Job `build-context`, [`docker/lab/build-context.sh`](../docker/lab/build-context.sh), run after `npm ci` so `node_modules` exists. The context is exported exactly as the builder receives it (`FROM scratch`, `COPY . /`, `-o type=local`) and measured with **`du -sh` of the exported directory: that is the figure to quote**. BuildKit's own `transferring context` line (bytes sent to the builder; the builder cache is pruned before each build, so the transfer starts empty) is recorded next to it.

Note (2026-11-22): since the Next.js app was added, `.dockerignore` ends with two more lines, a comment and `web`. The transcript below predates both the app and these lines.

```text
$ du -sh node_modules
181M	node_modules

# ---- with .dockerignore ----
$ cat .dockerignore
node_modules
dist
.git
.env
.env.*
Dockerfile*
.dockerignore
npm-debug.log

$ docker builder prune -af > /dev/null

$ docker build --progress=plain -f /home/runner/work/_temp/context.Dockerfile -o type=local,dest=/home/runner/work/_temp/context-with-dockerignore . 2>&1 | grep -E 'transferring context|load .dockerignore'
#2 [internal] load .dockerignore
#2 transferring context: 115B done
#3 transferring context: 270.60kB done

$ du -sh /home/runner/work/_temp/context-with-dockerignore
444K	/home/runner/work/_temp/context-with-dockerignore

$ find /home/runner/work/_temp/context-with-dockerignore -maxdepth 1 -mindepth 1 -printf '%f\n' | sort | tr '\n' ' '
.dive-ci .editorconfig .gitattributes .github .gitignore .nvmrc README.md docker docs e2e eslint.config.js examples package-lock.json package.json playwright.config.ts src tsconfig.build.json tsconfig.json vitest.config.ts 

# ---- without .dockerignore ----
$ mv .dockerignore /home/runner/work/_temp/dockerignore.bak

$ docker builder prune -af > /dev/null

$ docker build --progress=plain -f /home/runner/work/_temp/context.Dockerfile -o type=local,dest=/home/runner/work/_temp/context-without-dockerignore . 2>&1 | grep -E 'transferring context|load .dockerignore'
#2 [internal] load .dockerignore
#2 transferring context: 2B done
#3 transferring context: 169.13MB 0.7s done

$ du -sh /home/runner/work/_temp/context-without-dockerignore
182M	/home/runner/work/_temp/context-without-dockerignore

$ find /home/runner/work/_temp/context-without-dockerignore -maxdepth 1 -mindepth 1 -printf '%f\n' | sort | tr '\n' ' '
.dive-ci .editorconfig .git .gitattributes .github .gitignore .nvmrc Dockerfile README.md docker docs e2e eslint.config.js examples node_modules package-lock.json package.json playwright.config.ts src tsconfig.build.json tsconfig.json vitest.config.ts 

$ mv /home/runner/work/_temp/dockerignore.bak .dockerignore
```

| | `du -sh` of the context | BuildKit `transferring context` |
| --- | --- | --- |
| without `.dockerignore` | 182M | 169.13MB |
| with `.dockerignore` | 444K | 270.60kB |

Without the file, `node_modules` (181M), `.git` and `Dockerfile` are in the context; with it, only the source, docs and config files are.

### Base image probes: alpine and distroless (post 3)

Job `base-images`, [`docker/lab/base-images.sh`](../docker/lab/base-images.sh); images built from [`docker/Dockerfile.alpine`](../docker/Dockerfile.alpine) and [`docker/Dockerfile.distroless`](../docker/Dockerfile.distroless).

bcrypt on `node:26-alpine` (the post's snippet):

```text
$ docker run --rm orders-api:alpine node -e "
  const bcrypt = require('bcrypt');
  const h = bcrypt.hashSync('secret', 10);
  console.log('alpine bcrypt ok:', bcrypt.compareSync('secret', h));
"
alpine bcrypt ok: true
```

The prebuilt binaries bcrypt 6.0.0 ships, the Alpine release, and the toolchain (`which` finds none of `python3`, `make`, `g++`):

```text
$ docker run --rm orders-api:alpine sh -c 'ls node_modules/bcrypt/prebuilds/; cat /etc/alpine-release; which python3 make g++ || true'
darwin-arm64
darwin-x64
linux-arm
linux-arm64
linux-x64
win32-arm64
win32-x64
3.24.4
```

Forcing a build from source inside the alpine image (plain `node:26-alpine` underneath, no toolchain added), full output:

```text
$ docker run --rm orders-api:alpine npm rebuild bcrypt --build-from-source
npm warn Unknown cli config "--build-from-source". This will stop working in the next major version of npm.
npm error code 1
npm error path /app/node_modules/bcrypt
npm error command failed
npm error command sh -c node-gyp-build
npm error gyp info it worked if it ends with ok
npm error gyp info using node-gyp@12.4.0
npm error gyp info using node@26.13.1 | linux | x64
npm error gyp ERR! find Python 
npm error gyp ERR! find Python --python was not set on the command line
npm error gyp ERR! find Python Python is not set from environment variable PYTHON
npm error gyp ERR! find Python checking if "python3" can be used
npm error gyp ERR! find Python - executable path is ""
npm error gyp ERR! find Python - "" could not be run
npm error gyp ERR! find Python checking if "python" can be used
npm error gyp ERR! find Python - executable path is ""
npm error gyp ERR! find Python - "" could not be run
npm error gyp ERR! find Python 
npm error gyp ERR! find Python **********************************************************
npm error gyp ERR! find Python You need to install the latest version of Python.
npm error gyp ERR! find Python Node-gyp should be able to find and use Python. If not,
npm error gyp ERR! find Python you can try one of the following options:
npm error gyp ERR! find Python - Use the switch --python="/path/to/pythonexecutable"
npm error gyp ERR! find Python (accepted by both node-gyp and npm)
npm error gyp ERR! find Python - Set the environment variable PYTHON
npm error gyp ERR! find Python For more information consult the documentation at:
npm error gyp ERR! find Python https://github.com/nodejs/node-gyp#installation
npm error gyp ERR! find Python **********************************************************
npm error gyp ERR! find Python 
npm error gyp ERR! configure error 
npm error gyp ERR! stack Error: Could not find any Python installation to use
npm error gyp ERR! stack at PythonFinder.fail (/usr/local/lib/node_modules/npm/node_modules/node-gyp/lib/find-python.js:300:11)
npm error gyp ERR! stack at PythonFinder.findPython (/usr/local/lib/node_modules/npm/node_modules/node-gyp/lib/find-python.js:160:17)
npm error gyp ERR! stack at process.processTicksAndRejections (node:internal/process/task_queues:104:5)
npm error gyp ERR! stack at async configure (/usr/local/lib/node_modules/npm/node_modules/node-gyp/lib/configure.js:27:18)
npm error gyp ERR! stack at async run (/usr/local/lib/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js:81:18)
npm error gyp ERR! System Linux 7.0.0-1016-aws
npm error gyp ERR! command "/usr/local/bin/node" "/usr/local/lib/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js" "rebuild"
npm error gyp ERR! cwd /app/node_modules/bcrypt
npm error gyp ERR! node -v v26.13.1
npm error gyp ERR! node-gyp -v v12.4.0
npm error gyp ERR! $npm_package_name bcrypt
npm error gyp ERR! $npm_package_version 6.0.0
npm error gyp ERR! not ok
npm notice
npm notice New major version of npm available! 11.20.0 -> 12.2.3
npm notice Changelog: https://github.com/npm/cli/releases/tag/v12.2.3
npm notice To update run: npm install -g npm@12.2.3
npm notice
npm error A complete log of this run can be found in: /home/node/.npm/_logs/2026-11-21T23_42_46_139Z-debug-0.log
[exit 1]
```

The shell probe on distroless:

```text
$ docker run --rm --entrypoint sh orders-api:distroless -c 'echo hi'
docker: Error response from daemon: failed to create task for container: failed to create shim task: OCI runtime create failed: runc create failed: unable to start container process: error during container init: exec: "sh": executable file not found in $PATH

Run 'docker run --help' for more information
[exit 127]
```

### Secrets: `ARG` vs secret mount (post 4)

Job `secrets`, [`docker/lab/secrets.sh`](../docker/lab/secrets.sh). The token is fake on purpose, `npm_FAKE_TOKEN_DO_NOT_USE` (25 bytes), and does not match the npm token format.

[`docker/lab/Dockerfile.leaky`](../docker/lab/Dockerfile.leaky) built with `--build-arg NPM_TOKEN=npm_FAKE_TOKEN_DO_NOT_USE`. The build ends with a lint warning:

```text
1 warning found (use docker --debug to expand):
 - SecretsUsedInArgOrEnv: Do not use ARG or ENV instructions for sensitive data (ARG "NPM_TOKEN") (line 5)
```

```text
$ docker history --no-trunc --format '{{.CreatedBy}}' leaky:demo | head -n 3
RUN |1 NPM_TOKEN=npm_FAKE_TOKEN_DO_NOT_USE /bin/sh -c echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" > .npmrc  && npm config get registry  && rm .npmrc # buildkit
WORKDIR /app
ARG NPM_TOKEN=npm_FAKE_TOKEN_DO_NOT_USE

$ docker history --no-trunc --format '{{.CreatedBy}}' leaky:demo | grep -c npm_FAKE_TOKEN_DO_NOT_USE
2
```

[`docker/lab/Dockerfile.safe`](../docker/lab/Dockerfile.safe) built with `--secret id=npm_token,src=<file>`:

```text
$ docker history --no-trunc --format '{{.CreatedBy}}' safe:demo | head -n 3
RUN /bin/sh -c echo "//registry.npmjs.org/:_authToken=$(cat /run/secrets/npm_token)" > .npmrc  && npm config get registry  && rm .npmrc # buildkit
WORKDIR /app
CMD ["node"]

$ docker history --no-trunc --format '{{.CreatedBy}}' safe:demo | grep -c npm_FAKE_TOKEN_DO_NOT_USE
0
[exit 1]

$ docker image inspect safe:demo | grep -c npm_FAKE_TOKEN_DO_NOT_USE
0
[exit 1]

$ docker run --rm safe:demo sh -c 'ls -A /app; ls /run/secrets 2>&1'
ls: cannot access '/run/secrets': No such file or directory
[exit 2]
```

The token is in the leaky image's history twice (the `ARG` line and the `RUN |1 NPM_TOKEN=…` line) and nowhere in the safe image: `grep -c` finds 0 lines in its history and 0 in `docker image inspect`; `/app` is empty (`.npmrc` was removed) and `/run/secrets` does not exist in the image.

#### Is `# syntax=docker/dockerfile:1` required for `RUN --mount`?

The same two-line Dockerfile built with and without the directive. `required=true` makes the build fail if the secret is not mounted, and the `RUN` prints the size of what it read:

```text
$ cat /home/runner/work/_temp/Dockerfile.with-directive
# syntax=docker/dockerfile:1
FROM node:26-slim
RUN --mount=type=secret,id=npm_token,required=true sh -c 'echo "secret mounted: $(wc -c < /run/secrets/npm_token) bytes"'

$ docker build --no-cache --progress=plain --secret id=npm_token,src=/home/runner/work/_temp/npm_token.txt -f /home/runner/work/_temp/Dockerfile.with-directive -t mount:with-directive docker/lab > /home/runner/work/_temp/lab-out/mount-with-directive.log 2>&1; status=$?; grep -E '^#[0-9]+ (\[|resolve image config|docker-image://)|secret mounted: [0-9]|ERROR' /home/runner/work/_temp/lab-out/mount-with-directive.log; exit $status
#1 [internal] load build definition from Dockerfile.with-directive
#2 resolve image config for docker-image://docker.io/docker/dockerfile:1
#3 docker-image://docker.io/docker/dockerfile:1@sha256:572cebbc2b15e6f84c077742952674889cb63cd5e9b80abdffcbe587b6f19183
#4 [internal] load metadata for docker.io/library/node:26-slim
#5 [internal] load .dockerignore
#6 [stage-0 1/2] FROM docker.io/library/node:26-slim@sha256:e6bedef217677b276c591795e169840edd9096dbf13f29df8ef8d1856b8820bc
#7 [stage-0 2/2] RUN --mount=type=secret,id=npm_token,required=true sh -c 'echo "secret mounted: $(wc -c < /run/secrets/npm_token) bytes"'
#7 0.148 secret mounted: 25 bytes

$ cat /home/runner/work/_temp/Dockerfile.without-directive
FROM node:26-slim
RUN --mount=type=secret,id=npm_token,required=true sh -c 'echo "secret mounted: $(wc -c < /run/secrets/npm_token) bytes"'

$ docker build --no-cache --progress=plain --secret id=npm_token,src=/home/runner/work/_temp/npm_token.txt -f /home/runner/work/_temp/Dockerfile.without-directive -t mount:without-directive docker/lab > /home/runner/work/_temp/lab-out/mount-without-directive.log 2>&1; status=$?; grep -E '^#[0-9]+ (\[|resolve image config|docker-image://)|secret mounted: [0-9]|ERROR' /home/runner/work/_temp/lab-out/mount-without-directive.log; exit $status
#1 [internal] load build definition from Dockerfile.without-directive
#2 [internal] load metadata for docker.io/library/node:26-slim
#3 [internal] load .dockerignore
#4 [stage-0 1/2] FROM docker.io/library/node:26-slim@sha256:e6bedef217677b276c591795e169840edd9096dbf13f29df8ef8d1856b8820bc
#5 [stage-0 2/2] RUN --mount=type=secret,id=npm_token,required=true sh -c 'echo "secret mounted: $(wc -c < /run/secrets/npm_token) bytes"'
#5 0.128 secret mounted: 25 bytes
```

Both builds succeed and both read the 25-byte secret. The build with the directive is also the positive control for `safe:demo` (same frontend, same token file): the secret mount does deliver the token, so its absence from `safe:demo` is not an unmounted secret. With the directive, BuildKit first pulls the `docker/dockerfile:1` frontend image (`resolve image config for docker-image://docker.io/docker/dockerfile:1`); without it, the Dockerfile frontend built into BuildKit v0.29.0 parses the file and handles `RUN --mount=type=secret` itself. On this Docker the directive is **recommended, not required**: it pins the Dockerfile syntax to the latest `1.x` frontend instead of whatever the local BuildKit bundles.

### dive in CI mode (post 7)

Job `dive`, [`docker/lab/dive.sh`](../docker/lab/dive.sh): `docker.io/wagoodman/dive:v0.13.1` (checked by hand on 2026-11-22, not by the job: the latest dive release, published 2025-03-29, also as `ghcr.io/wagoodman/dive`) on the production image built from [`Dockerfile`](../Dockerfile) as `orders-api:multi`, rules in [`.dive-ci`](../.dive-ci) (`lowestEfficiency: 0.95`, `highestWastedBytes: 20MB`, `highestUserWastedPercent: 0.10`; the job fails when a rule fails). The post's command, reading the image through the Docker socket, works against Docker 29 (the script falls back to a `docker save` archive only if it does not):

```text
$ docker run --rm -e CI=true -v /var/run/docker.sock:/var/run/docker.sock -v "$PWD/.dive-ci:/.dive-ci:ro" docker.io/wagoodman/dive:v0.13.1 orders-api:multi --ci-config /.dive-ci
  Using CI config: /.dive-ci
Image Source: docker://orders-api:multi
Extracting image from docker-engine... (this can take a while for large images)
Analyzing image...
  efficiency: 99.3056 %
  wastedBytes: 3503492 bytes (3.5 MB)
  userWastedPercent: 1.9817 %
Inefficient Files:
Count  Wasted Space  File Path
    2        1.6 MB  /var/cache/debconf/templates.dat-old
    2        1.6 MB  /var/cache/debconf/templates.dat
    2        142 kB  /var/lib/dpkg/status-old
    2        142 kB  /var/lib/dpkg/status
    2         21 kB  /var/cache/debconf/config.dat-old
    2        9.8 kB  /var/log/apt/eipp.log.xz
    2        9.0 kB  /var/lib/apt/extended_states
    2        8.7 kB  /var/cache/debconf/config.dat
    2        8.3 kB  /etc/ld.so.cache
    2        1.7 kB  /etc/passwd
    2        1.7 kB  /etc/passwd-
    2         974 B  /etc/shadow
    2         881 B  /etc/group
    2         868 B  /etc/group-
    2         737 B  /etc/gshadow
    2         436 B  /var/lib/dpkg/diversions-old
    2         400 B  /var/lib/dpkg/diversions
    2          18 B  /etc/subuid
    2          18 B  /etc/subgid
    2           0 B  /var/lib/dpkg/lock
    2           0 B  /var/lib/dpkg/triggers/Lock
    2           0 B  /var/lib/dpkg/triggers/Unincorp
Results:
  PASS: highestUserWastedPercent
  PASS: highestWastedBytes
  PASS: lowestEfficiency
Result:PASS [Total:3] [Passed:3] [Failed:0] [Warn:0] [Skipped:0]
```

Every inefficient file is in the layers of the base image `node:26-slim` (`apt`/`dpkg`/`debconf` state and `/etc/passwd`-style files written by one base layer and rewritten by a later one); none is under `/app`, so none comes from this repo's layers.

### Post says / reality (Docker lab)

| Post section | Post says (written for Node 24) | Reality (Node 26, this run) |
| --- | --- | --- |
| Docker 1.1 | naive rebuild: `RUN npm install` `DONE 4.0s`, `RUN npm run build` `DONE 1.1s`, `TOTAL 6.60 s` | `RUN npm install` re-runs, as the post says: `DONE 3.3s`, build `DONE 2.5s`, `TOTAL 16.13 s`. Most of the total is exporting and unpacking the new layers (`exporting layers 6.8s`, `unpacking … 1.5s`), which the post's step list does not show |
| Docker 1.1 (note) | 221 packages | `npm ci` installs 299 packages in this repo (see [Docker images](#docker-images)) |
| Docker 1.2 | ordered rebuild: manifests and `RUN npm ci` `CACHED`, `TOTAL 1.42 s`, 4.6 times faster | `CACHED`, as the post says; `TOTAL 2.66 s`; 16.13 s → 2.66 s = 6.1 times |
| Docker 1.3 | `du -sh .`: 40M without `.dockerignore`, 68K with it | `du -sh` of the exported context: 182M without, 444K with (BuildKit `transferring context`: 169.13MB vs 270.60kB). This repo carries Vitest, Playwright, MSW, ESLint and TypeScript as devDependencies, so `node_modules` alone is 181M |
| Docker 3 | `alpine bcrypt ok: true` | identical. bcrypt 6.0.0 ships its binaries in `prebuilds/` (folders listed above, `linux-x64` among them) and loads on Alpine 3.24.4 without a toolchain |
| Docker 3 | `npm rebuild bcrypt --build-from-source` fails with `gyp ERR! find Python` … `gyp ERR! not ok` (4 lines) | fails, exit 1; the post's four lines are all in the real output (between them node-gyp prints more `find Python` lines and a stack trace). New: npm 11.20.0 first warns `npm warn Unknown cli config "--build-from-source". This will stop working in the next major version of npm.`; the flag still reaches node-gyp today |
| Docker 3 | distroless: `docker: Error response from daemon: failed to create task for container:` / `exec: "sh": executable file not found in $PATH` | same error with a longer prefix on Docker 29: `failed to create task for container: failed to create shim task: OCI runtime create failed: runc create failed: unable to start container process: error during container init: exec: "sh": executable file not found in $PATH`, exit 127 |
| Docker 4.1 | `docker history` shows `RUN \|1 NPM_TOKEN=<token> /bin/sh -c …` and `ARG NPM_TOKEN=<token>` | identical, with the fake token. New: Docker 29 prints the build warning `SecretsUsedInArgOrEnv: Do not use ARG or ENV instructions for sensitive data (ARG "NPM_TOKEN")`, and builds the image anyway |
| Docker 4.2 | history shows only `$(cat /run/secrets/npm_token)`; a grep for the token finds nothing | identical |
| Docker 4.2 | the `# syntax=docker/dockerfile:1` line is required ("bắt buộc") for `--mount` | **not required** on Docker 29.4.2 / BuildKit v0.29.0: the same `RUN --mount=type=secret,required=true` builds and reads the secret without it. Recommended: it pins the latest 1.x Dockerfile syntax |
| Docker 7 | `wagoodman/dive:latest`; `efficiency: 98.7044 %`, `wastedBytes: 5275656 bytes (5.3 MB)`, `userWastedPercent: 2.6348 %`, `Result:PASS [Total:3] [Passed:2] [Failed:0] [Warn:0] [Skipped:1]` | `wagoodman/dive:v0.13.1` (checked by hand on 2026-11-22: Docker Hub lists the same digest, `sha256:f1886e6c…`, for `latest` and `v0.13.1`); `efficiency: 99.3056 %`, `wastedBytes: 3503492 bytes (3.5 MB)`, `userWastedPercent: 1.9817 %`, `Result:PASS [Total:3] [Passed:3] [Failed:0] [Warn:0] [Skipped:0]`. Three rules pass because `.dive-ci` sets all three |

## Docker lab (runtime)

Measured 2026-11-22 (jobs started between 00:08:57 and 00:09:03 UTC) by run `44965193005` of [`.github/workflows/docker-lab.yml`](../.github/workflows/docker-lab.yml) on pull request [#8](https://github.com/jsiovn/cicd-pipeline/pull/8), head commit `d4872a6` (`ci: Docker lab, runtime experiments …`). Same reporting as [Docker lab (build-time)](#docker-lab-build-time): each job runs one script in [`docker/lab/`](../docker/lab) and everything below is copied from the artifacts it uploaded (`lab-compose-up`, `lab-volume-trap`, `lab-non-root`, `lab-healthcheck`, `lab-graceful-shutdown`). Lines starting with `$` are the commands, `#` lines are the script's own notes, `OK:` lines are its assertions, `[exit N]` marks a non-zero exit code. The versions block every script prints first is identical in all five jobs, so it is given once here instead of five times; the only other cut is the layer pull progress of `postgres:19-alpine`, marked where it was.

Runner: `ubuntu-latest`, `Docker server 29.4.2, client 29.4.2`, `Docker Compose version v5.1.3`, `BuildKit version: v0.29.0`. Images: the production image built from [`Dockerfile`](../Dockerfile) (`node:26-slim`, `CMD ["node", "dist/server.js"]`), the dev image built from [`docker/Dockerfile.dev`](../docker/Dockerfile.dev) (`node:26-slim`, Node `v26.13.1`, npm `11.20.0`), `postgres:19-alpine` (`postgres (PostgreSQL) 19.0`, `PGDATA=/var/lib/postgresql/19/docker`, `VOLUME /var/lib/postgresql`).

### Compose dev stack (post 6)

Job `compose-up`, [`docker/lab/compose-up.sh`](../docker/lab/compose-up.sh), on [`compose.yaml`](../compose.yaml). The API's `/healthz` runs `select 1` against Postgres when `DATABASE_URL` is set (only the compose stack sets it) and then adds `"db":"ok"`; without `DATABASE_URL` it answers `{"status":"ok","uptime":<seconds>}` as before. Postgres 18 and later keep their data in `/var/lib/postgresql/<major>/docker` and declare `VOLUME /var/lib/postgresql`, so `compose.yaml` mounts the named volume there; the last part of the job starts `postgres:19-alpine` with the post's mount path, `/var/lib/postgresql/data`, instead.

```text
$ docker compose version
Docker Compose version v5.1.3

$ docker compose config --images
cicd-pipeline-api
postgres:19-alpine

$ docker compose build api > /home/runner/work/_temp/lab-out/compose-build.log 2>&1

$ docker compose up -d --wait --wait-timeout 180
 Image postgres:19-alpine Pulling 
[… 57 lines of layer pull progress omitted …]
 Image postgres:19-alpine Pulled 
 Network cicd-pipeline_default Creating 
 Network cicd-pipeline_default Created 
 Volume cicd-pipeline_pgdata Creating 
 Volume cicd-pipeline_pgdata Created 
 Container cicd-pipeline-db-1 Creating 
 Container cicd-pipeline-db-1 Created 
 Container cicd-pipeline-api-1 Creating 
 Container cicd-pipeline-api-1 Created 
 Container cicd-pipeline-db-1 Starting 
 Container cicd-pipeline-db-1 Started 
 Container cicd-pipeline-db-1 Waiting 
 Container cicd-pipeline-db-1 Healthy 
 Container cicd-pipeline-api-1 Starting 
 Container cicd-pipeline-api-1 Started 
 Container cicd-pipeline-api-1 Waiting 
 Container cicd-pipeline-db-1 Waiting 
 Container cicd-pipeline-api-1 Healthy 
 Container cicd-pipeline-db-1 Healthy 

$ docker compose ps --format 'table {{.Name}}\t{{.Image}}\t{{.Status}}'
NAME                  IMAGE                STATUS
cicd-pipeline-api-1   cicd-pipeline-api    Up Less than a second
cicd-pipeline-db-1    postgres:19-alpine   Up 6 seconds (healthy)

# right after --wait returns (api has no healthcheck, so --wait only means 'running'):
$ curl -s localhost:3000/healthz
{"status":"ok","uptime":0,"db":"ok"}

# poll /healthz once a second until it answers with the database (at most 60 s)
# answered with db ok after 0.01 s of polling
$ curl -s localhost:3000/healthz
{"status":"ok","uptime":0,"db":"ok"}

OK: /healthz answered through compose and the API reached Postgres at host db
$ docker compose logs --no-log-prefix api
{"level":30,"time":1795306182671,"pid":31,"hostname":"a0f72c7ddffd","msg":"listening on 3000"}

$ docker compose exec api node --version
v26.13.1

$ docker compose exec api npm --version
11.20.0

$ docker compose exec db postgres --version
postgres (PostgreSQL) 19.0

$ docker compose exec db sh -c 'echo PGDATA=$PGDATA'
PGDATA=/var/lib/postgresql/19/docker

$ docker image inspect --format '{{json .Config.Volumes}}' postgres:19-alpine
{"/var/lib/postgresql":{}}

$ docker compose down -v
 Container cicd-pipeline-api-1 Stopping 
 Container cicd-pipeline-api-1 Stopped 
 Container cicd-pipeline-api-1 Removing 
 Container cicd-pipeline-api-1 Removed 
 Container cicd-pipeline-db-1 Stopping 
 Container cicd-pipeline-db-1 Stopped 
 Container cicd-pipeline-db-1 Removing 
 Container cicd-pipeline-db-1 Removed 
 Network cicd-pipeline_default Removing 
 Volume cicd-pipeline_pgdata Removing 
 Network cicd-pipeline_default Removed 
 Volume cicd-pipeline_pgdata Removed 

# ---- the post's volume path, /var/lib/postgresql/data, on postgres:19-alpine ----
$ docker run -d --name pgprobe -e POSTGRES_PASSWORD=probe -v pgprobe:/var/lib/postgresql/data postgres:19-alpine > /dev/null

$ docker inspect --format 'running={{.State.Running}} exit code={{.State.ExitCode}}' pgprobe
running=false exit code=1

$ docker logs pgprobe 2>&1 | tail -n 25
Error: in 18+, these Docker images are configured to store database data in a
       format which is compatible with "pg_ctlcluster" (specifically, using
       major-version-specific directory names).  This better reflects how
       PostgreSQL itself works, and how upgrades are to be performed.

       See also https://github.com/docker-library/postgres/pull/1259

       Counter to that, there appears to be PostgreSQL data in:
         /var/lib/postgresql/data (unused mount/volume)

       This is usually the result of upgrading the Docker image without
       upgrading the underlying database using "pg_upgrade" (which requires both
       versions).

       The suggested container configuration for 18+ is to place a single mount
       at /var/lib/postgresql which will then place PostgreSQL data in a
       subdirectory, allowing usage of "pg_upgrade --link" without mount point
       boundary issues.

       See https://github.com/docker-library/postgres/issues/37 for a (long)
       discussion around this process, and suggestions for how to do so.

OK: postgres:19-alpine refuses to start with the volume at /var/lib/postgresql/data (running=false exit code=1)
```

### Volume trap: `node_modules` behind the bind mount (post 6.1)

Job `volume-trap`, [`docker/lab/volume-trap.sh`](../docker/lab/volume-trap.sh). The checkout has no `node_modules` (the job runs no `npm ci`); the two `docker run` commands are the post's, unchanged.

```text
$ ls -A
.dive-ci
.dockerignore
.editorconfig
.git
.gitattributes
.github
.gitignore
.nvmrc
Dockerfile
README.md
compose.yaml
docker
docs
e2e
eslint.config.js
examples
package-lock.json
package.json
playwright.config.ts
src
tsconfig.build.json
tsconfig.json
vitest.config.ts

$ docker build -q -f docker/Dockerfile.dev -t orders-api:dev .
sha256:e156ee389f3ba00784e0e5a35541457e86f6a67fbc9e2836ba63d18f406015bd

$ docker run --rm orders-api:dev node -e "console.log('in the image, no mounts:', require('fs').readdirSync('/app/node_modules').length, 'entries')"
in the image, no mounts: 241 entries

# ---- only the bind mount ----
$ docker run --rm -v $(pwd):/app orders-api:dev \
    node -e "const fs=require('fs'); console.log(fs.existsSync('/app/node_modules') ? 'present' : 'GONE')"
GONE

OK: with only -v $(pwd):/app, node_modules is missing inside the container
# ---- bind mount + anonymous volume on /app/node_modules ----
$ docker run --rm -v $(pwd):/app -v /app/node_modules orders-api:dev \
    node -e "console.log('node_modules entries:', require('fs').readdirSync('/app/node_modules').length)"
node_modules entries: 241

OK: with -v /app/node_modules, the image's node_modules is visible again
# the anonymous volume left an empty mountpoint in the checkout:
$ ls -ld node_modules && ls -A node_modules | wc -l
drwxr-xr-x 2 root root 4096 Nov 22 00:09 node_modules
0
```

### Non-root (post 8.1)

Job `non-root`, [`docker/lab/non-root.sh`](../docker/lab/non-root.sh).

```text
$ docker build -q -t orders-api .
sha256:35307d845bc6156acb61f85d73bc89cd9ec799971174a6d49c8688368a759f2b

$ docker image inspect --format 'image Config.User: {{.Config.User}}' orders-api
image Config.User: node

$ docker run -d --name orders-api orders-api
07ccfc97675a9dae6e11c93102ccc94ae8d48e6d0fb73d253dc235a62b3d0f6b

$ docker exec orders-api whoami
node

$ docker exec orders-api id
uid=1000(node) gid=1000(node) groups=1000(node)

$ docker exec orders-api ls -l /app
total 12
drwxr-xr-x  4 node node 4096 Nov 22 00:09 dist
drwxr-xr-x 97 node node 4096 Nov 22 00:09 node_modules
-rw-r--r--  1 node node 1492 Nov 22 00:08 package.json

# for contrast, the base image without USER:
$ docker run --rm --entrypoint whoami node:26-slim
Unable to find image 'node:26-slim' locally
26-slim: Pulling from library/node
Digest: sha256:e6bedef217677b276c591795e169840edd9096dbf13f29df8ef8d1856b8820bc
Status: Downloaded newer image for node:26-slim
root

OK: the production container runs as node
```

### `HEALTHCHECK`: time to healthy (post 8.2)

Job `healthcheck`, [`docker/lab/healthcheck.sh`](../docker/lab/healthcheck.sh). The production image's `HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3`; the script polls the status every 0.5 s.

```text
$ docker build -q -t orders-api .
sha256:431e6b765811124bc8ffe21fc92832655d6b1c8465eb5c4a01e651a65807cf24

$ docker image inspect --format '{{json .Config.Healthcheck}}' orders-api
{"Test":["CMD-SHELL","node -e \"fetch('http://127.0.0.1:3000/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))\""],"Interval":30000000000,"Timeout":3000000000,"StartPeriod":5000000000,"Retries":3}

$ docker run -d --name orders-api -p 3000:3000 orders-api
7bf8c51db1c25bf69d6fab357c5f277ceb27cc08e72ccf47f5aeb15040ca7c2e

# poll .State.Health.Status every 0.5 s (at most 90 s), print each change
# t+0.02 s after docker run returned: starting
# t+5.17 s after docker run returned: healthy
$ docker inspect --format='{{.State.Health.Status}}' orders-api
healthy

$ docker inspect --format '{{.State.StartedAt}}' orders-api
2026-11-22T00:09:07.72495322Z

$ docker inspect --format '{{json .State.Health.Log}}' orders-api | jq -c '.[] | {Start, End, ExitCode, Output}'
{"Start":"2026-11-22T00:09:13.020088961Z","End":"2026-11-22T00:09:13.104218362Z","ExitCode":0,"Output":""}

$ docker ps --format '{{.Names}}  {{.Status}}'
orders-api  Up 5 seconds (healthy)

OK: the container reached healthy
```

The first probe ran 5.3 s after the container started (`StartedAt` 00:09:07.72, first probe `Start` 00:09:13.02), not after the 30 s `--interval`: since Docker Engine 25, probes during the start period run every `--start-interval`, which defaults to 5 s when the Dockerfile does not set it. One passing probe is enough for `healthy`.

### Graceful shutdown: `node` vs `npm start` (post 8.3)

Job `graceful-shutdown`, [`docker/lab/graceful-shutdown.sh`](../docker/lab/graceful-shutdown.sh). Both containers are stopped only after they have logged `listening on 3000` (the `SIGTERM` handler is registered before that line). The second container is the same image with `npm start` as its command, so npm runs `node dist/server.js`.

```text
$ docker build -q -t orders-api .
sha256:c44bbaba5973b5dd5266d3c8fac0123ad3ecbfe0f298f83947ead397426baf90

$ docker run --rm orders-api npm --version
11.20.0

$ docker image inspect --format '{{json .Config.Cmd}}' orders-api
["node","dist/server.js"]

# ---- CMD ["node", "dist/server.js"] (the image as built) ----
$ docker run -d --name orders-api orders-api
0a2cd0df81978df31b6a6479c256af5505776678dbd6a1eb08531d3fb481ad09

$ docker top orders-api -o pid,ppid,args
PID                 PPID                COMMAND
3232                3208                node dist/server.js

$ docker stop orders-api
orders-api

# docker stop took 0.11 s
$ docker inspect --format '{{.State.ExitCode}}' orders-api
0

$ docker logs orders-api
{"level":30,"time":1795306152582,"pid":1,"hostname":"0a2cd0df8197","msg":"listening on 3000"}
{"level":30,"time":1795306153566,"pid":1,"hostname":"0a2cd0df8197","msg":"SIGTERM received, draining connections"}

OK: node as PID 1: both log lines, exit 0, docker stop took 0.11 s
# ---- the same image started with npm start ----
$ docker run -d --name orders-npm orders-api npm start
5922c457004e1095f0c7ff09b6ead7595ee510edff7b204c5990e47f9f62d325

$ docker top orders-npm -o pid,ppid,args
PID                 PPID                COMMAND
3454                3429                npm start
3506                3454                sh -c node dist/server.js
3507                3506                node dist/server.js

$ docker stop orders-npm
orders-npm

# docker stop took 0.68 s
$ docker inspect --format '{{.State.ExitCode}}' orders-npm
1

$ docker logs orders-npm

> cicd-pipeline@1.0.0 start
> node dist/server.js

{"level":30,"time":1795306154309,"pid":20,"hostname":"5922c457004e","msg":"listening on 3000"}
npm error path /app
npm error command failed
npm error signal SIGTERM
npm error command sh -c node dist/server.js
npm notice
npm notice New major version of npm available! 11.20.0 -> 12.2.3
npm notice Changelog: https://github.com/npm/cli/releases/tag/v12.2.3
npm notice To update run: npm install -g npm@12.2.3
npm notice
npm error A complete log of this run can be found in: /home/node/.npm/_logs/2026-11-22T00_09_13_960Z-debug-0.log

OK: npm start: npm exited on SIGTERM without the drain line (exit 1, 0.68 s): not graceful
```

With `npm start` the process tree is `npm start` (PID 1 in the container) → `sh -c node dist/server.js` → `node dist/server.js`. npm 11.20.0 relays the `SIGTERM` to its child, the `sh -c` wrapper, and reports it killed by that signal (`npm error signal SIGTERM`, `npm error command sh -c node dist/server.js`); Node never logs its drain line, npm exits 1, and Node ends with the container without having run its handler. **The post's claim holds** in effect: with `npm start` the graceful shutdown of 8.3 never runs (no `SIGTERM received` line). The mechanism is not the one the post's wording suggests: the signal is not swallowed until the 10-second kill (exit 137); the container stops in 0.68 s with exit code 1, and the signal stops at the shell npm runs the script with.

### Post says / reality (Docker lab, runtime)

| Post section | Post says (written for Node 24, Postgres 16) | Reality (Node 26, Postgres 19, this run) |
| --- | --- | --- |
| Docker 6 | `Dockerfile.dev` on `node:24-slim`, `CMD ["npx", "tsx", "watch", "src/server.ts"]` | same file on `node:26-slim` ([`docker/Dockerfile.dev`](../docker/Dockerfile.dev)); `tsx watch` logs `listening on 3000` |
| Docker 6 | `postgres:16-alpine` with `pgdata:/var/lib/postgresql/data` | the current major is 19 (`postgres:19-alpine`, PostgreSQL 19.0). On 18+ that mount path **does not work**: the container exits 1 with `Error: in 18+, these Docker images are configured to store database data in a format which is compatible with "pg_ctlcluster"` … `/var/lib/postgresql/data (unused mount/volume)`. The image's own advice, used in [`compose.yaml`](../compose.yaml): one mount at `/var/lib/postgresql`. On `postgres:16-alpine` the post's path is still the right one |
| Docker 6 | `docker compose up -d` prints `Waiting`, `Healthy`, `Starting`, `Started` for `ordersdemo-*`; then `curl -s localhost:3000/healthz` → `{"status":"ok","uptime":13}` | `docker compose up -d --wait` prints the same four lines for `db`/`api` (project `cicd-pipeline`, named after the directory), and `api` is started only once `db` is `Healthy`. With `--wait` it also prints `api-1 Healthy` although `api` has no healthcheck (for `--wait` that means running). `/healthz` → `{"status":"ok","uptime":0,"db":"ok"}` on the first request; `db` is this repo's addition, the proof that the API reached Postgres at host `db` |
| Docker 6.1 | bind mount only → `GONE`; with `-v /app/node_modules` → `node_modules entries: 223` | `GONE`, then `node_modules entries: 241` (this repo's dependency tree; the same count as the image without mounts). Side effect the post does not mention: the anonymous volume leaves an empty, root-owned `node_modules` directory in the host checkout |
| Docker 8.1 | `docker exec orders-api whoami` → `node` | identical; `id` → `uid=1000(node) gid=1000(node) groups=1000(node)`, `/app` owned by `node:node`; the base image without `USER` runs as `root` |
| Docker 8.2 | `healthy` "after about thirty seconds" (`sau khoảng ba mươi giây`) | `healthy` after **5.17 s**: the first probe runs at the 5 s default `--start-interval` of the start period (Docker Engine 25+), not after the 30 s `--interval` |
| Docker 8.3 | `docker stop` logs `listening on 3000` and `SIGTERM received, draining connections` | identical two lines; exit code 0; `docker stop` took 0.11 s, far below the 10 s timeout |
| Docker 8.3 | `npm start` adds a process that does not forward signals to Node, so the shutdown handler never runs | **holds**: no `SIGTERM received` line. But npm does relay `SIGTERM` to its child, the `sh -c` wrapper, and Node never gets to log; npm exits 1 after 0.68 s (`npm error signal SIGTERM`) instead of hanging until the 10 s kill |

## Next.js app

The app in [`web/`](../web), built by [`.github/workflows/web.yml`](../.github/workflows/web.yml) (CI/CD post 8.2, Deploy post 4.2, the app the Docker post's section 5 containerises).

### Versions

| What | Version |
| --- | --- |
| Next.js | 16.4.6 (`next` in [`web/package.json`](../web/package.json), the `latest` dist-tag on 2026-11-22) |
| React, React DOM | 19.3.0 (what `create-next-app@16.4.6` pins) |
| TypeScript, ESLint | `^5`, `^9` + `eslint-config-next` 16.4.6 (the create-next-app 16.4.6 template; the API at the root keeps TypeScript 6 and ESLint 10) |
| Node.js in CI | `node-version: 26`, as the rest of the repo (setup-node resolved it to 26.13.1 on 2026-11-22); Next.js 16.4.6 declares `engines.node >= 20.9.0`, so no extra pin |

### `next build` in CI

Measured 2026-11-22 on commit [`d80e773`](https://github.com/jsiovn/cicd-pipeline/commit/d80e7736a5ebd76623f78d01bb44e2bab962fd12) (`fix: pin the Next.js tracing root to web/`), the `pull_request` run of [Actions › Web](https://github.com/jsiovn/cicd-pipeline/actions/workflows/web.yml) for pull request [#9](https://github.com/jsiovn/cicd-pipeline/pull/9), job `build` on `ubuntu-latest`, Node 26.13.1, first run of the app (no `.next/cache`). Step durations from `gh run view <run> --json jobs` (`completedAt - startedAt`, whole seconds as the API reports them).

| Step | Duration |
| --- | --- |
| `npm ci` | 9 s |
| `npm run lint` | 2 s |
| `npm run typecheck` | 1 s |
| `npm run build (timed)` | 7 s |
| whole job `build` | 30 s |

Log of the build step, verbatim:

```text
> web@0.1.0 build
> next build

▲ Next.js 16.4.6 (Turbopack)
✓ Running next.config.ts took 35ms
⚠ No build cache found. Please configure build caching for faster rebuilds. Read more: https://nextjs.org/docs/messages/no-cache

  Creating an optimized production build ...
✓ Compiled successfully in 3.7s
  Running TypeScript ...
  Finished TypeScript in 1499ms ...
  Collecting page data using 3 workers ...
  Generating static pages using 3 workers (0/4) ...
  Generating static pages using 3 workers (1/4) 
  Generating static pages using 3 workers (2/4) 
  Generating static pages using 3 workers (3/4) 
✓ Generating static pages using 3 workers (4/4) in 135ms
  Finalizing page optimization ...

Route (app)
┌ ○ /
├ ○ /_not-found
└ ƒ /api/counter


○  (Static)   prerendered as static content
ƒ  (Dynamic)  server-rendered on demand
```

The next step, `test -f .next/standalone/server.js`, passed. On the same pull request `CI` (`ci-ok`), `Image` and `Docker lab` stayed green with `web/` excluded from their toolchain.

### `next build` locally

Measured 2026-11-22 in a local terminal (Node 22.23.1, before the first push; the output is the same with `outputFileTracingRoot`). Excerpt: the telemetry notice and a warning about the directory above this checkout are left out; every other line is verbatim.

```text
$ npm run build
▲ Next.js 16.4.6 (Turbopack)
  Creating an optimized production build ...
✓ Compiled successfully in 1975ms
  Running TypeScript ...
  Finished TypeScript in 1196ms ...
✓ Generating static pages using 5 workers (4/4) in 599ms

Route (app)
┌ ○ /
├ ○ /_not-found
└ ƒ /api/counter

○  (Static)   prerendered as static content
ƒ  (Dynamic)  server-rendered on demand

$ ls .next/standalone/server.js
.next/standalone/server.js

$ PORT=3417 node .next/standalone/server.js &
$ curl -s localhost:3417/api/counter
{"count":1,"processStartedAt":"2026-11-22T00:36:01.679Z"}
$ curl -s localhost:3417/api/counter
{"count":2,"processStartedAt":"2026-11-22T00:36:01.679Z"}
$ curl -s -o /dev/null -w "HTTP %{http_code}\n" localhost:3417/
HTTP 200
$ curl -s -o /dev/null -w "HTTP %{http_code}\n" localhost:3417/robots.txt
HTTP 404
```

`/api/counter` is `ƒ` (dynamic): without `cacheComponents` in `next.config.ts` a `GET` route handler is not prerendered. On one long-running process the count only goes up and `processStartedAt` stays the same; that is exactly why it looks right until it runs on serverless. `robots.txt` is a 404 because `.next/standalone` does not contain `public/` (nor `.next/static/`): the Docker post's section 5 copies both next to it.

### Post says / reality (Next.js app)

| Post section | Post says | Reality (this repo) |
| --- | --- | --- |
| Docker 5 | `next.config.ts` with only `output: "standalone"`; `next build` puts `server.js` in `.next/standalone` | true for an app at the root of its repository. Here `web/` sits next to the API's `package-lock.json`, and the first CI run of this app failed `test -f .next/standalone/server.js`: `next build` warned `Next.js inferred your workspace root, but it may not be correct. We detected multiple lockfiles and selected the directory of /home/runner/work/cicd-pipeline/cicd-pipeline/package-lock.json as the root directory.` and wrote `.next/standalone/web/server.js`. One more line in [`web/next.config.ts`](../web/next.config.ts), `outputFileTracingRoot: __dirname`, brings it back to `.next/standalone/server.js` and silences the warning |
| Docker 5 | an app on Next.js 16.2.10 | Next.js 16.4.6 |

## Deploy

GitHub Pages site and the approval-gated promotion (CI/CD post 5.2, 6.1, 6.2, 7.1; Deploy post 3, 6). Set up 2026-11-22 through the REST API: `gh api -X POST repos/jsiovn/cicd-pipeline/pages -f build_type=workflow`, `gh api -X PUT repos/jsiovn/cicd-pipeline/environments/production --input <file>` (body `{"prevent_self_review": false, "reviewers": [{"type": "User", "id": <owner id>}]}`), `gh api -X PUT repos/jsiovn/cicd-pipeline/environments/vercel` (no body).

### GitHub Pages (`pages.yml`)

Site: **https://jsiovn.github.io/cicd-pipeline/** (`gh api repos/jsiovn/cicd-pipeline/pages`: `build_type` `workflow`, `https_enforced` `true`). `curl -s -o /dev/null -w "%{http_code}" https://jsiovn.github.io/cicd-pipeline/` printed `200` on 2026-11-22 after the first deployment.

Measured 2026-11-22 on commit [`3ce4c8e`](https://github.com/jsiovn/cicd-pipeline/commit/3ce4c8ed35b21997caec63546e0b094d0e6da4eb) (`ci: deploy a static site to GitHub Pages (OIDC) and gate the production promotion (#10)`), the first run of [Actions › Pages](https://github.com/jsiovn/cicd-pipeline/actions/workflows/pages.yml) on `main` (event `push`, runner image `ubuntu-26.04`). Durations from `gh run view <run> --json jobs` (`completedAt - startedAt`, whole seconds as the API reports them).

| Job / step | Duration |
| --- | --- |
| job `build` | 12 s (03:57:53Z → 03:58:05Z) |
| `actions/setup-node@v7` (Node 26) | 5 s |
| `Build the site` (`node scripts/build-site.mjs`) | 0 s |
| `Upload Pages artifact` | 1 s |
| job `deploy` | 8 s (03:58:09Z → 03:58:17Z) |
| `Deploy to GitHub Pages` | 6 s |
| run wall clock (`run_started_at` → `updated_at`) | 26 s (03:57:51Z → 03:58:17Z) |

Log of the build step: `build-site: wrote _site/index.html (8146 bytes)`.

Log of the `deploy` job, verbatim (timestamp prefixes removed; the action's input echo and a Node `punycode` deprecation warning left out). The `GITHUB_TOKEN` permissions the job prints are only `Metadata: read` and `Pages: write`: `id-token: write` is not a token permission, it lets the job request an OIDC token, which the action sends as `oidc_token` (masked):

```text
Fetching artifact metadata for "github-pages" in this workflow run
Found 1 artifact(s)
Creating Pages deployment with payload:
{
	"artifact_id": 14738611161,
	"pages_build_version": "3ce4c8ed35b21997caec63546e0b094d0e6da4eb",
	"oidc_token": "***"
}
Created deployment for 3ce4c8ed35b21997caec63546e0b094d0e6da4eb, ID: 3ce4c8ed35b21997caec63546e0b094d0e6da4eb
Getting Pages deployment status...
Reported success!
Evaluate and set environment url
Evaluated environment url: https://jsiovn.github.io/cicd-pipeline/
```

### Environments

`gh api repos/jsiovn/cicd-pipeline/environments --jq '.environments[] | "\(.name) | rules: \([.protection_rules[].type] | join(",")) | branch policy: \(.deployment_branch_policy)"'`, 2026-11-22:

```text
github-pages | rules: branch_policy | branch policy: {"custom_branch_policies":true,"protected_branches":false}
production | rules: required_reviewers | branch policy: null
vercel | rules:  | branch policy: null
```

- `github-pages` was created by GitHub when Pages was enabled with the `workflow` build type, with one deployment branch policy: `main` (type `branch`), so only runs on `main` may deploy to it (the rule as configured; no run from another branch was tried).
- `production`: `required_reviewers`, reviewer `User:jsiovn` (the repo owner), `prevent_self_review=false`. With one maintainer, self-review must stay allowed or nobody could approve a run they dispatched. Free plan, public repo: up to 6 reviewers.
- `vercel`: no rules yet; it holds the Vercel deploy secrets, which a job can read only when it declares `environment: vercel`.

### Promotion waiting for approval (`release.yml`)

`release.yml` was dispatched once from `main` on 2026-11-22 (`gh workflow run release.yml --repo jsiovn/cicd-pipeline --ref main`). `gh run list --repo jsiovn/cicd-pipeline --workflow release.yml --limit 1 --json status,event,headBranch` a few seconds later:

```text
[{"event":"workflow_dispatch","headBranch":"main","status":"waiting"}]
```

The run's pending deployments (`gh api` on the REST endpoint "Get pending deployments for a workflow run"): environment `production`, `wait_timer` 0, reviewers `jsiovn`, `current_user_can_approve` `true`. Until someone approves, the `promote` job does not start, so the re-tag to `:production` has not run.
