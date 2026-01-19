#!/usr/bin/env bash
# Step 024 — repo_scan_for_docs_inputs (NO-CHANGE)
# Objective: Scan the repository for inputs needed by AUTOGRADING.md and LABS.md without modifying any files.
# Output: report saved to tools/logs/repo_scan_docs_YYYYMMDD_HHMMSS.txt

set -euo pipefail

# Timestamped report path
TS="$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="tools/logs"
REPORT_PATH="${REPORT_DIR}/repo_scan_docs_${TS}.txt"
mkdir -p "${REPORT_DIR}"

# Small helper to append a titled section
section() {
  echo "" >>"${REPORT_PATH}"
  echo "## $1" >>"${REPORT_PATH}"
}

# Header
{
  echo "# Repo Scan Report"
  echo "generated_at: $(date -Iseconds)"
  echo "cwd: $(pwd)"
} >"${REPORT_PATH}"

# 1) Arborescence niveau 2 (répertoires)
section "1) Arborescence niveau 2 (répertoires)"
{
  echo "- ls -la (racine)"
  ls -la || true

  echo ""
  echo "- find . -maxdepth 2 -type d | sort"
  find . -maxdepth 2 -type d 2>/dev/null | sort || true
} >>"${REPORT_PATH}"

# Prepare common targets if they exist
TARGETS=()
[[ -d api ]] && TARGETS+=(api)
[[ -d worker ]] && TARGETS+=(worker)

