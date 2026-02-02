#!/usr/bin/env bash
# Step 049 — commit_phase2_3_atomic
# Goal: Commit Phase 2/3 changes introduced in steps 046a–048 (mount /repo; jsonschema validation; worker refactor; e2e smoke)
# Policy: never commit tools/logs/
# Proofs: pre/post git status, list of staged files, commit hash and subject

set -euo pipefail
shopt -s nullglob

# Show pre-commit state
echo "--- PRE: git status --porcelain ---"
git status --porcelain | sed -n '1,200p'

# Build inclusion list explicitly
step_files=(
  tools/steps/046a_compose_mount_repo_api_worker.sh
  tools/steps/047_schemas_validate_on_write.sh
  tools/steps/047a_collect_api_worker_logs_and_health.sh
  tools/steps/047b_fix_validation_and_worker_syntax.sh
  tools/steps/047c_retry_proofs_only.sh
  tools/steps/048_e2e_smoke_upload_to_proof.sh
)

code_files=(
  api/app/main.py
  api/requirements.txt
  worker/worker.py
  worker/requirements.txt
  docker-compose.override.yml
)

fixture_files=(
  tests/fixtures/minimal.zip
)

# Stage files that actually exist
add_list=()
for f in "${step_files[@]}" "${code_files[@]}" "${fixture_files[@]}"; do
  if [[ -e "$f" ]]; then
    add_list+=("$f")
  fi
done

if [[ ${#add_list[@]} -eq 0 ]]; then
  echo "Nothing to commit for steps 046a–048; aborting." >&2
  exit 0
fi

# Ensure logs are not staged
git add -- "${add_list[@]}"
if git ls-files -o --exclude-standard tools/logs | grep -q .; then
  echo "[INFO] tools/logs contains untracked files; they will remain untracked (ignored)."
fi

# Show staged
echo "--- STAGED (name-status) ---"
git --no-pager diff --cached --name-status | sed -n '1,400p'

# Commit
msg=$(cat <<'MSG'
Phase 2/3: schema validation on write + E2E smoke (Steps 046a–048)

- 046a: Mount /repo into api/worker via docker-compose.override.yml (schemas available at /repo/schemas/canonical)
- 047: Add jsonschema to API/Worker; validate Submission/Run/Proof against canonical schemas
- 047b: Fix worker syntax; align timestamps and score.rubric; keep invalid_proof path for demo
- 048: E2E smoke (upload -> run completed -> proof_bundle_id present) — PASS

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
git status --porcelain | sed -n '1,120p'
