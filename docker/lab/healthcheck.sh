#!/usr/bin/env bash
# Docker post 8.2: how long until the production container's HEALTHCHECK
# (--interval=30s --timeout=3s --start-period=5s --retries=3) reports healthy.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
lab_start healthcheck "HEALTHCHECK: time to healthy (post 8.2)"
versions
trap 'docker rm -f orders-api > /dev/null 2>&1 || true' EXIT
must "docker build -q -t orders-api ."
run "docker image inspect --format '{{json .Config.Healthcheck}}' orders-api"
must "docker run -d --name orders-api -p 3000:3000 orders-api"
start=$(date +%s.%N)
note "poll .State.Health.Status every 0.5 s (at most 90 s), print each change"
prev=
status=
for _ in $(seq 1 180); do
  status=$(docker inspect --format '{{.State.Health.Status}}' orders-api)
  if [ "$status" != "$prev" ]; then
    note "t+$(seconds_since "$start") s after docker run returned: $status"
    prev=$status
  fi
  [ "$status" = healthy ] && break
  sleep 0.5
done
[ "$status" = healthy ] || fail "not healthy after 90 s (last status: $status)"
run "docker inspect --format='{{.State.Health.Status}}' orders-api"
run "docker inspect --format '{{.State.StartedAt}}' orders-api"
run "docker inspect --format '{{json .State.Health.Log}}' orders-api | jq -c '.[] | {Start, End, ExitCode, Output}'"
run "docker ps --format '{{.Names}}  {{.Status}}'"
ok "the container reached healthy"
finish
