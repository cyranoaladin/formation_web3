#!/usr/bin/env bash
# STEP 057 — scan_labs_assets_no_change (NO-CHANGE)
# Inventory of existing labs, runner files, API routes, and schemas.

set -euo pipefail

TS=$(date +%Y%m%d_%H%M%S)
LOG_FILE="tools/logs/labs_scan_${TS}.txt"
mkdir -p tools/logs

{
  echo "[INFO] STEP 057 @ ${TS}"
  
  echo
  echo "== 1. Labs Structure =="
  echo "ls -la labs/:"
  ls -la labs/ || echo "[missing labs/]"
  echo
  echo "ls -R labs/specs (depth 2):"
  if [[ -d labs/specs ]]; then
      find labs/specs -maxdepth 2 -ls
  else
      echo "[missing labs/specs]"
  fi

  echo
  echo "== 2. Runner Assets =="
  echo "ls -la runner/:"
  ls -la runner/

  echo
  echo "== 3. API Endpoints =="
  echo "grep '@app' api/app/main.py:"
  if [[ -f api/app/main.py ]]; then
      grep "@app" api/app/main.py || true
  else
       # Try finding where app is defined
       grep -r "@.*get" api/app || true
       grep -r "@.*post" api/app || true
  fi

  echo
  echo "== 4. Worker Lab Handling =="
  echo "grep 'lab_id ==' worker/worker.py:"
  grep "lab_id ==" worker/worker.py || true

  echo
  echo "== 5. Schemas =="
  SCHEMA_ROOT="schemas/canonical" # based on worker.py constant
  # worker.py says: SCHEMA_ROOT = "/repo/schemas/canonical"
  # In repo root, it is schemas/canonical
  echo "ls -la schemas/canonical:"
  if [[ -d schemas/canonical ]]; then
      ls -la schemas/canonical
  else
      echo "[missing schemas/canonical]"
      ls -la schemas/ || true
  fi

  echo
  echo "== 6. Pipelines / RAG =="
  echo "ls -R pipelines/rag:"
  if [[ -d pipelines/rag ]]; then
      ls -R pipelines/rag
  else
      echo "[missing pipelines/rag]"
      ls -la pipelines/ || true
  fi

  echo
  echo "== Verify Harness =="
  bash tools/verify.sh --spec tools/verify.spec

} | tee "$LOG_FILE"
