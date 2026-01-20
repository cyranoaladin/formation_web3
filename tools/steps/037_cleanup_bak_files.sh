#!/usr/bin/env bash
# Step 037 — cleanup_bak_files_and_ignore (atomic)
# - Remove from git any tracked backup files matching *.bak.* (use --cached to keep workspace files)
# - Add .gitignore rule '*.bak.*' (idempotent)
# - Commit with trailer; stop after proofs

set -euo pipefail

MSG_TITLE="chore: remove backup artifacts (*.bak.*)"
MSG_TRAILER="Co-Authored-By: Warp <agent@warp.dev>"

# 1) BEFORE: list tracked *.bak.*
echo "--- BEFORE: tracked backup files ---"
(git ls-files | grep -E '\\.bak\\.' || true)

# Collect tracked bak files (NUL-safe)
mapfile -d '' -t BAKS < <(git ls-files -z | grep -z -E '\\.bak\\.' || true)

# 2) Update .gitignore idempotently
UPDATED=0
if ! grep -qx '\*.bak\.\*' .gitignore 2>/dev/null; then
  if [[ -s .gitignore ]]; then echo >> .gitignore; fi
  {
    echo "# Ignore editor/program backup artifacts"
    echo "*.bak.*"
  } >> .gitignore
  UPDATED=1
fi
if [[ "$UPDATED" != "0" ]]; then git add .gitignore; fi

# 3) Stage removals (from git index only)
if (( ${#BAKS[@]} > 0 )); then
  # Show what will be removed
  printf "%s\n" "${BAKS[@]}" | sed 's/^/WILL_REMOVE: /'
  git rm --cached -- "${BAKS[@]}"
fi

# 4) Show staging proofs
echo "--- STATUS (git status --porcelain) ---"
git status --porcelain | sed -n '1,200p'

echo "--- STAGED (git diff --cached --name-only) ---"
git diff --cached --name-only

# 5) Commit if there is something staged
if git diff --cached --quiet; then
  echo "NO_CHANGES_TO_COMMIT=1"
else
  echo "NO_CHANGES_TO_COMMIT=0"
  git -c commit.gpgsign=false commit -m "$MSG_TITLE" -m "$MSG_TRAILER"
fi

# 6) After proofs
echo "--- LAST COMMIT (hash) ---"
echo -n "COMMIT_HASH="; git rev-parse HEAD

echo "--- AFTER: tracked backup files ---"
(git ls-files | grep -E '\\.bak\\.' || true)