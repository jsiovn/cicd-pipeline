#!/usr/bin/env bash
# Docker post 4: a build-arg token stays in the image history; a BuildKit
# secret mount does not. Then: is `# syntax=docker/dockerfile:1` required for
# RUN --mount on this Docker, or only recommended?
#
# The token is FAKE on purpose and does not match the real npm token format.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
lab_start secrets "Secrets: ARG vs secret mount, and the syntax directive (post 4)"
versions

token=npm_FAKE_TOKEN_DO_NOT_USE
token_file="$RUNNER_TEMP/npm_token.txt"
printf '%s' "$token" > "$token_file"

note "---- 4.1 leaky: ARG NPM_TOKEN (docker/lab/Dockerfile.leaky) ----"
must "docker build --progress=plain --build-arg NPM_TOKEN=$token -f docker/lab/Dockerfile.leaky -t leaky:demo docker/lab 2>&1 | grep -vE '^#[0-9]+ (sha256|extracting|resolve|[0-9.]+ ?MB|DONE 0\.0s)'"
must "docker history --no-trunc --format '{{.CreatedBy}}' leaky:demo | head -n 3"
run "docker history --no-trunc --format '{{.CreatedBy}}' leaky:demo | grep -c $token"
[ "$rc" -eq 0 ] && [ "$out" -ge 1 ] || fail "the fake token is not in the leaky image history"
ok "leaky:demo history exposes the token ($out lines)"

note "---- 4.2 safe: RUN --mount=type=secret (docker/lab/Dockerfile.safe) ----"
must "docker build --progress=plain --secret id=npm_token,src=$token_file -f docker/lab/Dockerfile.safe -t safe:demo docker/lab 2>&1 | grep -vE '^#[0-9]+ (sha256|extracting|[0-9.]+ ?MB|DONE 0\.0s)'"
must "docker history --no-trunc --format '{{.CreatedBy}}' safe:demo | head -n 3"
run "docker history --no-trunc --format '{{.CreatedBy}}' safe:demo | grep -c $token"
[ "$out" = 0 ] || fail "the token appears in the safe image history"
run "docker image inspect safe:demo | grep -c $token"
[ "$out" = 0 ] || fail "the token appears in docker image inspect of the safe image"
run "docker run --rm safe:demo sh -c 'ls -A /app; ls /run/secrets 2>&1'"
ok "safe:demo: the token is in neither the history nor the image config"

note "---- is '# syntax=docker/dockerfile:1' required for RUN --mount? ----"
note "same Dockerfile twice, with and without the directive; required=true makes the"
note "build fail if the secret is not mounted"
mount_run='RUN --mount=type=secret,id=npm_token,required=true sh -c '\''echo "secret mounted: $(wc -c < /run/secrets/npm_token) bytes"'\'''
printf '# syntax=docker/dockerfile:1\nFROM node:26-slim\n%s\n' "$mount_run" > "$RUNNER_TEMP/Dockerfile.with-directive"
printf 'FROM node:26-slim\n%s\n' "$mount_run" > "$RUNNER_TEMP/Dockerfile.without-directive"
for variant in with-directive without-directive; do
  must "cat $RUNNER_TEMP/Dockerfile.$variant"
  run "docker build --no-cache --progress=plain --secret id=npm_token,src=$token_file -f $RUNNER_TEMP/Dockerfile.$variant -t mount:$variant docker/lab > $out_dir/mount-$variant.log 2>&1; status=\$?; grep -E '^#[0-9]+ (\[|resolve image config|docker-image://)|secret mounted: [0-9]|ERROR' $out_dir/mount-$variant.log; exit \$status"
  printf -v "rc_${variant//-/_}" '%s' "$rc"
done
grep -q 'secret mounted: 25 bytes' "$out_dir/mount-with-directive.log" || fail "the build with the directive did not mount the secret"
[ "$rc_with_directive" -eq 0 ] || fail "the build with the syntax directive failed"
if [ "$rc_without_directive" -eq 0 ] && grep -q 'secret mounted: 25 bytes' "$out_dir/mount-without-directive.log"; then
  ok "RUN --mount builds and mounts the secret WITHOUT the syntax directive: recommended, not required"
else
  ok "RUN --mount does not work without the syntax directive (exit $rc_without_directive): required"
fi
finish
