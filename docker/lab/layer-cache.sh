#!/usr/bin/env bash
# Docker post 1.1 vs 1.2: change one line of src/server.ts and rebuild.
# The naive Dockerfile (COPY . . before npm install) re-runs the install step;
# the ordered one (manifests, npm ci, then the source) reports it CACHED.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
lab_start layer-cache "Layer cache: naive vs ordered (post 1.1, 1.2)"
versions

# Builds with --progress=plain into $3 and records the command, the per-step
# lines ("[n/m]" headers with their DONE / CACHED lines) and the wall time.
timed_build() { # variant dockerfile log
  local cmd="docker build --progress=plain -f $2 -t lab:$1 ." start end
  printf '$ %s\n' "$cmd" | tee -a "$lab_log"
  start=$(date +%s.%N)
  $cmd > "$3" 2>&1 || { cat "$3"; fail "build failed: $cmd"; }
  end=$(date +%s.%N)
  awk '/^#[0-9]+ \[[^]]*[0-9]+\/[0-9]+\]/ { id[$1] = 1; print; next }
       ($1 in id) && ($2 == "DONE" || $2 == "CACHED") { print }' "$3" | tee -a "$lab_log"
  awk -v s="$start" -v e="$end" 'BEGIN { printf "TOTAL %.2f s (wall time of docker build)\n\n", e - s }' |
    tee -a "$lab_log"
}
# DONE or CACHED for the step whose command matches $2.
step_status() { # log pattern
  local id
  id=$(grep -E "^#[0-9]+ \[[0-9]+/[0-9]+\] $2" "$1" | head -n 1 | cut -d' ' -f1)
  grep -E "^$id (DONE|CACHED)" "$1" | tail -n 1 | cut -d' ' -f2
}

for v in naive ordered; do
  file="docker/Dockerfile.$v"
  note "---- $v ($file): first build, fills the cache ----"
  timed_build "$v" "$file" "$out_dir/$v-first.log"
  note "---- $v: change one line of src/server.ts ----"
  must "sed -i 's/listening on/listening on port/' src/server.ts"
  must "git diff -U0 -- src/server.ts"
  note "---- $v: rebuild after the one-line change ----"
  timed_build "$v" "$file" "$out_dir/$v-rebuild.log"
  must "git checkout -- src/server.ts"
done

naive_install=$(step_status "$out_dir/naive-rebuild.log" "RUN npm install")
ordered_install=$(step_status "$out_dir/ordered-rebuild.log" "RUN npm ci")
[ "$naive_install" = DONE ] || fail "naive rebuild: RUN npm install is '$naive_install', expected DONE"
ok "naive rebuild re-ran RUN npm install (DONE)"
[ "$ordered_install" = CACHED ] || fail "ordered rebuild: RUN npm ci is '$ordered_install', expected CACHED"
ok "ordered rebuild reused RUN npm ci (CACHED)"
finish
