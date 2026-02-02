#!/usr/bin/env bash
set -euo pipefail

API_URL="http://localhost:8000"

log() {
  echo "[audit] $*"
}

log "starting stack"
docker compose up -d

log "waiting for API health"
healthy=0
for i in $(seq 1 60); do
  if curl -sS -m 2 "${API_URL}/health" >/dev/null 2>&1; then
    healthy=1
    break
  fi
  sleep 2
done
if [[ "$healthy" -ne 1 ]]; then
  echo "API health check failed" >&2
  exit 1
fi

log "upload hello-proof"
RESP="$(curl -sS -F student_id=stu_audit -F lab_id=hello-proof -F file=@tests/fixtures/minimal.zip ${API_URL}/submissions/upload_zip)"
echo "$RESP"

SUB_ID="$(echo "$RESP" | python3 -c 'import sys,json; print(json.load(sys.stdin)["submission_id"])')"
if [[ -z "$SUB_ID" ]]; then
  echo "missing submission_id" >&2
  exit 1
fi

log "poll submission status"
STATUS=""
for i in $(seq 1 120); do
  S="$(curl -sS ${API_URL}/submissions/${SUB_ID})"
  STATUS="$(echo "$S" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("status",""))')"
  if [[ "$STATUS" != "queued" && "$STATUS" != "running" && "$STATUS" != "uploaded" ]]; then
    echo "$S"
    break
  fi
  sleep 2
done

if [[ "$STATUS" != "completed" ]]; then
  echo "unexpected status: $STATUS" >&2
  exit 1
fi

S_FINAL="$(curl -sS ${API_URL}/submissions/${SUB_ID})"
PROOF_ID="$(echo "$S_FINAL" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("proof_bundle_id",""))')"
if [[ -z "$PROOF_ID" || "$PROOF_ID" == "None" ]]; then
  echo "missing proof_bundle_id" >&2
  exit 1
fi

log "validate proof bundle"
curl -sS "${API_URL}/proofs/${PROOF_ID}" | python3 -c 'import json,sys; payload=json.load(sys.stdin); \
    (payload.get("decision_hint")=="validated") or (print("decision_hint invalid", file=sys.stderr) or sys.exit(1)); \
    ("auto" in payload.get("score", {})) or (print("missing score.auto", file=sys.stderr) or sys.exit(1)); \
    print("proof_validated=ok")'

log "verify proof in Mongo"
COUNT="$(docker compose exec -T mongo mongosh "mongodb://mongo:27017/rbk_labs" --quiet --eval "db.proof_bundles.countDocuments({proof_bundle_id: '${PROOF_ID}'})")"
COUNT="${COUNT//[^0-9]/}"
if [[ -z "$COUNT" || "$COUNT" -lt 1 ]]; then
  echo "proof not found in db" >&2
  exit 1
fi

log "SYSTEM VALIDATED"
