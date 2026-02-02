#!/usr/bin/env bash
# Step 057 — commit_ui_minimal_atomic
# Goal: Commit UI Health+Labs minimal (Step 056) changes
# Policy: never commit tools/logs/
# Proofs: pre/post git status, staged list, commit hash and subject

set -euo pipefail
shopt -s nullglob

echo "--- PRE: git status --porcelain ---"
git status --porcelain | sed -n '1,240p'

files=(
  ui/src/App.jsx
  tools/steps/056_ui_minimal_health_and_labs.sh
)

add_list=()
for f in "${files[@]}"; do
  if [[ -e "$f" ]]; then
    add_list+=("$f")
  fi

done

if [[ ${#add_list[@]} -eq 0 ]]; then
  echo "Nothing to commit for Step 056; aborting." >&2
  exit 0
fi

git add -- "${add_list[@]}"

echo "--- STAGED (name-status) ---"
git --no-pager diff --cached --name-status | sed -n '1,200p'

msg=$(cat <<'MSG'
Phase 5: UI minimal — Health and Labs (Step 056)

- Adds onLabs action and button to fetch /labs and display in Output panel
- Confirms UI serves index and API /labs returns hello-proof

Excludes tools/logs/ by policy.

Co-Authored-By: Warp <agent@warp.dev>
MSG
)

git commit -m "$msg"

echo "--- COMMIT HASH ---"
git rev-parse HEAD

echo "--- COMMIT SUBJECT ---"
git show -s --format='%h %s'

echo "--- POST: git status --porcelain ---"
git status --porcelain | sed -n '1,160p'