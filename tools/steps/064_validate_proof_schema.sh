#!/usr/bin/env bash
set -euo pipefail

curl -sS -m 3 http://localhost:8000/health >/dev/null

RESP="$(curl -sS -F student_id=stu_schema -F lab_id=hello-proof -F file=@tests/fixtures/minimal.zip http://localhost:8000/submissions/upload_zip)"
echo "$RESP"

SUB_ID="$(echo "$RESP" | python3 -c 'import sys,json; print(json.load(sys.stdin)["submission_id"])')"

for i in $(seq 1 120); do
  S="$(curl -sS http://localhost:8000/submissions/${SUB_ID})"
  STATUS="$(echo "$S" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("status",""))')"
  if [[ "$STATUS" != "queued" && "$STATUS" != "running" && "$STATUS" != "uploaded" ]]; then
    echo "$S"
    break
  fi
  sleep 1
done

S="$(curl -sS http://localhost:8000/submissions/${SUB_ID})"
PROOF_ID="$(echo "$S" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("proof_bundle_id",""))')"

if [[ -z "$PROOF_ID" || "$PROOF_ID" == "None" ]]; then
  echo "missing proof_bundle_id" >&2
  exit 1
fi

docker compose exec -T api python - "$PROOF_ID" <<'PY'
import json
import sys
import urllib.request
import jsonschema

proof_id = sys.argv[1]
url = f"http://localhost:8000/proofs/{proof_id}"

with urllib.request.urlopen(url) as resp:
    payload = json.loads(resp.read().decode("utf-8"))

with open("/repo/schemas/canonical/proof_bundle.schema.json", "r", encoding="utf-8") as f:
    schema = json.load(f)

jsonschema.validate(instance=payload, schema=schema)
print("schema_validate=ok", proof_id)
PY
