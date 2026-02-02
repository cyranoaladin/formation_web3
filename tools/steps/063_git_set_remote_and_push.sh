#!/usr/bin/env bash
# Step 063 — git_set_remote_and_push
# Goal: Ensure a GitHub remote exists and push main. If no remote, require REMOTE_URL or GITHUB_SLUG env.
# Also replace README CI badge placeholder with the real slug if available.
# Proofs: remotes list, push output (or explicit abort), README head if patched, git status/last commit.

set -euo pipefail

show_remotes() {
  echo "--- git remote -v ---"
  git remote -v || true
}

# 1) Inspect current remotes
show_remotes

have_origin=0
if git remote get-url origin >/dev/null 2>&1; then
  have_origin=1
fi

# 2) If no origin, try to add from env
if [[ "$have_origin" -eq 0 ]]; then
  REMOTE_URL_DEFAULT=""
  if [[ -n "${REMOTE_URL:-}" ]]; then
    REMOTE_URL_DEFAULT="$REMOTE_URL"
  elif [[ -n "${GITHUB_SLUG:-}" ]]; then
    REMOTE_URL_DEFAULT="git@github.com:${GITHUB_SLUG}.git"
  fi

  if [[ -z "$REMOTE_URL_DEFAULT" ]]; then
    echo "ABORT_NEEDS_REMOTE=1"
    echo "Hint: set REMOTE_URL=git@github.com:OWNER/REPO.git or GITHUB_SLUG=OWNER/REPO and rerun."
    exit 2
  fi

  echo "--- adding origin: $REMOTE_URL_DEFAULT ---"
  git remote add origin "$REMOTE_URL_DEFAULT"
  have_origin=1
fi

# 3) Push main
if [[ "$have_origin" -eq 1 ]]; then
  echo "--- pushing: git push -u origin main ---"
  set +e
  git push -u origin main
  PUSH_RC=$?
  set -e
  echo "PUSH_RC=${PUSH_RC}"
  if [[ "$PUSH_RC" -ne 0 ]]; then
    echo "Push failed (auth/network?). Resolve and rerun this step."
    exit $PUSH_RC
  fi
fi

# 4) If push succeeded, patch README CI badge if placeholder exists and slug can be resolved
slug=""
url=$(git remote get-url origin 2>/dev/null || true)
url_no_git=${url%.git}
if [[ "$url_no_git" =~ github.com[:/]+([^/]+)/([^/]+)$ ]]; then
  slug="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
fi

if [[ -n "$slug" ]] && grep -q "github.com/OWNER/REPO" README.md; then
  echo "--- patching README badge with slug: $slug ---"
  sed -i.bak "s#github.com/OWNER/REPO#github.com/${slug}#g" README.md
  rm -f README.md.bak
  git add README.md
  git commit -m $'Docs: set CI badge slug\n\nCo-Authored-By: Warp <agent@warp.dev>' || true
  echo "README_BADGE_PATCHED=1"
else
  echo "README_BADGE_PATCHED=0"
fi

# 5) Proofs
show_remotes

echo "--- git branch -vv ---"
git --no-pager branch -vv || true

echo "--- last commit ---"
git --no-pager log -1 --oneline || true
