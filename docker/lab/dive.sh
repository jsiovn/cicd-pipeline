#!/usr/bin/env bash
# Docker post 7: dive in CI mode on the production image (root Dockerfile).
# CI=true skips the UI, prints efficiency / wasted bytes and a Result line, and
# exits non-zero when a rule of .dive-ci fails.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
lab_start dive "dive in CI mode on the production image (post 7)"
versions

dive_image=docker.io/wagoodman/dive:v0.13.1
must "docker build -q -t orders-api:multi ."
must "docker pull -q $dive_image"
must "cat .dive-ci"

note "---- the post's command: dive reads the image through the Docker socket ----"
run "docker run --rm -e CI=true -v /var/run/docker.sock:/var/run/docker.sock -v \"\$PWD/.dive-ci:/.dive-ci:ro\" $dive_image orders-api:multi --ci-config /.dive-ci"
if [ "$rc" -ne 0 ] && ! grep -q '^Result:' <<< "$out"; then
  note "---- the Docker engine source failed: analyse a docker save archive instead ----"
  must "docker save -o \"$RUNNER_TEMP/orders-api.tar\" orders-api:multi"
  run "docker run --rm -e CI=true -v \"$RUNNER_TEMP/orders-api.tar:/image.tar:ro\" -v \"\$PWD/.dive-ci:/.dive-ci:ro\" $dive_image --source docker-archive /image.tar --ci-config /.dive-ci"
fi
grep -qE 'efficiency: [0-9.]+ %' <<< "$out" || fail "dive printed no efficiency figure"
grep -q '^Result:PASS' <<< "$out" || fail "dive did not pass the .dive-ci rules (exit $rc)"
[ "$rc" -eq 0 ] || fail "dive exited $rc"
ok "dive: $(grep -oE 'efficiency: [0-9.]+ %' <<< "$out"), Result:PASS"
finish
