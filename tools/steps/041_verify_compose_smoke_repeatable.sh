#!/usr/bin/env bash
# Step 041 — verify_compose_smoke_repeatable (NO-CHANGE)
# Confirm docker compose up -d --build + /health remains stable.
# No repo modifications (except logs via runner).

set -euo pipefail

# 1) Ensure stack is up (rebuild allowed)
echo "--- docker compose up -d --build ---"
docker compose up -d --build

# 2) Show services status
echo "--- docker compose ps ---"
docker compose ps

# 3) Health check
URL="http://localhost:8000/health"
OUT="/tmp/health_step041.out"
echo "--- curl $URL ---"
CODE=$(curl -sS -o "$OUT" -w "HTTP=%{http_code}\n" "$URL")
echo "$CODE"
cat "$OUT" || true

# 4) Repo cleanliness
echo "--- git status --porcelain (raw) ---"
git status --porcelain | sed -n '1,80p'

echo "--- git status (filtered, exclude tools/logs) ---"
(git status --porcelain | grep -v '^\?\? tools/logs/' || true)