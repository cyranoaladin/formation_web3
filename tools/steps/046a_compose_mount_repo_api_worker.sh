#!/usr/bin/env bash
# Step 046a — compose_mount_repo_api_worker (pre-047 dependency)
# Goal: Ensure /repo (the repo root) is mounted read-only into api and worker containers
# Rationale: Step 047 loads JSON Schemas from /repo/schemas/canonical inside the containers.
# Proofs: show docker-compose.override.yml content, merged docker compose config with /repo mounts,
#         containers running, and that /repo/schemas/canonical is readable inside api/worker.

set -euo pipefail

OVR_FILE="docker-compose.override.yml"
TMP_OVR="/tmp/docker-compose.override.046a.yml"

cat >"${TMP_OVR}" <<'YAML'
services:
  api:
    volumes:
      - ./:/repo:ro
  worker:
    volumes:
      - ./:/repo:ro
YAML

need_update=0
if [[ ! -f "${OVR_FILE}" ]]; then
  need_update=1
else
  # If file already equals desired content, no update needed; otherwise we abort to avoid clobbering custom overrides
  if ! diff -u "${OVR_FILE}" "${TMP_OVR}" >/dev/null 2>&1; then
    echo "[WARN] ${OVR_FILE} exists and differs from desired minimal content." >&2
    echo "[WARN] To keep this step idempotent and safe, we won't edit it automatically." >&2
    echo "[HINT] Merge the following desired content into ${OVR_FILE}:" >&2
    sed -n '1,200p' "${TMP_OVR}" >&2
    echo "ABORTING_NO_EDIT=1"
    exit 2
  fi
fi

if [[ "$need_update" -eq 1 ]]; then
  cp "${TMP_OVR}" "${OVR_FILE}"
  echo "WROTE_OVERRIDE=${OVR_FILE}"
else
  echo "WROTE_OVERRIDE=0 (already up-to-date)"
fi

# Show effective config to prove mounts are present
echo "--- docker compose config (grep /repo:ro) ---"
docker compose config | grep -n "/repo:ro" -n || true

# Rebuild + up to ensure containers see the new mount
echo "--- docker compose up -d --build (api, worker only) ---"
docker compose up -d --build api worker

echo "--- docker compose ps (api, worker) ---"
docker compose ps api worker || true

# Validate that schemas are visible inside containers
set +e
API_LS=$(docker compose exec -T api ls -1 /repo/schemas/canonical 2>&1)
API_RC=$?
WORKER_LS=$(docker compose exec -T worker ls -1 /repo/schemas/canonical 2>&1)
WORKER_RC=$?
set -e

echo "API_SCHEMA_LS_RC=${API_RC}"
echo "API_SCHEMA_LS_OUT_BEGIN"; echo "$API_LS" | sed -n '1,120p'; echo "API_SCHEMA_LS_OUT_END"

echo "WORKER_SCHEMA_LS_RC=${WORKER_RC}"
echo "WORKER_SCHEMA_LS_OUT_BEGIN"; echo "$WORKER_LS" | sed -n '1,120p'; echo "WORKER_SCHEMA_LS_OUT_END"

# Git status for traceability
echo "--- git status --porcelain ---"
git status --porcelain | sed -n '1,200p'
