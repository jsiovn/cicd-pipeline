#!/usr/bin/env bash
# Docker post 8.1: the production image runs as the image's `node` user.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
lab_start non-root "Non-root user (post 8.1)"
versions
trap 'docker rm -f orders-api > /dev/null 2>&1 || true' EXIT
must "docker build -q -t orders-api ."
run "docker image inspect --format 'image Config.User: {{.Config.User}}' orders-api"
must "docker run -d --name orders-api orders-api"
wait_for_log orders-api "listening on 3000"
run "docker exec orders-api whoami"
[ "$out" = node ] || fail "whoami printed '$out', expected node"
run "docker exec orders-api id"
run "docker exec orders-api ls -l /app"
note "for contrast, the base image without USER:"
run "docker run --rm --entrypoint whoami node:26-slim"
ok "the production container runs as node"
finish
