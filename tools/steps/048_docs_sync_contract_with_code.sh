#!/usr/bin/env bash
# STEP 048 — docs_sync_contract_with_code (DOC CHANGE)
# But: mettre à jour CONTRACT_CANON.md + SPEC.md + AUTOGRADING.md + LABS.md pour refléter EXACTEMENT les endpoints réels.
# Règle: ne pas mentionner /rag/query si absent dans le code actuel.
# Preuves: sha256 avant/après; grep endpoints dans docs; absence /rag/query; verify PASS.

set -euo pipefail

TS=$(date +%Y%m%d_%H%M%S)
LOG="tools/logs/048_docs_sync_${TS}.txt"
mkdir -p tools/logs

sha() { if [[ -f "$1" ]]; then sha256sum "$1" | awk '{print $1}'; else echo "(absent)"; fi }

DOCS=(
  CONTRACT_CANON.md
  SPEC.md
  AUTOGRADING.md
  LABS.md
)

ENDPOINTS=$(cat <<'TXT'
- GET /health
- POST /submissions/upload_zip
- GET /submissions/{submission_id}
- GET /runs/{run_id}
- GET /proofs/{proof_bundle_id}
TXT
)

{
  echo "[INFO] STEP 048 @ ${TS}"
  echo "== SHA BEFORE =="
  for f in "${DOCS[@]}"; do echo "$f: $(sha "$f")"; done

  echo
  echo "== PATCH docs endpoints blocks =="
  python3 - <<'PY'
from pathlib import Path
import re

docs = [Path('CONTRACT_CANON.md'), Path('SPEC.md'), Path('AUTOGRADING.md'), Path('LABS.md')]
block_hdr = '## Endpoints (synchronised)'
start_tag = '<!-- BEGIN:SYNC_ENDPOINTS -->'
end_tag = '<!-- END:SYNC_ENDPOINTS -->'
block_body = '\n'.join([
    start_tag,
    '',
    '- GET /health',
    '- POST /submissions/upload_zip',
    '- GET /submissions/{submission_id}',
    '- GET /runs/{run_id}',
    '- GET /proofs/{proof_bundle_id}',
    '',
    end_tag,
])

for p in docs:
    if not p.exists():
        print(f'SKIP {p} (missing)');
        continue
    s = p.read_text(encoding='utf-8')
    # Remove any /rag/query mention in this doc
    s = re.sub(r'^.*?/rag/query.*?$\n?', '', s, flags=re.MULTILINE)
    # If block already present, replace it
    if start_tag in s and end_tag in s:
        s = re.sub(rf'{re.escape(start_tag)}.*?{re.escape(end_tag)}', block_body, s, flags=re.DOTALL)
    else:
        # Try to insert after an existing Endpoints header, else append near top after first H2 or at end
        idx = s.lower().find('\n## endpoints')
        if idx != -1:
            # Insert after that line
            head = s[:idx]
            tail = s[idx:]
            # Find end of that header line
            line_end = tail.find('\n')
            if line_end == -1:
                s = head + tail + '\n' + block_body + '\n'
            else:
                s = head + tail[:line_end+1] + block_body + '\n' + tail[line_end+1:]
        else:
            # Insert a new section near top, after first heading line if present
            lines = s.splitlines(True)
            insert_at = 1
            if lines and lines[0].startswith('#'):
                insert_at = 1
            s = ''.join(lines[:insert_at]) + f"\n{block_hdr}\n{block_body}\n\n" + ''.join(lines[insert_at:])
    p.write_text(s, encoding='utf-8')
    print(f'PATCHED {p}')
PY

  echo
  echo "== SHA AFTER =="
  for f in "${DOCS[@]}"; do echo "$f: $(sha "$f")"; done

  echo
  echo "== GREP endpoints in docs =="
  for f in "${DOCS[@]}"; do echo "-- $f"; grep -nE '/(health|submissions|runs|proofs)' "$f" || true; done

  echo
  echo "== Ensure /rag/query is absent in these docs =="
  for f in "${DOCS[@]}"; do echo "-- $f"; ! grep -nE '/rag/query' "$f" && echo ABSENT || true; done

  echo
  echo "== VERIFY HARNESS =="
  if [[ -x tools/verify.sh ]]; then
    tools/verify.sh --spec tools/verify.spec || true
  elif [[ -f tools/verify.sh ]]; then
    bash tools/verify.sh --spec tools/verify.spec || true
  else
    echo "(no verify harness found)"
  fi
} | tee "$LOG"

echo "STOP."