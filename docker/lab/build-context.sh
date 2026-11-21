#!/usr/bin/env bash
# Docker post 1.3: how much of the checkout reaches the builder, with and
# without .dockerignore. Run after `npm ci`, so node_modules exists.
#
# The context is exported exactly as the builder receives it (FROM scratch,
# COPY . /, local exporter) and measured with `du -sh`: that is the primary
# figure. BuildKit's own "transferring context" line is recorded next to it;
# the builder cache is pruned before each build so the transfer starts empty.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
lab_start build-context "Build context with and without .dockerignore (post 1.3)"
versions

ctx_file="$RUNNER_TEMP/context.Dockerfile"
printf 'FROM scratch\nCOPY . /\n' > "$ctx_file"
must "cat $ctx_file"
must "du -sh node_modules"

measure() { # label
  local dest="$RUNNER_TEMP/context-$1"
  must "docker builder prune -af > /dev/null"
  must "docker build --progress=plain -f $ctx_file -o type=local,dest=$dest . 2>&1 | grep -E 'transferring context|load .dockerignore'"
  must "du -sh $dest"
  must "find $dest -maxdepth 1 -mindepth 1 -printf '%f\n' | sort | tr '\n' ' '"
}

note "---- with .dockerignore ----"
must "cat .dockerignore"
measure with-dockerignore
note "---- without .dockerignore ----"
must "mv .dockerignore $RUNNER_TEMP/dockerignore.bak"
measure without-dockerignore
must "mv $RUNNER_TEMP/dockerignore.bak .dockerignore"

with=$(du -sk "$RUNNER_TEMP/context-with-dockerignore" | cut -f1)
without=$(du -sk "$RUNNER_TEMP/context-without-dockerignore" | cut -f1)
[ "$with" -lt "$without" ] || fail "context with .dockerignore (${with}K) is not smaller than without (${without}K)"
[ -d "$RUNNER_TEMP/context-without-dockerignore/node_modules" ] || fail "node_modules missing from the unfiltered context"
[ ! -e "$RUNNER_TEMP/context-with-dockerignore/node_modules" ] || fail "node_modules present despite .dockerignore"
ok "context: ${without}K without .dockerignore, ${with}K with it (du -sk of the exported context)"
finish
