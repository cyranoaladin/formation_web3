#!/usr/bin/env bash
# Step 051 — add_lab_schemas_minimal
# Goal: Add canonical schemas for lab and labs_index. Validate with jsonschema inside API container.
# Effects: create/overwrite schemas/canonical/lab.schema.json and labs_index.schema.json
# Proofs: print schema heads, run validation with sample docs, show PASS markers, git status

set -euo pipefail

mkdir -p schemas/canonical

LAB_SCHEMA_PATH="schemas/canonical/lab.schema.json"
LABS_INDEX_SCHEMA_PATH="schemas/canonical/labs_index.schema.json"

cat >"${LAB_SCHEMA_PATH}" <<'JSON'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "rbk://schemas/canonical/lab.schema.json",
  "title": "RBK Lab (Canonical)",
  "type": "object",
  "additionalProperties": true,
  "required": ["lab_id", "title", "version", "visibility", "rubric", "created_at", "updated_at"],
  "properties": {
    "lab_id": { "type": "string", "pattern": "^[a-z0-9][a-z0-9_-]{1,63}$" },
    "title": { "type": "string", "minLength": 1, "maxLength": 200 },
    "version": { "type": "string", "pattern": "^\\d+\\.\\d+\\.\\d+$" },
    "description": { "type": "string" },
    "visibility": { "type": "string", "enum": ["public", "private"] },
    "rubric": { "type": "string", "minLength": 1, "maxLength": 128 },
    "tags": { "type": "array", "items": { "type": "string" } },
    "created_at": { "type": "string", "format": "date-time" },
    "updated_at": { "type": "string", "format": "date-time" }
  }
}
JSON

cat >"${LABS_INDEX_SCHEMA_PATH}" <<'JSON'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "rbk://schemas/canonical/labs_index.schema.json",
  "title": "RBK Labs Index (Canonical)",
  "type": "object",
  "additionalProperties": false,
  "required": ["labs"],
  "properties": {
    "labs": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": true,
        "required": ["lab_id", "title", "version", "visibility", "rubric"],
        "properties": {
          "lab_id": { "type": "string", "pattern": "^[a-z0-9][a-z0-9_-]{1,63}$" },
          "title": { "type": "string", "minLength": 1, "maxLength": 200 },
          "version": { "type": "string", "pattern": "^\\d+\\.\\d+\\.\\d+$" },
          "visibility": { "type": "string", "enum": ["public", "private"] },
          "rubric": { "type": "string", "minLength": 1, "maxLength": 128 }
        }
      }
    }
  }
}
JSON

# Show schema headers for proof
echo "--- head -n 20 ${LAB_SCHEMA_PATH} ---"
sed -n '1,20p' "${LAB_SCHEMA_PATH}"

echo "--- head -n 20 ${LABS_INDEX_SCHEMA_PATH} ---"
sed -n '1,20p' "${LABS_INDEX_SCHEMA_PATH}"

# Validate sample instances using jsonschema within API container (jsonschema already installed there)
cat >/tmp/lab_sample_051.json <<'JSON'
{
  "lab_id": "hello-proof",
  "title": "Hello Proof",
  "version": "0.1.0",
  "visibility": "public",
  "rubric": "placeholder",
  "created_at": "2026-01-20T00:00:00Z",
  "updated_at": "2026-01-20T00:00:00Z"
}
JSON

cat >/tmp/labs_index_sample_051.json <<'JSON'
{
  "labs": [
    {"lab_id": "hello-proof", "title": "Hello Proof", "version": "0.1.0", "visibility": "public", "rubric": "placeholder"}
  ]
}
JSON

# Copy samples into api container namespace for validation
set +e
docker compose cp /tmp/lab_sample_051.json api:/tmp/lab_sample_051.json >/dev/null 2>&1
COPIED1=$?
docker compose cp /tmp/labs_index_sample_051.json api:/tmp/labs_index_sample_051.json >/dev/null 2>&1
COPIED2=$?
set -e

echo "COPIED_SAMPLES_RC=${COPIED1},${COPIED2}"

echo "--- validate samples in API container ---"
set +e
docker compose exec -T api python - <<'PY'
import json, jsonschema
import sys
from pathlib import Path

lab_schema = json.load(open('/repo/schemas/canonical/lab.schema.json'))
labs_index_schema = json.load(open('/repo/schemas/canonical/labs_index.schema.json'))

lab_sample = json.load(open('/tmp/lab_sample_051.json'))
labs_index_sample = json.load(open('/tmp/labs_index_sample_051.json'))

jsonschema.validate(instance=lab_sample, schema=lab_schema)
jsonschema.validate(instance=labs_index_sample, schema=labs_index_schema)
print('LAB_SCHEMA_VALIDATE=PASS')
print('LABS_INDEX_SCHEMA_VALIDATE=PASS')
PY
RC=$?
set -e

echo "VALIDATE_RC=${RC}"

# Git status
echo "--- git status --porcelain ---"
git status --porcelain | sed -n '1,200p'
