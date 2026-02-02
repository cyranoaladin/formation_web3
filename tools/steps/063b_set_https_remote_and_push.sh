#!/usr/bin/env bash
# Step 063b — set_https_remote_and_push
# Goal: Set origin to HTTPS https://github.com/cyranoaladin/formation_web3.git and push main.
# Then patch README CI badge slug if placeholder present.

set -euo pipefail

SLUG="cyranoaladin/formation_web3"
HTTPS_URL="https://github.com/${SLUG}.git"

echo "--- git remote -v (before) ---"
git remote -v || true

if git remote get-url origin >/dev/null 2>&1; then
  echo "--- set-url origin -> ${HTTPS_URL} ---"
  git remote set-url origin "${HTTPS_URL}"
else
  echo "--- add origin ${HTTPS_URL} ---"
  git remote add origin "${HTTPS_URL}"
fi

echo "--- git remote -v (after) ---"
git remote -v || true

echo "--- pushing: git push -u origin main ---"
set +e
git push -u origin main
PUSH_RC=$?
set -e
echo "PUSH_RC=${PUSH_RC}"
if [[ "$PUSH_RC" -ne 0 ]]; then
  echo "Push failed (HTTPS auth?). Configure git credentials or PAT and rerun."
  exit $PUSH_RC
fi

# Patch README badge
if grep -q "github.com/OWNER/REPO" README.md; then
  echo "--- patching README badge with slug: ${SLUG} ---"
  sed -i.bak "s#github.com/OWNER/REPO#github.com/${SLUG}#g" README.md
  rm -f README.md.bak
  git add README.md
  git commit -m $'Docs: set CI badge slug (post-push)\n\nCo-Authored-By: Warp <agent@warp.dev>' || true
  echo "README_BADGE_PATCHED=1"
else
  echo "README_BADGE_PATCHED=0"
fi

echo "--- last commit ---"
git --no-pager log -1 --oneline || true
