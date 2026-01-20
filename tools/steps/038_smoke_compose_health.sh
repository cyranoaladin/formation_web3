#!/usr/bin/env bash
# Step 038 — smoke_docker_compose_health (NO DOC CHANGES)
# - Start stack with docker compose
# - Verify API /health responds
# - No repo modifications (except logs produced by runner)

set -euo pipefail

# 1) docker compose config (first lines)
echo "--- docker compose config (head) ---"
docker compose config | sed -n '1,20p'

# 2) Up stack (detached, build if needed)
echo "--- docker compose up -d --build ---"
docker compose up -d --build

# 3) docker compose ps
echo "--- docker compose ps ---"
docker compose ps

# 4) Health check loop (up to 90s)
URL="http://localhost:8000/health"
OUT="/tmp/health.out"
HTTP=""
for i in $(seq 1 90); do
  HTTP=$(curl -sS -o "$OUT" -w "HTTP=%{http_code}\n" "$URL" || true)
  code="${HTTP#HTTP=}"
  if [[ "$code" == "200" ]]; then
    break
  fi
  sleep 1
done

echo "--- curl $URL ---"
echo "$HTTP"
cat "$OUT" || true

# 5) If not 200, show api logs tail
if [[ "${HTTP#HTTP=}" != "200" ]]; then
  echo "--- docker compose logs --tail=80 api (since HTTP!=200) ---"
  docker compose logs --tail=80 api || true
fi

# 6) Repo cleanliness (ignore tools/logs/)
echo "--- git status --porcelain (raw) ---"
git status --porcelain | sed -n '1,100p'

echo "--- git status (filtered: exclude tools/logs/) ---"
FILTERED=$(git status --porcelain | grep -v '^\?\? tools/logs/' || true)
printf "%s\n" "$FILTERED"
if [[ -z "$FILTERED" ]]; then
  echo "CLEAN=1"
else
  echo "CLEAN=0"
fi