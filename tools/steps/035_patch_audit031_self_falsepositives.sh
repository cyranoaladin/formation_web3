#!/usr/bin/env bash
# Step 035 — patch audit 031 to eliminate self-false-positives and always output OK_TO_COMMIT
# Scope: ONLY edit tools/steps/031_audit_untracked_no_change.sh. No other changes.

set -euo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
LOG="tools/logs/patch_audit031_${TS}.txt"
mkdir -p tools/logs

AUD="tools/steps/031_audit_untracked_no_change.sh"
PRE_SHA=$(sha256sum "$AUD" | awk '{print $1}')

python3 - "$AUD" <<'PY'
import sys, re
from pathlib import Path
p = Path(sys.argv[1])
src = p.read_text(encoding='utf-8', errors='ignore')
orig = src

# 1) Strengthen UNTRACKED_SCAN excludes (never scan tools/steps, .git, .warp, tools/logs, node_modules, dist, build, __pycache__, .venv)
exclude_new = (
    "mapfile -t UNTRACKED_SCAN < <(git ls-files --others --exclude-standard | grep -vE "
    "'(^|/)tools/steps(/|$)|(^|/)\\.git(/|$)|(^|/)\\.warp(/|$)|(^|/)tools/logs(/|$)|"
    "(^|/)node_modules(/|$)|(^|/)dist(/|$)|(^|/)build(/|$)|(^|/)__pycache__(/|$)|(^|/)\\.venv(/|$)')"
)
# Regex replace any existing exclude line for UNTRACKED_SCAN
src = re.sub(r"mapfile -t UNTRACKED_SCAN < <\(git ls-files --others --exclude-standard \| grep -vE '[^']*'\)", exclude_new, src, count=1)

# 2) Make secrets grep pipeline non-fatal (avoid set -e pipefail abort)
src = src.replace(
    "| sed 's/^/SECRETS_MATCH: /' >>\"$REPORT_PATH\"",
    "| sed 's/^/SECRETS_MATCH: /' >>\"$REPORT_PATH\" || true"
)
# Make summary grep pipelines tolerant
search1 = """secrets_cnt=$(grep -E '^SECRETS_MATCHES:' "$REPORT_PATH" | tail -n1 | awk '{print $2+0}' )"""
repl1   = """secrets_cnt=$(grep -E '^SECRETS_MATCHES:' "$REPORT_PATH" | tail -n1 | awk '{print $2+0}' || true)"""
src = src.replace(search1, repl1)
search2 = """big_cnt=$(grep -E '^SIZE_GT_5MB_COUNT:' "$REPORT_PATH" | tail -n1 | awk '{print $2+0}')"""
repl2   = """big_cnt=$(grep -E '^SIZE_GT_5MB_COUNT:' "$REPORT_PATH" | tail -n1 | awk '{print $2+0}' || true)"""
src = src.replace(search2, repl2)

# 3) Ensure SUMMARY always prints SECRETS_MATCHES and SIZE_GT_5MB counts (idempotent)
if "SECRETS_MATCHES: $secrets_cnt" not in src or "SIZE_GT_5MB: $big_cnt" not in src:
    src = src.replace(
        "echo \"BLOCKERS: ${blockers[*]}\"\n  fi\n\n  if (( ${#sugg[@]} > 0 )); then\n    echo \"SUGGESTED_GITIGNORE_ADDITIONS: ${sugg[*]}\"\n  else\n    echo \"SUGGESTED_GITIGNORE_ADDITIONS: (none)\"\n  fi\n} >>\"$REPORT_PATH\"",
        "echo \"BLOCKERS: ${blockers[*]}\"\n  fi\n\n  echo \"SECRETS_MATCHES: $secrets_cnt\"\n  echo \"SIZE_GT_5MB: $big_cnt\"\n\n  if (( ${#sugg[@]} > 0 )); then\n    echo \"SUGGESTED_GITIGNORE_ADDITIONS: ${sugg[*]}\"\n  else\n    echo \"SUGGESTED_GITIGNORE_ADDITIONS: (none)\"\n  fi\n} >>\"$REPORT_PATH\""
    )

if src != orig:
    p.write_text(src, encoding='utf-8')
print("PATCHED=1" if src!=orig else "PATCHED=0")
PY

POST_SHA=$(sha256sum "$AUD" | awk '{print $1}')
{
  echo "FILE=$AUD"
  echo "PRE_SHA=$PRE_SHA"
  echo "POST_SHA=$POST_SHA"
} > "$LOG"

echo "LOG_PATH=$LOG"