# 2) Détection d’assets autograding
section "2) Détection d’assets autograding"
{
  echo "- Présence worker.py :"
  find . -maxdepth 2 -type f -name "worker.py" 2>/dev/null | sed 's/^/  /' || true

  echo "- Présence dossiers worker/ et api/ :"
  [[ -d worker ]] && echo "  worker/" || echo "  (absent) worker/"
  [[ -d api ]] && echo "  api/" || echo "  (absent) api/"

  echo "- Indices d’endpoints /submissions (grep) :"
  if (( ${#TARGETS[@]} )); then
    grep -RIn "/submissions" "${TARGETS[@]}" 2>/dev/null | sed 's/^/  /' || true
  else
    echo "  (no api/ or worker/ to scan)"
  fi

  echo "- grep -RIn (mots-clés) sur api/ worker/ : autograd|grading|rubric|score|proof_bundle|run_id|upload_zip"
  if (( ${#TARGETS[@]} )); then
    grep -RInE "autograd|grading|rubric|score|proof_bundle|run_id|upload_zip" "${TARGETS[@]}" 2>/dev/null | sed 's/^/  /' || true
  else
    echo "  (no api/ or worker/ to scan)"
  fi
} >>"${REPORT_PATH}"

# 3) Détection d’assets labs
section "3) Détection d’assets labs"
{
  echo "- Présence dossiers labs/, schemas/, templates/, runners/, solana/*anchor* :"
  for d in labs schemas templates runners; do
    if [[ -d "$d" ]]; then echo "  $d/"; else echo "  (absent) $d/"; fi
  done
  # any directory path containing solana and anchor (in that order, within depth 4)
  find . -maxdepth 4 -type d -ipath "*solana*/*anchor*" 2>/dev/null | sed 's/^/  /' || true

  echo ""
  echo "- find . -maxdepth 4 -type f with patterns: *lab* *schema* *runner* *anchor* *solana*"
  find . -maxdepth 4 -type f \( -iname "*lab*" -o -iname "*schema*" -o -iname "*runner*" -o -iname "*anchor*" -o -iname "*solana*" \) 2>/dev/null | sort | sed 's/^/  /' || true
} >>"${REPORT_PATH}"

# 4) Détection de scripts/outils disponibles
section "4) Détection de scripts/outils disponibles"
{
  echo "- ls -la tools/ :"
  ls -la tools 2>/dev/null | sed 's/^/  /' || echo "  (tools/ absent)"
  echo "- ls -la tools/steps/ :"
  ls -la tools/steps 2>/dev/null | sed 's/^/  /' || echo "  (tools/steps/ absent)"
  echo "- Présence tools/verify.sh : $([[ -f tools/verify.sh ]] && echo yes || echo no)"
  echo "- Présence tools/verify.spec : $([[ -f tools/verify.spec ]] && echo yes || echo no)"
} >>"${REPORT_PATH}"

# 5) Résumé final
section "5) Résumé final"
{
  # AUTOGRADING assets heuristic
  has_worker_py=$(find . -maxdepth 2 -type f -name "worker.py" 2>/dev/null | wc -l | tr -d ' ' || true)
  has_worker_dir=$([[ -d worker ]] && echo 1 || echo 0)
  has_api_dir=$([[ -d api ]] && echo 1 || echo 0)
  subm_count=0
  if (( ${#TARGETS[@]} )); then
    subm_count=$(grep -RIn "/submissions" "${TARGETS[@]}" 2>/dev/null | wc -l | tr -d ' ' || true)
  fi
  grep_keys_count=0
  if (( ${#TARGETS[@]} )); then
    grep_keys_count=$(grep -RInE "autograd|grading|rubric|score|proof_bundle|run_id|upload_zip" "${TARGETS[@]}" 2>/dev/null | wc -l | tr -d ' ' || true)
  fi
  if [[ "${has_worker_py}" != "0" || "${has_worker_dir}" == "1" || "${has_api_dir}" == "1" || "${subm_count}" != "0" || "${grep_keys_count}" != "0" ]]; then
    AUTOGRADING_ASSETS=yes
  else
    AUTOGRADING_ASSETS=no
  fi

  # LABS assets heuristic
  labs_dirs_count=0
  for d in labs schemas templates runners; do [[ -d "$d" ]] && labs_dirs_count=$((labs_dirs_count+1)); done
  sol_anchor_dirs=$(find . -maxdepth 4 -type d -ipath "*solana*/*anchor*" 2>/dev/null | wc -l | tr -d ' ' || true)
  labs_files=$(find . -maxdepth 4 -type f \( -iname "*lab*" -o -iname "*schema*" -o -iname "*runner*" -o -iname "*anchor*" -o -iname "*solana*" \) 2>/dev/null | wc -l | tr -d ' ' || true)
  if [[ "$labs_dirs_count" != "0" || "$sol_anchor_dirs" != "0" || "$labs_files" != "0" ]]; then
    LABS_ASSETS=yes
  else
    LABS_ASSETS=no
  fi

  echo "AUTOGRADING_ASSETS: ${AUTOGRADING_ASSETS}"
  if [[ "${AUTOGRADING_ASSETS}" == "yes" ]]; then
    echo "  paths:"
    find . -maxdepth 2 -type f -name "worker.py" 2>/dev/null | sed 's/^/    /' || true
    [[ -d worker ]] && echo "    worker/"
    [[ -d api ]] && echo "    api/"
    if (( ${#TARGETS[@]} )); then
      grep -RIn "/submissions" "${TARGETS[@]}" 2>/dev/null | cut -d: -f1 | sort -u | sed 's/^/    /' || true
    fi
  fi

  echo "LABS_ASSETS: ${LABS_ASSETS}"
  if [[ "${LABS_ASSETS}" == "yes" ]]; then
    echo "  dirs:"
    for d in labs schemas templates runners; do [[ -d "$d" ]] && echo "    $d/"; done
    find . -maxdepth 4 -type d -ipath "*solana*/*anchor*" 2>/dev/null | sed 's/^/    /' || true
    echo "  files(patterns):"
    find . -maxdepth 4 -type f \( -iname "*lab*" -o -iname "*schema*" -o -iname "*runner*" -o -iname "*anchor*" -o -iname "*solana*" \) 2>/dev/null | sort | sed 's/^/    /' || true
  fi

  echo "API_ENDPOINT_HINTS:"
  if [[ -d api ]]; then
    # Try common Python web frameworks route patterns (explicit variants only, avoid regex parens)
    { grep -RIn '@app.get("/' api 2>/dev/null || true; \
      grep -RIn '@app.post("/' api 2>/dev/null || true; \
      grep -RIn '@app.put("/' api 2>/dev/null || true; \
      grep -RIn '@app.delete("/' api 2>/dev/null || true; \
      grep -RIn '@app.patch("/' api 2>/dev/null || true; \
      grep -RIn '@router.get("/' api 2>/dev/null || true; \
      grep -RIn '@router.post("/' api 2>/dev/null || true; \
      grep -RIn '@router.put("/' api 2>/dev/null || true; \
      grep -RIn '@router.delete("/' api 2>/dev/null || true; \
      grep -RIn '@router.patch("/' api 2>/dev/null || true; \
      grep -RIn '\.route\("/' api 2>/dev/null || true; \
      grep -RIn 'path="/' api 2>/dev/null || true; \
      grep -RInE '/health|/submissions|/rag' api 2>/dev/null || true; } \
    | sed -E 's/.*\"(\/[^"]+)\".*/\1/' | sed 's/^/  - /' | sort -u || true
  else
    echo "  (api/ absent)"
  fi

  echo "NOTES:"
  echo "  - NO-CHANGE step: only generated report at ${REPORT_PATH}"
  echo "  - Review findings to drive AUTOGRADING.md and LABS.md without assumptions"
} >>"${REPORT_PATH}"

# Emit the report path for the runner log
echo "REPORT_PATH=${REPORT_PATH}"