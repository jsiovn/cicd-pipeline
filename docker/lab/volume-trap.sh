#!/usr/bin/env bash
# Docker post 6.1: the bind mount .:/app hides the node_modules the dev image
# installed; an anonymous volume on /app/node_modules brings it back. The
# checkout has no node_modules (no npm ci in this job). The bind-only run goes
# first: the anonymous-volume run leaves an empty mountpoint in the checkout.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
lab_start volume-trap "Volume trap: node_modules behind the bind mount (post 6.1)"
versions
[ ! -e node_modules ] || fail "node_modules exists in the checkout; the experiment needs a checkout without it"
run "ls -A"
must "docker build -q -f docker/Dockerfile.dev -t orders-api:dev ."
run "docker run --rm orders-api:dev node -e \"console.log('in the image, no mounts:', require('fs').readdirSync('/app/node_modules').length, 'entries')\""

note "---- only the bind mount ----"
bind_only='docker run --rm -v $(pwd):/app orders-api:dev \
    node -e "const fs=require('"'fs'"'); console.log(fs.existsSync('"'/app/node_modules'"') ? '"'present'"' : '"'GONE'"')"'
run "$bind_only"
[ "$out" = GONE ] || fail "expected GONE with only the bind mount, got: $out"
ok "with only -v \$(pwd):/app, node_modules is missing inside the container"

note "---- bind mount + anonymous volume on /app/node_modules ----"
with_volume='docker run --rm -v $(pwd):/app -v /app/node_modules orders-api:dev \
    node -e "console.log('"'node_modules entries:'"', require('"'fs'"').readdirSync('"'/app/node_modules'"').length)"'
run "$with_volume"
grep -qE '^node_modules entries: [1-9][0-9]*$' <<< "$out" || fail "node_modules is not back with the anonymous volume: $out"
ok "with -v /app/node_modules, the image's node_modules is visible again"
note "the anonymous volume left an empty mountpoint in the checkout:"
run "ls -ld node_modules && ls -A node_modules | wc -l"
finish
