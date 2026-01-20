#!/usr/bin/env bash
# Step 047a — collect_api_worker_logs_and_health
# Goal: Capture API/worker logs and confirm API health after Step 047 failure.
# Proofs: docker compose ps, logs (api+worker), /health HTTP status+body.

set -euo pipefail

echo "--- docker compose ps ---"
docker compose ps || true

echo "--- docker compose logs --tail=200 api ---"
docker compose logs --tail=200 api || true

echo "--- docker compose logs --tail=200 worker ---"
docker compose logs --tail=200 worker || true

echo "--- curl /health ---"
set +e
curl -sS -w "\nHTTP=%{http_code}\n" http://localhost:8000/health -o /tmp/health.json
rc=$?
set -e
cat /tmp/health.json || true
echo "CURL_RC=${rc}"
