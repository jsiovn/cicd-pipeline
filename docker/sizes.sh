#!/usr/bin/env bash
# Builds every Dockerfile variant with Buildx and measures it: base image size,
# final image size, `docker history` of the production image, node_modules with
# and without devDependencies, and the "added N packages" line of npm ci.
# Then the Next.js app in web/: the standalone image against a naive one.
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

# Docker 29 uses the containerd image store: `docker image inspect .Size` is the
# compressed content size and the `docker image ls` SIZE column is disk usage
# (unpacked layers + compressed content). The size the article compares is the
# unpacked one, the sum of the layer sizes in `docker history`. Record all three.
human() { awk '{ split("B kB MB GB TB", u, " "); i = 1; s = $1
  while (s >= 1000 && i < 5) { s /= 1000; i++ }; printf "%.3g%s\n", s, u[i] }'; }
image_json() { # image
  local unpacked compressed
  unpacked=$(docker history --human=false --format '{{.Size}}' "$1" | awk '{ s += $1 } END { print s }')
  compressed=$(docker image inspect --format '{{.Size}}' "$1")
  jq -n --argjson unpacked "$unpacked" --argjson compressed "$compressed" \
    --arg size "$(human <<< "$unpacked")" --arg compressed_size "$(human <<< "$compressed")" \
    --arg disk_usage "$(docker image ls --format '{{.Size}}' "$1" | head -n 1)" \
    '{size: $size, bytes: $unpacked, compressed_size: $compressed_size,
      compressed_bytes: $compressed, disk_usage: $disk_usage}'
}

build() { # tag file [extra buildx args...]; build context: $context (default .)
  local tag=$1 file=$2
  shift 2
  docker buildx build --progress=plain --load -t "$tag" -f "$file" "$@" "${context:-.}" 2>&1 |
    tee "build-${tag#orders-api:}.log"
}

: > variants.jsonl
for v in "${variants[@]}"; do
  IFS='|' read -r name file base <<< "$v"
  echo "::group::build $name ($file)"
  build "orders-api:$name" "$file"
  docker pull -q "$base"
  echo "::endgroup::"
  jq -n --arg variant "$name" --arg dockerfile "$file" --arg base_image "$base" \
    --argjson base "$(image_json "$base")" --argjson final "$(image_json "orders-api:$name")" \
    '{variant: $variant, dockerfile: $dockerfile, base_image: $base_image,
      base: $base, final: $final}' >> variants.jsonl
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

# Next.js app (web/, its own build context): the image built from
# `output: "standalone"` against one that keeps node_modules and runs npm start.
echo "::group::build web:naive, web:standalone and its build stage"
context=web build web:naive web/Dockerfile.naive
context=web build web:standalone web/Dockerfile
context=web build web:build web/Dockerfile --target build
echo "::endgroup::"
next_version=$(docker run --rm web:build node -p 'require("next/package.json").version')
web_du=$(docker run --rm web:build du -sh .next/standalone node_modules)
web_hostname=$(docker run --rm web:build grep -n HOSTNAME .next/standalone/server.js || echo "(no match)")

# Smoke test: web:standalone starts and answers / with HTTP 200.
docker run -d --name web -p 3402:3000 web:standalone > /dev/null
web_root=""
for _ in $(seq 1 20); do
  web_root=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3402/ || true)
  if [ "$web_root" = 200 ]; then break; fi
  sleep 0.5
done
if [ "$web_root" != 200 ]; then
  docker logs web
  echo "::error::web:standalone did not answer / with HTTP 200 (got $web_root)"
  exit 1
fi
# A file from public/: served only because the Dockerfile copies public/.
web_robots=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3402/robots.txt || true)
docker stop web > /dev/null

: > web.jsonl
for v in "naive|web/Dockerfile.naive|node:26" "standalone|web/Dockerfile|node:26-slim"; do
  IFS='|' read -r name file base <<< "$v"
  jq -n --arg variant "$name" --arg dockerfile "$file" --arg base_image "$base" \
    --argjson base "$(image_json "$base")" --argjson final "$(image_json "web:$name")" \
    '{variant: $variant, dockerfile: $dockerfile, base_image: $base_image,
      base: $base, final: $final}' >> web.jsonl
done
web_json=$(jq -s --arg next "$next_version" --arg du "$web_du" --arg hostname "$web_hostname" \
  --arg root "$web_root" --arg robots "$web_robots" \
  '{next: $next, du: $du, hostname_line: $hostname, http_root: $root,
    http_robots_txt: $robots, images: .}' web.jsonl)

jq -s --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg commit "${GITHUB_SHA:-local}" \
  --arg docker "$docker_version" --arg buildx "$buildx_version" \
  --arg nm_all "$nm_all" --arg nm_prod "$nm_prod" \
  --arg added_all "$added_all" --arg added_prod "$added_prod" \
  --arg history "$history" --arg healthz "$healthz" --argjson web "$web_json" \
  '{date: $date, commit: $commit, docker: $docker, buildx: $buildx, variants: .,
    node_modules: {with_dev: $nm_all, production: $nm_prod},
    npm_ci: {with_dev: $added_all, production: $added_prod},
    history_multi: $history, healthz_multi: $healthz, web: $web}' variants.jsonl > sizes.json

{
  echo "### Image sizes"
  echo
  echo "Size = unpacked (sum of the \`docker history\` layers); compressed = what a pull downloads."
  echo
  echo "| Variant | Dockerfile | Base image | Base size | Final size | Base compressed | Final compressed |"
  echo "| --- | --- | --- | --- | --- | --- | --- |"
  jq -r '.variants[] | "| \(.variant) | `\(.dockerfile)` | `\(.base_image)` | \(.base.size) | \(.final.size) | \(.base.compressed_size) | \(.final.compressed_size) |"' sizes.json
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
  echo
  echo "### Next.js images (web/, Next.js $next_version)"
  echo
  echo "| Image | Dockerfile | Base image | Final size | Final compressed |"
  echo "| --- | --- | --- | --- | --- |"
  jq -r '.web.images[] | "| web:\(.variant) | `\(.dockerfile)` | `\(.base_image)` | \(.final.size) | \(.final.compressed_size) |"' sizes.json
  echo
  echo '```text'
  echo "\$ du -sh .next/standalone node_modules"
  echo "$web_du"
  echo "\$ grep -n HOSTNAME .next/standalone/server.js"
  echo "$web_hostname"
  echo '```'
  echo
  echo "web:standalone: \`/\` HTTP $web_root, \`/robots.txt\` HTTP $web_robots"
} >> "$summary"
