#!/usr/bin/env bash
# Step 032 — fix_untracked_blockers (minimal, safe)
# Scope: update .gitignore with common artifacts; patch 031 audit script to avoid noisy secrets matches.
# No deletions, no git add, no commit.

set -euo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="tools/logs"
LOG_PATH="${LOG_DIR}/fix_untracked_blockers_${TS}.txt"
mkdir -p "${LOG_DIR}"

GI=".gitignore"
AUD="tools/steps/031_audit_untracked_no_change.sh"

pre_sha_gi="$(sha256sum "$GI" 2>/dev/null | awk '{print $1}')" || true
[[ -z "${pre_sha_gi:-}" ]] && pre_sha_gi="(absent)"
pre_sha_aud="$(sha256sum "$AUD" 2>/dev/null | awk '{print $1}')" || true
[[ -z "${pre_sha_aud:-}" ]] && pre_sha_aud="(absent)"

# 1) Update .gitignore idempotently
PY_GI='import sys
from pathlib import Path
p=Path(".gitignore")
cur=set()
if p.exists():
    cur={line.rstrip("\n") for line in p.read_text(encoding="utf-8", errors="ignore").splitlines()}
need=[
    "ui/node_modules/",
    "**/__pycache__/",
    "*.pyc",
    "dist/",
    "build/",
    ".cache/",
    ".pytest_cache/",
    ".env",
    ".env.*",
    "*.pem",
    "*.key",
]
added=[]
for line in need:
    if line not in cur:
        added.append(line)
if added:
    with p.open("a", encoding="utf-8") as f:
        if p.stat().st_size > 0:
            f.write("\n")
        f.write("# Added by tools/steps/032_fix_untracked_blockers.sh\n")
        for line in added:
            f.write(line+"\n")
print("ADDED_COUNT=",len(added))
'

add_out="$(python3 -c "$PY_GI")"
ADDED_COUNT=$(echo "$add_out" | awk -F= '/ADDED_COUNT/{print $2+0}')

# 2) Patch audit script to exclude self and caches in secrets scan (idempotent)
if [[ -f "$AUD" ]]; then
  python3 - "$AUD" <<'PY'
import sys, re
from pathlib import Path
fp=Path(sys.argv[1])
s=fp.read_text(encoding='utf-8', errors='ignore')
old=s
# Strengthen UNTRACKED_SCAN exclude to also drop this audit script explicitly
pat=r"git ls-files --others --exclude-standard \| grep -vE '([^']*)'\)"
# More explicit replace on the exact line used in step 031
s=s.replace(
    "git ls-files --others --exclude-standard | grep -vE '(^|/)node_modules(/|$)|(^|/)dist(/|$)|(^|/)__pycache__(/|$)|(^|/)\\.venv(/|$)|(^|/)tools/logs(/|$)'",
    "git ls-files --others --exclude-standard | grep -vE '(^|/)node_modules(/|$)|(^|/)dist(/|$)|(^|/)__pycache__(/|$)|(^|/)\\.venv(/|$)|(^|/)tools/logs(/|$)|(^|)tools/steps/031_audit_untracked_no_change\\.sh$'"
)
if s!=old:
    fp.write_text(s, encoding='utf-8')
print("PATCHED=", int(s!=old))
PY
else
  echo "PATCHED=0"
fi

post_sha_gi="$(sha256sum "$GI" 2>/dev/null | awk '{print $1}')" || true
post_sha_aud="$(sha256sum "$AUD" 2>/dev/null | awk '{print $1}')" || true

{
  echo "GI_PRE_SHA256=$pre_sha_gi"
  echo "GI_POST_SHA256=$post_sha_gi"
  echo "AUD_PRE_SHA256=$pre_sha_aud"
  echo "AUD_POST_SHA256=$post_sha_aud"
  echo "GITIGNORE_ADDED=$ADDED_COUNT"
} >"$LOG_PATH"

echo "LOG_PATH=${LOG_PATH}"

# Proof snippets
echo "--- .gitignore (tail) ---"
tail -n 40 .gitignore 2>/dev/null || true

echo "--- audit script (secrets scan block excerpt) ---"
nl -ba "$AUD" | sed -n '60,120p' 2>/dev/null || true