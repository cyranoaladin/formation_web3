#!/usr/bin/env bash
# STEP 044a — fix_proof_schema_artifacts (CODE CHANGE)
# But: ouvrir artifacts dans proof_bundle.schema.json pour autoriser result.json
# Preuves: sha avant/après, extrait JSON, test court d'upload + GET proof

set -euo pipefail

TS=$(date +%Y%m%d_%H%M%S)
LOG="tools/logs/044a_fix_schema_${TS}.txt"
mkdir -p tools/logs

SCHEMA="schemas/canonical/proof_bundle.schema.json"
FIXTURE="tests/fixtures/minimal.zip"

sha() { if [[ -f "$1" ]]; then sha256sum "$1" | awk '{print $1}'; else echo "(absent)"; fi }

{
  echo "[INFO] STEP 044a @ ${TS}"
  echo "== SHA BEFORE =="
  echo "proof_bundle.schema.json: $(sha "$SCHEMA")"

  echo
  echo "== PATCH artifacts -> open object =="
  python3 - <<'PY'
import json
from pathlib import Path
p=Path('schemas/canonical/proof_bundle.schema.json')
j=json.load(p.open('r',encoding='utf-8'))
props=j.get('properties') or {}
arts=props.get('artifacts') or {}
# Force open object
arts={'type':'object'}
props['artifacts']=arts
j['properties']=props
json.dump(j,p.open('w',encoding='utf-8'),ensure_ascii=False,indent=2)
print('PATCHED artifacts to open object')
PY

  echo
  echo "== SHA AFTER =="
  echo "proof_bundle.schema.json: $(sha "$SCHEMA")"

  echo
  echo "== docker compose up (no rebuild needed) =="
  docker compose up -d api worker mongo
  docker compose ps || true

  echo
  echo "== quick check: upload + poll + proof =="
  if [[ ! -f "$FIXTURE" ]]; then echo "(fixture missing) $FIXTURE"; exit 2; fi
  U=/tmp/044a_u.json; S=/tmp/044a_s.json; R=/tmp/044a_r.json; P=/tmp/044a_p.json
  curl -sS -o "$U" -w "HTTP=%{http_code}\n" -F file=@"$FIXTURE" -F student_id=stu_044a -F lab_id=hello-proof http://localhost:8000/submissions/upload_zip
  SUB=$(python3 - <<'PY'
import json;print(json.load(open('/tmp/044a_u.json')).get('submission_id',''))
PY
  )
  for i in $(seq 1 60); do
    curl -sS -o "$S" http://localhost:8000/submissions/$SUB >/dev/null || true
    st=$(python3 - <<'PY'
import json;print(json.load(open('/tmp/044a_s.json')).get('status',''))
PY
    )
    [[ "$st" != "queued" && "$st" != "running" && -n "$st" ]] && break
    sleep 1
  done
  RUN=$(python3 - <<'PY'
import json;print(json.load(open('/tmp/044a_s.json')).get('latest_run_id','') or json.load(open('/tmp/044a_s.json')).get('run_id',''))
PY
  )
  curl -sS -o "$R" http://localhost:8000/runs/$RUN >/dev/null || true
  PF=$(python3 - <<'PY'
import json;print(json.load(open('/tmp/044a_r.json')).get('proof_bundle_id',''))
PY
  )
  curl -sS -o "$P" http://localhost:8000/proofs/$PF >/dev/null || true
  echo "proof_bundle_id=$PF"
  grep -n '"result"' "$P" || true

} | tee "$LOG"

echo "STOP."