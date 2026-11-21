#!/usr/bin/env bash
# Builds every Dockerfile variant with Buildx and measures it: base image size,
# final image size, `docker history` of the production image, node_modules with
# and without devDependencies, and the "added N packages" line of npm ci.
# Writes sizes.json and, on GitHub Actions, a table into the job summary.
set -euo pipefail

summary=${GITHUB_STEP_SUMMARY:-/dev/stdout}

# name|Dockerfile|base image of the final stage
variants=(
  "multi|Dockerfile|node:26-slim"
  "naive|docker/Dockerfile.naive|node:26"
  "ordered|docker/Dockerfile.ordered|node:26"
  "alpine|docker/Dockerfile.alpine|node:26-alpine"
  "distroless|docker/Dockerfile.distroless|gcr.io/distroless/nodejs26-debian13"
)

size_bytes() { docker image inspect --format '{{.Size}}' "$1"; }
size_human() { docker image ls --format '{{.Size}}' "$1" | head -n 1; }

build() { # tag file [extra buildx args...]
  local tag=$1 file=$2
  shift 2
  docker buildx build --progress=plain --load -t "$tag" -f "$file" "$@" . 2>&1 |
    tee "build-${tag#orders-api:}.log"
}

: > variants.jsonl
for v in "${variants[@]}"; do
  IFS='|' read -r name file base <<< "$v"
  echo "::group::build $name ($file)"
  build "orders-api:$name" "$file"
  docker pull -q "$base"
  echo "::endgroup::"
  jq -n --arg variant "$name" --arg dockerfile "$file" --arg base "$base" \
    --argjson base_bytes "$(size_bytes "$base")" --arg base_size "$(size_human "$base")" \
    --argjson bytes "$(size_bytes "orders-api:$name")" --arg size "$(size_human "orders-api:$name")" \
    '{variant: $variant, dockerfile: $dockerfile, base: $base,
      base_size: $base_size, base_bytes: $base_bytes, size: $size, bytes: $bytes}' >> variants.jsonl
done

# node_modules of the two install stages of the production Dockerfile.
echo "::group::build stages deps and prod-deps"
build orders-api:deps Dockerfile --target deps
build orders-api:prod-deps Dockerfile --target prod-deps
echo "::endgroup::"
nm_all=$(docker run --rm orders-api:deps du -sh /app/node_modules | cut -f1)
nm_prod=$(docker run --rm orders-api:prod-deps du -sh /app/node_modules | cut -f1)

# "added N packages ..." printed by npm ci in each install stage of the multi build.
npm_added() { # stage
  local id
  id=$(grep -oE "^#[0-9]+ \[$1 [0-9]+/[0-9]+\] RUN npm ci" build-multi.log | head -n 1 | cut -d' ' -f1)
  grep -E "^$id [0-9.]+ added [0-9]+ packages" build-multi.log | head -n 1 | sed -E "s/^$id [0-9.]+ //"
}
added_all=$(npm_added deps)
added_prod=$(npm_added prod-deps)

history=$(docker history --format '{{.Size}}\t{{.CreatedBy}}' orders-api:multi)
docker_version=$(docker version --format '{{.Server.Version}}')
buildx_version=$(docker buildx version)

# Smoke test: the production image starts and answers /healthz.
docker run -d --name orders-api -p 3000:3000 orders-api:multi > /dev/null
healthz=""
for _ in $(seq 1 20); do
  if healthz=$(curl -fsS http://127.0.0.1:3000/healthz); then break; fi
  sleep 0.5
done
docker stop orders-api > /dev/null
if [ -z "$healthz" ]; then
  docker logs orders-api
  echo "::error::orders-api:multi did not answer /healthz"
  exit 1
fi

jq -s --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg commit "${GITHUB_SHA:-local}" \
  --arg docker "$docker_version" --arg buildx "$buildx_version" \
  --arg nm_all "$nm_all" --arg nm_prod "$nm_prod" \
  --arg added_all "$added_all" --arg added_prod "$added_prod" \
  --arg history "$history" --arg healthz "$healthz" \
  '{date: $date, commit: $commit, docker: $docker, buildx: $buildx, variants: .,
    node_modules: {with_dev: $nm_all, production: $nm_prod},
    npm_ci: {with_dev: $added_all, production: $added_prod},
    history_multi: $history, healthz_multi: $healthz}' variants.jsonl > sizes.json

{
  echo "### Image sizes"
  echo
  echo "| Variant | Dockerfile | Base image | Base size | Final size |"
  echo "| --- | --- | --- | --- | --- |"
  jq -r '.variants[] | "| \(.variant) | `\(.dockerfile)` | `\(.base)` | \(.base_size) | \(.size) |"' sizes.json
  echo
  echo "### node_modules"
  echo
  echo "- with devDependencies (stage \`deps\`): $nm_all — npm ci: \`$added_all\`"
  echo "- production only (stage \`prod-deps\`): $nm_prod — npm ci --omit=dev: \`$added_prod\`"
  echo
  echo "### docker history orders-api:multi"
  echo
  echo '```text'
  echo "$history"
  echo '```'
  echo
  echo "Docker $docker_version, $buildx_version. /healthz: \`$healthz\`"
} >> "$summary"
