#!/usr/bin/env bash
# Docker post 3: probes on the alpine and distroless images.
# - alpine: bcrypt (a native module) hashes and compares with its musl prebuild;
# - alpine: forcing a build from source needs a toolchain the image lacks;
# - distroless: there is no shell to enter.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
lab_start base-images "Base image probes: alpine and distroless (post 3)"
versions

note "---- build the two images ----"
must "docker build -q -f docker/Dockerfile.alpine -t orders-api:alpine ."
must "docker build -q -f docker/Dockerfile.distroless -t orders-api:distroless ."

note "---- alpine: bcrypt with its prebuilt binary ----"
run "docker run --rm orders-api:alpine node -e \"
  const bcrypt = require('bcrypt');
  const h = bcrypt.hashSync('secret', 10);
  console.log('alpine bcrypt ok:', bcrypt.compareSync('secret', h));
\""
[ "$rc" -eq 0 ] && grep -q 'alpine bcrypt ok: true' <<< "$out" || fail "bcrypt did not hash and compare on alpine"
ok "bcrypt hashes and compares on node:26-alpine"
run "docker run --rm orders-api:alpine sh -c 'ls node_modules/bcrypt/prebuilds/; cat /etc/alpine-release; which python3 make g++ || true'"

note "---- alpine: force a build from source (node:26-alpine, no toolchain added) ----"
run "docker run --rm orders-api:alpine npm rebuild bcrypt --build-from-source"
rebuild_rc=$rc
[ "$rebuild_rc" -ne 0 ] || fail "npm rebuild bcrypt --build-from-source succeeded on plain alpine"
grep -q 'gyp ERR! find Python' <<< "$out" || fail "the build from source failed, but not for lack of Python"
ok "npm rebuild bcrypt --build-from-source fails on plain alpine: no Python (exit $rebuild_rc)"

note "---- distroless: no shell ----"
run "docker run --rm --entrypoint sh orders-api:distroless -c 'echo hi'"
[ "$rc" -ne 0 ] && grep -q 'executable file not found' <<< "$out" || fail "the distroless shell probe did not fail with 'executable file not found'"
ok "distroless has no sh (exit $rc)"
finish
