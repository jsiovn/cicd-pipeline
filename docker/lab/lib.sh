# Shared helpers for the Docker lab scripts (sourced, not executed).
# Each experiment writes what it ran and what it printed into lab-out/<name>.txt;
# `finish` copies that file into the job summary. The workflow uploads lab-out/.
# lab-out/ lives outside the checkout so the logs never enter a build context.

RUNNER_TEMP=${RUNNER_TEMP:-/tmp}
out_dir=${LAB_OUT:-$RUNNER_TEMP/lab-out}
mkdir -p "$out_dir"

lab_start() { # name title
  lab_name=$1
  lab_title=$2
  lab_log="$out_dir/$lab_name.txt"
  : > "$lab_log"
}

note() { # text: a line of context in the record, not a command
  printf '%s\n' "# $*" | tee -a "$lab_log"
}

# run 'command string': records "$ command", then its stdout+stderr verbatim,
# then "[exit N]" when it fails. Terminal colour codes are stripped. Never
# aborts the script; the exit code is left in $rc and the output in $out for
# the assertions that follow.
run() {
  printf '$ %s\n' "$1" | tee -a "$lab_log"
  set +e
  out=$(bash -o pipefail -c "$1" 2>&1)
  rc=$?
  out=$(sed 's/\x1b\[[0-9;]*m//g' <<< "$out")
  set -e
  if [ -n "$out" ]; then printf '%s\n' "$out" | tee -a "$lab_log"; fi
  if [ "$rc" -ne 0 ]; then printf '[exit %s]\n' "$rc" | tee -a "$lab_log"; fi
  echo >> "$lab_log"
}

# Same as run, but stops the job if the command fails (setup steps).
must() {
  run "$1"
  if [ "$rc" -ne 0 ]; then fail "setup command failed: $1"; fi
}

fail() {
  printf 'FAIL: %s\n' "$*" | tee -a "$lab_log"
  echo "::error::$lab_name: $*"
  finish
  exit 1
}

ok() {
  printf 'OK: %s\n' "$*" | tee -a "$lab_log"
}

versions() {
  run "docker version --format 'Docker server {{.Server.Version}}, client {{.Client.Version}}'"
  run "docker buildx version"
  run "docker buildx inspect | grep -iE '^(Driver|BuildKit version):'"
  run "date -u +%Y-%m-%dT%H:%M:%SZ"
}

finish() {
  {
    echo "### $lab_title"
    echo
    echo '```text'
    cat "$lab_log"
    echo '```'
  } >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
}

# Runtime experiments: wait until a container has logged a line (the SIGTERM
# handler is registered before "listening on", so stopping earlier proves nothing).
wait_for_log() { # container pattern [seconds]
  local i
  for i in $(seq 1 "${3:-30}"); do
    if docker logs "$1" 2>&1 | grep -q "$2"; then return 0; fi
    sleep 1
  done
  fail "$1 did not log '$2' within ${3:-30} s"
}

seconds_since() { # start (from date +%s.%N): seconds elapsed, two decimals
  awk -v a="$1" -v b="$(date +%s.%N)" 'BEGIN { printf "%.2f", b - a }'
}
