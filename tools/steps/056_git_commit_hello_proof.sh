#!/usr/bin/env bash
# STEP 056 — git_commit_hello_proof (CODE CHANGE)
# Commits robust hello-proof integration artifacts.

set -euo pipefail

TS=$(date +%Y%m%d_%H%M%S)
LOG_FILE="tools/logs/step_056_commit_${TS}.txt"
mkdir -p tools/logs

{
  echo "[INFO] STEP 056 @ ${TS}"
  
  echo "== Pre-commit status =="
  git status --porcelain

  echo "== Staging =="
  # Stage core files
  git add runner/minimal.py worker/worker.py
  
  # Stage steps (including patches and smoke tests)
  # 052 might have been from previous session but instructed to include patches "si non committés"
  # I'll enable globbing for steps
  git add tools/steps/05[2-5]*.sh
  
  # Safety check
  echo "Staged files:"
  git diff --name-only --cached

  echo "== Committing =="
  git commit -m "feat: hello-proof runner integration (logs+result deterministic)

Co-Authored-By: Antigravity <agent@antigravity.dev>"

  echo "== Post-commit log =="
  git log -1 --stat
  
  echo
  echo "== Verify Harness =="
  bash tools/verify.sh --spec tools/verify.spec

} | tee "$LOG_FILE"
