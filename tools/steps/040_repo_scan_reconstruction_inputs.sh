#!/usr/bin/env bash
# STEP 040 — repo_scan_reconstruction_inputs (NO-CHANGE)
# But: scanner le repo pour décider où patcher (aucune modification).
# Sortie: tools/logs/reconstruction_scan_YYYYMMDD_HHMMSS.txt
# Preuves: extrait (l.1-60) + verify PASS

set -euo pipefail

TS=$(date +%Y%m%d_%H%M%S)
LOG_DIR="tools/logs"
LOG_FILE="${LOG_DIR}/reconstruction_scan_${TS}.txt"
mkdir -p "$LOG_DIR"

sha() { if [[ -f "$1" ]]; then sha256sum "$1" | awk '{print $1}'; else echo "(absent)"; fi }

{
  echo "[INFO] reconstruction scan @ ${TS}"
  echo
  echo "== repo root =="
  ls -la | sed -n '1,200p'

  echo
  echo "== docker-compose.yml : services/ports/env =="
  if [[ -f docker-compose.yml ]]; then
    echo "-- sha256: $(sha docker-compose.yml)"
    echo "-- docker compose ps --"
    docker compose ps || true
    echo "-- docker-compose.yml (excerpt) --"
    sed -n '1,200p' docker-compose.yml
    echo "-- docker compose config (excerpt) --"
    docker compose config | sed -n '1,200p' || true
  else
    echo "(missing) docker-compose.yml"
  fi

  echo
  echo "== api/app/main.py : routes détectées =="
  if [[ -f api/app/main.py ]]; then
    echo "-- sha256: $(sha api/app/main.py)"
    grep -nE '@app\.(get|post|put|delete)\("[^"]*"\)' api/app/main.py || echo '(no routes found)'
  else
    echo "(missing) api/app/main.py"
  fi

  echo
  echo "== worker/worker.py : structure =="
  if [[ -f worker/worker.py ]]; then
    echo "-- sha256: $(sha worker/worker.py)"
    grep -nE "def main\(|while True|find_one_and_update|update_one|insert_one" worker/worker.py || true
  else
    echo "(missing) worker/worker.py"
  fi

  echo
  echo "== schemas/canonical : présence + champs =="
  if [[ -d schemas/canonical ]]; then
    ls -l schemas/canonical | sed -n '1,200p'
    python3 - <<'PY'
import json,glob,os
for p in sorted(glob.glob('schemas/canonical/*.json')):
    try:
        j=json.load(open(p,'r',encoding='utf-8'))
        req=j.get('required')
        props=list((j.get('properties') or {}).keys())
        print(f"[schema] {os.path.basename(p)} required={req if isinstance(req,list) else 'n/a'} properties={props}")
    except Exception as e:
        print(f"[schema] {p} ERROR {e}")
PY
  else
    echo "(missing) schemas/canonical/"
  fi

  echo
  echo "== labs : contenu (tree <=3) =="
  if [[ -d labs ]]; then
    find labs -maxdepth 3 -printf '%y %p\n' | sed -n '1,200p'
  else
    echo "(missing) labs/"
  fi

  echo
  echo "== runner : contenu =="
  if [[ -d runner ]]; then
    find runner -maxdepth 2 -printf '%y %p\n' | sed -n '1,200p'
  else
    echo "(missing) runner/"
  fi

  echo
  echo "== SHA256 snapshot (NO-CHANGE step) =="
  for f in docker-compose.yml api/app/main.py worker/worker.py; do
    echo "BEFORE ${f}: $(sha "$f")"
    echo "AFTER  ${f}: $(sha "$f")"
  done

  echo
  echo "== verify harness =="
  if [[ -x tools/verify.sh ]]; then
    tools/verify.sh --spec tools/verify.spec || true
  elif [[ -f tools/verify.sh ]]; then
    bash tools/verify.sh --spec tools/verify.spec || true
  else
    echo "(no verify harness found)"
  fi
} >"$LOG_FILE"

# Preuve: extrait 1..60
sed -n '1,60p' "$LOG_FILE"
