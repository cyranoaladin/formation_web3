#!/usr/bin/env bash
set -euo pipefail
if [[ $# -lt 1 ]]; then
  echo "Usage: tools/run.sh <step_script>" >&2
  exit 1
fi
STEP="$1"
if [[ ! -f "$STEP" ]]; then
  echo "Step file not found: $STEP" >&2
  exit 1
fi
ts=$(date +%Y%m%d_%H%M%S)
mkdir -p tools/logs
log="tools/logs/$(basename "$STEP").${ts}.log"
echo "[RUN] $STEP" | tee "$log"
bash "$STEP" 2>&1 | tee -a "$log"
echo "[OK]  $STEP" | tee -a "$log"
