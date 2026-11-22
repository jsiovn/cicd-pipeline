#!/usr/bin/env bash
# Docker post 6: the dev stack in compose.yaml. Postgres with a healthcheck, the
# API built from docker/Dockerfile.dev with DATABASE_URL pointing at the service
# name `db`; /healthz runs `select 1` against it. Then: the post's volume path
# (/var/lib/postgresql/data) on the current Postgres major.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
lab_start compose-up "Compose dev stack: api + Postgres (post 6)"
versions
run "docker compose version"
trap 'docker compose down -v > /dev/null 2>&1 || true; docker rm -f pgprobe > /dev/null 2>&1 || true' EXIT

must "docker compose config --images"
must "docker compose build api > $out_dir/compose-build.log 2>&1"
must "docker compose up -d --wait --wait-timeout 180"
must "docker compose ps --format 'table {{.Name}}\t{{.Image}}\t{{.Status}}'"

note "right after --wait returns (api has no healthcheck, so --wait only means 'running'):"
run "curl -s localhost:3000/healthz"
note "poll /healthz once a second until it answers with the database (at most 60 s)"
start=$(date +%s.%N)
for _ in $(seq 1 60); do
  case $(curl -s localhost:3000/healthz || true) in *'"db":"ok"'*) break ;; esac
  sleep 1
done
note "answered with db ok after $(seconds_since "$start") s of polling"
run "curl -s localhost:3000/healthz"
grep -q '"db":"ok"' <<< "$out" || fail "/healthz did not report the database"
ok "/healthz answered through compose and the API reached Postgres at host db"

run "docker compose logs --no-log-prefix api"
run "docker compose exec api node --version"
run "docker compose exec api npm --version"
run "docker compose exec db postgres --version"
run "docker compose exec db sh -c 'echo PGDATA=\$PGDATA'"
run "docker image inspect --format '{{json .Config.Volumes}}' postgres:19-alpine"
must "docker compose down -v"

note "---- the post's volume path, /var/lib/postgresql/data, on postgres:19-alpine ----"
must "docker run -d --name pgprobe -e POSTGRES_PASSWORD=probe -v pgprobe:/var/lib/postgresql/data postgres:19-alpine > /dev/null"
for _ in $(seq 1 30); do
  [ "$(docker inspect --format '{{.State.Running}}' pgprobe)" = false ] && break
  docker logs pgprobe 2>&1 | grep -q 'database system is ready to accept connections' && break
  sleep 1
done
run "docker inspect --format 'running={{.State.Running}} exit code={{.State.ExitCode}}' pgprobe"
state=$out
run "docker logs pgprobe 2>&1 | tail -n 25"
case $state in
  running=false*) ok "postgres:19-alpine refuses to start with the volume at /var/lib/postgresql/data ($state)" ;;
  *) ok "postgres:19-alpine starts with the volume at /var/lib/postgresql/data ($state)" ;;
esac
docker rm -f pgprobe > /dev/null 2>&1 || true
docker volume rm pgprobe > /dev/null 2>&1 || true
finish
