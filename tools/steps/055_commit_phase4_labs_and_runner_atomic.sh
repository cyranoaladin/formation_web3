#!/usr/bin/env bash
# Step 055 — commit_phase4_labs_and_runner_atomic
# Goal: Commit lab schemas, first lab spec, /labs endpoint, and hello-proof runner behavior (Steps 050–054a)
# Policy: never commit tools/logs/
# Proofs: pre/post git status, staged file list, commit hash and subject

set -euo pipefail
shopt -s nullglob

echo "--- PRE: git status --porcelain ---"
git status --porcelain | sed -n '1,240p'

step_files=(
  tools/steps/050_labs_discovery_report.sh
  tools/steps/051_add_lab_schemas_minimal.sh
  tools/steps/052_add_first_lab_hello_proof.sh
  tools/steps/053_api_add_labs_index_endpoint.sh
  tools/steps/054_worker_runner_hello_proof_minimal.sh
  tools/steps/054a_fix_run_result_score_auto.sh
)

code_files=(
  schemas/canonical/lab.schema.json
  schemas/canonical/labs_index.schema.json
  labs/specs/hello-proof/lab.json
  labs/specs/hello-proof/README.md
  api/app/main.py
  worker/worker.py
)

# Stage existing files only
add_list=()
for f in "${step_files[@]}" "${code_files[@]}"; do
  if [[ -e "$f" ]]; then
    add_list+=("$f")
  fi

done

if [[ ${#add_list[@]} -eq 0 ]]; then
  echo "Nothing to commit for steps 050–054a; aborting." >&2
  exit 0
fi

git add -- "${add_list[@]}"

# Show staged
echo "--- STAGED (name-status) ---"
git --no-pager diff --cached --name-status | sed -n '1,400p'

# Commit
msg=$(cat <<'MSG'
Phase 4: labs + runner minimal (Steps 050–054a)

- 050: Labs discovery report (no code changes)
- 051: Canonical schemas for lab and labs_index + validation
- 052: First lab spec hello-proof
- 053: API GET /labs indexes lab specs and validates against labs_index schema
- 054: Worker recognizes hello-proof → validated with score_auto=100 (others stay needs_review)

Excludes tools/logs/ by policy.

Co-Authored-By: Warp <agent@warp.dev>
MSG
)

git commit -m "$msg"

# Proofs
echo "--- COMMIT HASH ---"
git rev-parse HEAD

echo "--- COMMIT SUBJECT ---"
git show -s --format='%h %s'

echo "--- POST: git status --porcelain ---"
git status --porcelain | sed -n '1,160p'
