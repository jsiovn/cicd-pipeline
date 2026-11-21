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

Log lines containing "Cache", attempt 2 (MISS), verbatim (job | step | line):

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

`actions/setup-node` and automatic caching (README at tag `v7` read 2026-11-21; latest release `v7.1.0`):

> Caching for npm dependencies is automatically enabled when your `package.json` contains either `devEngines.packageManager` field or top-level `packageManager` field set to `npm`, and no explicit cache input is provided.

> If your `package.json` file does not include a `packageManager` field set to `npm`, caching will be disabled unless you explicitly enable it.

The README lists this under "Breaking changes in V6" (V5 had first turned caching on by default with package-manager detection). The switch is the `package-manager-cache` input, default `true`; the logs above print `package-manager-cache: true`. This repo's `package.json` has no `packageManager` field, so caching here comes from the explicit `cache: npm` line. Yarn and pnpm are never cached automatically: they need `cache: yarn` / `cache: pnpm`.

## PR gate

Set up 2026-11-21. Ruleset `main` (id 27813828), created with `gh api -X POST repos/jsiovn/cicd-pipeline/rulesets --input <file>`: enforcement `active`, target the default branch, no bypass actors.

`gh api repos/jsiovn/cicd-pipeline/rules/branches/main --jq '.[].type'`:

```text
deletion
non_fast_forward
pull_request
required_status_checks
```

`pull_request` requires 0 approvals (one maintainer). `required_status_checks` requires the single check `ci-ok`, with "Require branches to be up to date" (`strict_required_status_checks_policy: true`). `ci-ok` is the job in `ci.yml` that `needs: [lint, test, build]` and runs with `if: always()`, so it reports success or failure on every pull request and is never left "expected".

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
- [#1](https://github.com/jsiovn/cicd-pipeline/pull/1) `[exhibit] Raise the free-shipping threshold to 600,000 VND` changes `FREE_SHIPPING_THRESHOLD` in `src/pricing/index.ts` from `500_000` to `600_000`, and is kept open. After its branch was updated to `main`: `mergeStateStatus` `BLOCKED`; `lint` `SUCCESS`; `test (22)`, `test (24)`, `test (26)` `FAILURE`; `build` `SKIPPED`; `ci-ok` `FAILURE`. The failing test, from the log: `FAIL src/pricing/pricing.test.ts > isFreeShipping > is free from 500,000 VND`, `AssertionError: expected false to be true // Object.is equality`, `Tests 1 failed | 8 passed (9)`.
  - Vitest's GitHub Actions annotation sits at `src/pricing/pricing.test.ts:25` (title `src/pricing/pricing.test.ts > isFreeShipping > is free from 500,000 VND`). The PR does not touch that file, so the annotation shows in the run summary and the PR's Checks tab, not inline under "Files changed": GitHub draws an annotation on the diff only on lines the diff contains.
