#!/usr/bin/env bash
# Docker post 8.3: `docker stop` on the production container (CMD ["node",
# "dist/server.js"]): the SIGTERM handler logs and exits 0 well before the
# 10-second kill. Counter-experiment: the same image started with `npm start`
# (the CMD the post warns against). Does SIGTERM still reach Node?
set -euo pipefail
. "$(dirname "$0")/lib.sh"
lab_start graceful-shutdown "Graceful shutdown: node vs npm start (post 8.3)"
versions
trap 'docker rm -f orders-api orders-npm > /dev/null 2>&1 || true' EXIT
must "docker build -q -t orders-api ."
run "docker run --rm orders-api npm --version"
run "docker image inspect --format '{{json .Config.Cmd}}' orders-api"

stop_and_measure() { # container: sets stop_secs, exit_code, logs
  local start
  start=$(date +%s.%N)
  run "docker stop $1"
  stop_secs=$(seconds_since "$start")
  note "docker stop took $stop_secs s"
  run "docker inspect --format '{{.State.ExitCode}}' $1"
  exit_code=$out
  run "docker logs $1"
  logs=$out
}

note "---- CMD [\"node\", \"dist/server.js\"] (the image as built) ----"
must "docker run -d --name orders-api orders-api"
wait_for_log orders-api "listening on 3000"
run "docker top orders-api -o pid,ppid,args"
stop_and_measure orders-api
[ "$exit_code" = 0 ] || fail "node exited $exit_code, expected 0"
grep -q '"msg":"listening on 3000"' <<< "$logs" || fail "no listening line in the logs"
grep -q '"msg":"SIGTERM received, draining connections"' <<< "$logs" || fail "no SIGTERM line in the logs"
awk -v s="$stop_secs" 'BEGIN { exit !(s < 5) }' || fail "docker stop took $stop_secs s"
ok "node as PID 1: both log lines, exit 0, docker stop took $stop_secs s"

note "---- the same image started with npm start ----"
must "docker run -d --name orders-npm orders-api npm start"
wait_for_log orders-npm "listening on 3000"
run "docker top orders-npm -o pid,ppid,args"
stop_and_measure orders-npm
if grep -q 'SIGTERM received, draining connections' <<< "$logs"; then
  ok "npm start: SIGTERM reached Node (drain line logged), exit $exit_code, docker stop took $stop_secs s"
elif [ "$exit_code" = 137 ]; then
  ok "npm start: SIGTERM did not reach Node; Docker killed it after the timeout (exit 137, $stop_secs s)"
else
  ok "npm start: npm exited on SIGTERM without the drain line (exit $exit_code, $stop_secs s): not graceful"
fi
finish
