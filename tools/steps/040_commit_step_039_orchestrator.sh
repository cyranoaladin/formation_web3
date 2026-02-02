#!/usr/bin/env bash
# Step 040 — commit_step_039_orchestrator (atomic)
# Scope: commit ONLY tools/steps/039_git_commit_steps_037_038.sh
# No side effects beyond staging/commit. Never stage tools/logs/.

set -euo pipefail

MSG_TITLE="chore: add step 039 (commit orchestrator)"
MSG_TRAILER="Co-Authored-By: Warp <agent@warp.dev>"
FILE=tools/steps/039_git_commit_steps_037_038.sh

# 1) BEFORE status (proof)
echo "--- BEFORE (git status --porcelain) ---"
git status --porcelain | sed -n '1,120p'

# 2) Stage ONLY the file (if it exists)
if [[ -f "$FILE" ]]; then
  git add "$FILE"
else
  echo "ERROR: missing $FILE" >&2
  exit 1
fi

# 3) Proof: staged list must be exactly this file
echo "--- STAGED (git diff --cached --name-only) ---"
STAGED=$(git diff --cached --name-only)
echo "$STAGED"

# Safety: ensure tools/logs/ is not staged
if echo "$STAGED" | grep -q '^tools/logs/'; then
  echo "ERROR: tools/logs/ is staged — aborting" >&2
  exit 1
fi

# Validate exact match
if [[ "$STAGED" != "$FILE" ]]; then
  echo "ERROR: staged set mismatch" >&2
  echo "EXPECTED: $FILE" >&2
  echo "ACTUAL:   $STAGED" >&2
  exit 1
fi

# 4) Commit
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
# Ignore untracked tools/logs entries if any
RAW=$(git status --porcelain)
echo "$RAW" | sed -n '1,120p'