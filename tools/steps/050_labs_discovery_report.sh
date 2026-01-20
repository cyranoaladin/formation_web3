#!/usr/bin/env bash
# Step 050 — labs_discovery_report (NO-CODE CHANGE)
# Goal: Inventory any labs-related content and produce a factual report.
# Outputs only to tools/logs/; no repo changes.
# Proofs: timestamped report with directory trees, counts, and next-step hints; git status.

set -euo pipefail

TS=$(date +%Y%m%d_%H%M%S)
LOG="tools/logs/050_labs_discovery_${TS}.txt"
mkdir -p tools/logs

{
  echo "[INFO] labs discovery report @ $TS"
  echo "== repo root =="
  ls -la | sed -n '1,200p'

  echo
  echo "== schemas/canonical =="
  if [[ -d schemas/canonical ]]; then
    ls -l schemas/canonical | sed -n '1,200p'
  else
    echo "(missing) schemas/canonical"
  fi

  echo
  echo "== labs directory tree (depth<=3) =="
  if [[ -d labs ]]; then
    find labs -maxdepth 3 -printf '%y %p\n' | sed -n '1,400p'
  else
    echo "(missing) labs/"
  fi

  echo
  echo "== candidate lab spec files (JSON/YAML) =="
  if [[ -d labs ]]; then
    find labs -maxdepth 4 \( -name '*.json' -o -name '*.yaml' -o -name '*.yml' \) -printf '%p\n' | sed -n '1,400p' || true
  else
    echo "(none)"
  fi

  echo
  echo "== tests/fixtures presence =="
  if [[ -d tests/fixtures ]]; then
    ls -l tests/fixtures | sed -n '1,200p'
  else
    echo "(missing) tests/fixtures"
  fi

  echo
  echo "== docker compose services (name -> status) =="
  docker compose ps || true

  echo
  echo "== next step hints =="
  echo "- Add lab schema(s) under schemas/canonical (e.g., lab.schema.json, labs_index.schema.json)."
  echo "- Create first lab spec folder (e.g., labs/specs/hello-proof/lab.json)."
  echo "- Implement API GET /labs to list lab ids and metadata from filesystem."
  echo "- Add minimal runner path keyed by lab_id to produce lab-specific proofs."

} >"$LOG"

# Print tail of report as proof
sed -n '1,200p' "$LOG"

# Git status for traceability
echo "--- git status --porcelain ---"
git status --porcelain | sed -n '1,200p'
