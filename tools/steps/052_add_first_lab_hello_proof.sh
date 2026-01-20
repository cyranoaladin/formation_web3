#!/usr/bin/env bash
# Step 052 — add_first_lab_hello_proof
# Goal: Create first lab spec "hello-proof" and validate it against canonical lab schema.
# Outputs: labs/specs/hello-proof/lab.json, labs/specs/hello-proof/README.md
# Proofs: print file heads, validate in API container (jsonschema), list tree, git status

set -euo pipefail

LAB_DIR="labs/specs/hello-proof"
LAB_JSON="$LAB_DIR/lab.json"
LAB_README="$LAB_DIR/README.md"

mkdir -p "$LAB_DIR"

# Write deterministic lab.json (idempotent)
cat >"$LAB_JSON" <<'JSON'
{
  "lab_id": "hello-proof",
  "title": "Hello Proof",
  "version": "0.1.0",
  "description": "Minimal lab used to prove the end-to-end submission→run→proof flow.",
  "visibility": "public",
  "rubric": "placeholder",
  "tags": ["hello", "proof", "demo"],
  "created_at": "2026-01-20T00:00:00Z",
  "updated_at": "2026-01-20T00:00:00Z"
}
JSON

# Minimal README (idempotent)
cat >"$LAB_README" <<'MD'
# Hello Proof (Lab)

A minimal lab spec to validate the pipeline: upload → worker → run → proof bundle.
MD

# Proof: show file headers
echo "--- head -n 40 $LAB_JSON ---"
sed -n '1,40p' "$LAB_JSON"

echo "--- head -n 20 $LAB_README ---"
sed -n '1,20p' "$LAB_README"

# Validate inside API container using canonical schema
set +e
docker compose exec -T api python - <<'PY'
import json, jsonschema
lab_schema = json.load(open('/repo/schemas/canonical/lab.schema.json'))
lab_doc = json.load(open('/repo/labs/specs/hello-proof/lab.json'))
jsonschema.validate(instance=lab_doc, schema=lab_schema)
print('HELLO_PROOF_LAB_VALIDATE=PASS')
PY
RC=$?
set -e

echo "VALIDATE_RC=${RC}"

# List tree for proof
echo "--- find labs/specs -maxdepth 3 ---"
find labs/specs -maxdepth 3 -printf '%y %p\n' | sed -n '1,200p'

# Git status for traceability
echo "--- git status --porcelain ---"
git status --porcelain | sed -n '1,200p'
