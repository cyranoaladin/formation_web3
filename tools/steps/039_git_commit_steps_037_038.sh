#!/usr/bin/env bash
# Step 039 — git_commit_steps_037_038 (atomic)
# Scope: ONLY commit tools/steps/037_cleanup_bak_files.sh and tools/steps/038_smoke_compose_health.sh
# No side effects beyond staging/commit. Never stage tools/logs/.

set -euo pipefail

MSG_TITLE="chore: add steps 037-038 (cleanup + smoke compose health)"
MSG_TRAILER="Co-Authored-By: Warp <agent@warp.dev>"

STEP1=tools/steps/037_cleanup_bak_files.sh
STEP2=tools/steps/038_smoke_compose_health.sh

# 1) BEFORE status (proof)
echo "--- BEFORE (git status --porcelain) ---"
git status --porcelain | sed -n '1,120p'

# 2) Stage ONLY the two files (if they exist)
[[ -f "$STEP1" ]] && git add "$STEP1" || true
[[ -f "$STEP2" ]] && git add "$STEP2" || true

# 3) Proof: staged list must be exactly those two (for existing ones)
echo "--- STAGED (git diff --cached --name-only) ---"
STAGED=$(git diff --cached --name-only)
echo "$STAGED"

# Safety: ensure tools/logs/ is not staged
if echo "$STAGED" | grep -q '^tools/logs/'; then
  echo "ERROR: tools/logs/ is staged — aborting" >&2
  exit 1
fi

# Validate staged set
want=()
[[ -f "$STEP1" ]] && want+=("$STEP1")
[[ -f "$STEP2" ]] && want+=("$STEP2")

# sort both lists and compare
sorted_staged=$(printf '%s\n' $STAGED | sort)
sorted_want=$(printf '%s\n' "${want[@]:-}" | sort)

if [[ "$sorted_staged" != "$sorted_want" ]]; then
  echo "ERROR: staged set mismatch" >&2
  echo "EXPECTED:" >&2
  echo "$sorted_want" >&2
  echo "ACTUAL:" >&2
  echo "$sorted_staged" >&2
  exit 1
fi

# 4) Commit if there is something staged
if git diff --cached --quiet; then
  echo "NO_CHANGES_TO_COMMIT=1"
else
  echo "NO_CHANGES_TO_COMMIT=0"
  git -c commit.gpgsign=false commit -m "$MSG_TITLE" -m "$MSG_TRAILER"
fi

# 5) Proofs after commit
echo "--- LAST COMMIT (hash + body) ---"
echo -n "COMMIT_HASH="; git rev-parse HEAD

git --no-pager log -1 --pretty=%B

# 6) AFTER status
echo "--- AFTER (git status --porcelain) ---"
git status --porcelain | sed -n '1,120p'