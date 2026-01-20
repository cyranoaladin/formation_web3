#!/usr/bin/env bash
# Step 031 — audit_untracked_no_change (NO-CHANGE)
# Goal: Audit untracked files/dirs for secrets, caches, large files. No edits, no git add, no commits.

set -euo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="tools/logs"
REPORT_PATH="${REPORT_DIR}/untracked_audit_${TS}.txt"
mkdir -p "${REPORT_DIR}"

section(){
  echo "" >>"$REPORT_PATH"
  echo "## $1" >>"$REPORT_PATH"
}

# Header
{
  echo "# Untracked Audit Report"
  echo "generated_at: $(date -Iseconds)"
  echo "cwd: $(pwd)"
} >"$REPORT_PATH"

# 1) Current git status
section "1) git status --porcelain"
{
  git status --porcelain || true
} >>"$REPORT_PATH"

# Collect untracked
mapfile -t UNTRACKED < <(git ls-files --others --exclude-standard)

section "2) Untracked paths (git ls-files --others --exclude-standard)"
{
  if (( ${#UNTRACKED[@]} == 0 )); then
    echo "(none)"
  else
    printf '%s\n' "${UNTRACKED[@]}"
  fi
} >>"$REPORT_PATH"

# 3) Top-level untracked directories scan
section "3) Top-level untracked directories overview"
{
  if (( ${#UNTRACKED[@]} == 0 )); then
    echo "(none)"
  else
    # derive top-level dirs
    TOP_DIRS=$(printf '%s\n' "${UNTRACKED[@]}" | awk -F/ 'NF>1{print $1}' | sort -u)
    if [[ -z "${TOP_DIRS}" ]]; then
      echo "(no top-level directories)"
    else
      for d in ${TOP_DIRS}; do
        if [[ -d "$d" ]]; then
          echo "- DIR: $d"
          echo "  files (depth<=2, up to 50):"
          find "$d" -maxdepth 2 -type f 2>/dev/null | head -n 50 | sed 's/^/    /' || true
          cnt=$(find "$d" -type f 2>/dev/null | wc -l | tr -d ' ')
          echo "  total_files: $cnt"
        fi
      done
    fi
  fi
} >>"$REPORT_PATH"

# 4) Secrets scan (untracked only)
section "4) Secrets scan (untracked paths only)"
{
  PATTERN='BEGIN PRIVATE KEY|OPENAI|API_KEY|SECRET|TOKEN|PASSWORD|mongodb\+srv|AWS_|GCP_|PRIVATE|oauth'
  if (( ${#UNTRACKED[@]} == 0 )); then
    echo "SECRETS_MATCHES: 0"
  else
    # Build filtered untracked list (exclude common caches to reduce false positives)
    mapfile -t UNTRACKED_SCAN < <(git ls-files --others --exclude-standard | grep -vE '(^|/)tools/steps(/|$)|(^|/)\.git(/|$)|(^|/)\.warp(/|$)|(^|/)tools/logs(/|$)|(^|/)node_modules(/|$)|(^|/)dist(/|$)|(^|/)build(/|$)|(^|/)__pycache__(/|$)|(^|/)\.venv(/|$)')
    if (( ${#UNTRACKED_SCAN[@]} == 0 )); then
      echo "SECRETS_MATCHES: 0"
    else
      printf '%s\0' "${UNTRACKED_SCAN[@]}" \
        | xargs -0 -r grep -RInE "$PATTERN" 2>/dev/null \
        | cut -d: -f1-2 | sort -u \
        | sed 's/^/SECRETS_MATCH: /' >>"$REPORT_PATH" || true || true || true
      # Count
      sm=$(grep -c '^SECRETS_MATCH: ' "$REPORT_PATH" || true)
      echo "SECRETS_MATCHES: ${sm}" >>"$REPORT_PATH"
    fi
  fi
} >>"$REPORT_PATH"

# 5) Size scan (largest untracked entries)
section "5) Size scan (top 20 largest untracked entries)"
{
  if (( ${#UNTRACKED[@]} == 0 )); then
    echo "(none)"
    echo "SIZE_GT_5MB: 0"
  else
    duout=$(git ls-files --others --exclude-standard -z | xargs -0 -r du -ah 2>/dev/null | sort -hr | head -n 20 || true)
    if [[ -n "$duout" ]]; then
      echo "$duout"
      # flag >5MB lines
      big=$(printf '%s\n' "$duout" | awk '
        function toMB(s) {
          n=s; u=substr(s, length(s), 1);
          gsub(/[^0-9.]/, "", n);
          if (u=="G") return n*1024; else if (u=="M") return n+0; else if (u=="K") return n/1024; else return 0;
        }
        { if(toMB($1) > 5) print $0; }')
      if [[ -n "$big" ]]; then
        echo ""
        echo "$big" | sed 's/^/SIZE_GT_5MB: /'
        echo "SIZE_GT_5MB_COUNT: $(printf '%s\n' "$big" | wc -l | tr -d ' ')"
      else
        echo "SIZE_GT_5MB: 0"
      fi
    else
      echo "(none)"
      echo "SIZE_GT_5MB: 0"
    fi
  fi
} >>"$REPORT_PATH"

# 6) SUMMARY
section "6) SUMMARY"
{
  # detect caches in untracked
  caches=()
  sugg=()
  # base suggestions on raw list for reliability
  UNTRACKED_TEXT=$(git ls-files --others --exclude-standard || true)
  if printf '%s\n' "$UNTRACKED_TEXT" | grep -qE '(^|/)node_modules(/|$)'; then caches+=(node_modules); sugg+=(node_modules/); fi
  if printf '%s\n' "$UNTRACKED_TEXT" | grep -qE '(^|/)dist(/|$)'; then caches+=(dist); sugg+=(dist/); fi
  if printf '%s\n' "$UNTRACKED_TEXT" | grep -qE '__pycache__'; then caches+=(__pycache__); sugg+=(**/__pycache__/); fi
  if printf '%s\n' "$UNTRACKED_TEXT" | grep -qE '(^|/)\\.venv(/|$)'; then caches+=(.venv); sugg+=(.venv/); fi
  if printf '%s\n' "$UNTRACKED_TEXT" | grep -qE '(^|/)logs(/|$)'; then caches+=(logs); sugg+=(logs/); fi

  secrets_cnt=$(grep -E '^SECRETS_MATCHES:' "$REPORT_PATH" | tail -n1 | awk '{print $2+0}' || true)
  big_cnt=$(grep -E '^SIZE_GT_5MB_COUNT:' "$REPORT_PATH" | tail -n1 | awk '{print $2+0}' || true)
  [[ -z "$secrets_cnt" ]] && secrets_cnt=0
  [[ -z "$big_cnt" ]] && big_cnt=0

  blockers=()
  (( secrets_cnt > 0 )) && blockers+=(secrets)
  (( big_cnt > 0 )) && blockers+=(large_files)
  (( ${#caches[@]} > 0 )) && blockers+=(caches)

  if (( ${#blockers[@]} == 0 )); then
    echo "OK_TO_COMMIT: yes"
    echo "BLOCKERS: (none)"
  else
    echo "OK_TO_COMMIT: no"
    echo "BLOCKERS: ${blockers[*]}"
  fi

  echo "SECRETS_MATCHES: $secrets_cnt"
  echo "SIZE_GT_5MB: $big_cnt"

  if (( ${#sugg[@]} > 0 )); then
    echo "SUGGESTED_GITIGNORE_ADDITIONS: ${sugg[*]}"
  else
    echo "SUGGESTED_GITIGNORE_ADDITIONS: (none)"
  fi
} >>"$REPORT_PATH"

# Emit report path for proofs
echo "REPORT_PATH=${REPORT_PATH}"