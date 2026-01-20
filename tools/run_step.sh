#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: tools/run_step.sh <step-name-without-extension>"
  echo "Example: tools/run_step.sh 000_sanity"
  exit 2
fi

STEP="$1"
FILE="tools/steps/${STEP}.sh"

if [[ ! -f "$FILE" ]]; then
  echo "ERROR: step file not found: $FILE"
  exit 1
fi

if file "$FILE" | grep -qi 'CRLF'; then
  echo "ERROR: $FILE has CRLF line endings. Convert with: sed -i 's/\r$//' $FILE"
  exit 1
fi

TS="$(date +%Y%m%d_%H%M%S)"
LOG="tools/logs/${TS}_${STEP}.log"

echo "== RUN $FILE ==" | tee "$LOG"
echo "cwd=$(pwd)" | tee -a "$LOG"
echo "ts=$TS" | tee -a "$LOG"
echo | tee -a "$LOG"

bash "$FILE" 2>&1 | tee -a "$LOG"

echo | tee -a "$LOG"
echo "== OK (log: $LOG) ==" | tee -a "$LOG"
