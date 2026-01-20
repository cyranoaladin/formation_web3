#!/usr/bin/env bash
# Step 034 — reveal_secrets_matches_safely (NO-CHANGE)
# Goal: extract SECRETS_MATCH entries from the specified audit report and print redacted snippets.
# No file edits. No git add. No commit.

set -euo pipefail

REPORT_INPUT="tools/logs/untracked_audit_20260120_000026.txt"
TS="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="tools/logs"
OUT_PATH="${OUT_DIR}/secrets_matches_redacted_${TS}.txt"
mkdir -p "$OUT_DIR"

if [[ ! -f "$REPORT_INPUT" ]]; then
  echo "ERROR: audit report not found: $REPORT_INPUT" >&2
  exit 1
fi

# Collect matches (path:line)
mapfile -t MATCHES < <(grep -n '^SECRETS_MATCH: ' "$REPORT_INPUT" | sed 's/^[0-9]\+:SECRETS_MATCH: //')

{
  echo "# Secrets Matches (Redacted)"
  echo "source_report: $REPORT_INPUT"
  echo "generated_at: $(date -Iseconds)"
  echo "count: ${#MATCHES[@]}"
  echo ""
  echo "## 1) Raw matches (path:line)"
  if (( ${#MATCHES[@]} == 0 )); then
    echo "(none)"
  else
    printf '%s\n' "${MATCHES[@]}"
  fi
  echo ""
  echo "## 2) Redacted snippets"
} >"$OUT_PATH"

# Redaction via Python to keep only safe context
REPORT_INPUT="$REPORT_INPUT" python3 - "$OUT_PATH" <<'PY'
import sys, re, os
from pathlib import Path
out_path = Path(sys.argv[1])
content = out_path.read_text(encoding='utf-8', errors='ignore')
lines = content.splitlines()
# Extract matches from section 1 we just wrote
raw = []
try:
    start = lines.index('## 1) Raw matches (path:line)') + 1
except ValueError:
    start = 0
for i in range(start, len(lines)):
    if lines[i].startswith('## 2)'):
        break
    line = lines[i].strip()
    if not line or line.startswith('#'):
        continue
    m = re.match(r'^(.+):(\d+)$', line)
    if m:
        raw.append((m.group(1), int(m.group(2))))

def redact(s: str) -> str:
    # Mask URI creds
    s = re.sub(r'(mongodb\+srv://)[^\s\'\"]+', r'\1***', s)
    # Mask assignments VAR=VALUE or key: value after sensitive keywords
    s = re.sub(r'((?:OPENAI|API_KEY|SECRET|TOKEN|PASSWORD|AWS_|GCP_|PRIVATE|oauth)[^:=]{0,40}[:=]\s*)([^,\s\'\"]+)', r'\1***', s, flags=re.I)
    # Mask quoted values after sensitive keywords
    s = re.sub(r'((?:OPENAI|API_KEY|SECRET|TOKEN|PASSWORD|AWS_|GCP_|PRIVATE|oauth)[^\'\"]{0,40}[\'\"])([^\'\"]+)([\'\"])', r'\1***\3', s, flags=re.I)
    # Collapse whitespace and limit length
    s = ' '.join(s.strip().split())
    if len(s) > 200:
        s = s[:200] + '…'
    return s

with out_path.open('a', encoding='utf-8') as out:
    if not raw:
        out.write("(no matches)\n")
    for path, lineno in raw:
        # Read the specific line
        try:
            with open(path, 'r', encoding='utf-8', errors='ignore') as fh:
                for i, line in enumerate(fh, start=1):
                    if i == lineno:
                        snippet = redact(line)
                        out.write(f"MATCH: {path}:{lineno}\n")
                        out.write(f"SNIPPET: {snippet}\n")
                        break
        except Exception as e:
            out.write(f"MATCH: {path}:{lineno}\n")
            out.write("SNIPPET: [unreadable or missing]***\n")
PY

echo "REPORT_PATH=${OUT_PATH}"