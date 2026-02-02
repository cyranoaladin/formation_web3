#!/usr/bin/env bash
# STEP 049 — atomic_commit_reconstruction (GIT CHANGE)
# But: commit atomique de la reconstruction (code + labs + runner + smoke + docs)
# Contraintes: exclure tools/logs/ ; message normalisé ; preuves avant/après.

set -euo pipefail

TS=$(date +%Y%m%d_%H%M%S)
LOG="tools/logs/049_commit_${TS}.txt"
mkdir -p tools/logs

{
  echo "[INFO] STEP 049 @ ${TS}"
  echo "--- PRE: git status --porcelain ---"
  git status --porcelain | sed -n '1,240p'

  # Build explicit inclusion list
  files=(
    api/app/main.py
    worker/worker.py
    runner/__init__.py
    runner/minimal.py
    schemas/canonical/submission.schema.json
    schemas/canonical/autograde_run.schema.json
    schemas/canonical/proof_bundle.schema.json
    labs/specs/hello-proof/lab.json
    # docs updated
    CONTRACT_CANON.md
    SPEC.md
    AUTOGRADING.md
    LABS.md
    # step scripts for traceability
    tools/steps/040_repo_scan_reconstruction_inputs.sh
    tools/steps/041_api_models_submission_run_proof.sh
    tools/steps/042_api_endpoint_upload_zip_real.sh
    tools/steps/043_api_endpoints_get_submission_run_proof.sh
    tools/steps/044_worker_queue_consumer_minimal.sh
    tools/steps/044a_fix_proof_schema_artifacts.sh
    tools/steps/045_runner_minimal_execute_lab.sh
    tools/steps/045a_fix_runner_newline_issue.sh
    tools/steps/045b_fix_runner_logs_concat.sh
    tools/steps/045c_overwrite_runner_minimal_safe.sh
    tools/steps/045d_patch_runner_literal_newlines.sh
    tools/steps/046_labs_hello_proof_minimal.sh
    tools/steps/047_smoke_e2e_upload_to_proof.sh
    tools/steps/048_docs_sync_contract_with_code.sh
  )

  add_list=()
  for f in "${files[@]}"; do
    [[ -e "$f" ]] && add_list+=("$f")
  done

  if [[ ${#add_list[@]} -eq 0 ]]; then
    echo "Nothing to commit for STEP 049.";
  else
    git add -- "${add_list[@]}"
    echo "--- STAGED (name-status) ---"
    git --no-pager diff --cached --name-status | sed -n '1,400p'

    msg=$(cat <<'MSG'
feat: make submission autograde flow executable (upload_zip -> worker -> proof_bundle)

- API: POST /submissions/upload_zip + GET read endpoints (/submissions, /runs, /proofs)
- Worker: queue consumer, run/proof creation, immutable proofs, artifacts
- Runner: minimal executable (hello-proof) producing logs.txt + result.json
- Labs: hello-proof spec (deterministic command + expected_artifacts)
- Schemas: align minimal fields + open artifacts
- Docs: sync endpoints with code; remove /rag/query mentions
- Smoke: end-to-end upload -> completed -> proof_bundle (E2E_SMOKE=PASS)

Co-Authored-By: Warp <agent@warp.dev>
MSG
    )

    git commit -m "$msg"
    echo "--- COMMIT HASH ---"; git rev-parse HEAD
    echo "--- COMMIT SUBJECT ---"; git show -s --format='%h %s'
  fi

  echo "--- POST: git status --porcelain ---"
  git status --porcelain | sed -n '1,240p'
} | tee "$LOG"

echo "STOP."