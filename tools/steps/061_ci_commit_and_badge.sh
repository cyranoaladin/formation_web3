#!/usr/bin/env bash
# Step 061 — ci_commit_and_badge
# Goal: Commit CI workflow (Step 060). No README badge since repo URL is unknown.
# Policy: never commit tools/logs/
# Proofs: pre/post git status, staged list, commit hash and subject

set -euo pipefail
shopt -s nullglob

echo "--- PRE: git status --porcelain ---"
git status --porcelain | sed -n '1,240p'

files=(
  .github/workflows/ci.yml
  tools/steps/060_ci_compose_smoke.sh
)

add_list=()
for f in "${files[@]}"; do
  if [[ -e "$f" ]]; then
    add_list+=("$f")
  fi

done

if [[ ${#add_list[@]} -eq 0 ]]; then
  echo "Nothing to commit for Step 060; aborting." >&2
  exit 0
fi

git add -- "${add_list[@]}"

echo "--- STAGED (name-status) ---"
git --no-pager diff --cached --name-status | sed -n '1,200p'

msg=$(cat <<'MSG'
Phase 6: CI compose smoke (Step 060)

- Adds GitHub Actions workflow to build compose services and run E2E smoke (Step 048)
- Includes compose logs on failure and teardown

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