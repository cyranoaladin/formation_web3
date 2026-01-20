#!/usr/bin/env bash
# Step 036 — git_commit_untracked_base_code (atomic commit)
# Scope: commit only untracked base code/assets (api, ui, worker, schemas, scripts, docker-compose.yml,
#         tools/run_step.sh, tools/safe_patch.py, and untracked tools/steps/*.sh), plus .gitignore if modified.
# Exclude tools/logs/, node_modules, caches, secrets.

set -euo pipefail

MSG_TITLE="chore: add initial app skeleton (api/ui/worker) + schemas + compose"
MSG_TRAILER="Co-Authored-By: Warp <agent@warp.dev>"

# 1) BEFORE status (proof)
echo "--- BEFORE (git status --porcelain) ---"
git status --porcelain | sed -n '1,200p'

# 2) Build staging set from untracked paths only
mapfile -t UNTRACKED < <(git ls-files --others --exclude-standard)

stage_file() {
  local p="$1"
  if [[ -e "$p" ]]; then git add "$p"; fi
}

# Stage top-level known paths if present
for p in api worker ui schemas scripts; do
  if printf '%s\n' "${UNTRACKED[@]}" | grep -qxE "^${p}(/|$)" || [[ -d "$p" ]]; then
    git add "$p" 2>/dev/null || true
  fi
done

# docker-compose
if printf '%s\n' "${UNTRACKED[@]}" | grep -qx '^docker-compose.yml' || [[ -f docker-compose.yml ]]; then
  git add docker-compose.yml 2>/dev/null || true
fi

# tools helpers
for p in tools/run_step.sh tools/safe_patch.py; do
  if printf '%s\n' "${UNTRACKED[@]}" | grep -qx "^${p}$" || [[ -f "$p" ]]; then
    git add "$p" 2>/dev/null || true
  fi
done

# Untracked step scripts under tools/steps/*.sh
mapfile -t UNTRACKED_STEPS < <(printf '%s\n' "${UNTRACKED[@]}" | grep -E '^tools/steps/.*\.sh$' || true)
if (( ${#UNTRACKED_STEPS[@]} )); then
  git add ${UNTRACKED_STEPS[@]} 2>/dev/null || true
fi

# Include .gitignore if modified
if git diff --name-only | grep -qx '.gitignore'; then
  git add .gitignore
fi

# 3) Safety assertions: ensure no forbidden paths are staged
echo "--- STAGED (git diff --cached --name-only) ---"
git diff --cached --name-only

STAGED_LIST=$(git diff --cached --name-only)
if printf '%s\n' "$STAGED_LIST" | grep -qE '^tools/logs/'; then
  echo "ERROR: tools/logs/ is staged — aborting" >&2
  exit 1
fi
if printf '%s\n' "$STAGED_LIST" | grep -qE '(\.env(\..*)?$|\.pem$|\.key$)'; then
  echo "ERROR: secret-like files are staged — aborting" >&2
  exit 1
fi
if printf '%s\n' "$STAGED_LIST" | grep -qE '/node_modules/'; then
  echo "ERROR: node_modules content staged — aborting" >&2
  exit 1
fi

# 4) Audit (re-run 031) and show summary excerpt
bash tools/run.sh tools/steps/031_audit_untracked_no_change.sh || true
LATEST_AUD=$(ls -1t tools/logs/untracked_audit_*.txt | head -n 1)
echo "--- AUDIT SUMMARY ($LATEST_AUD) ---"
grep -nE 'OK_TO_COMMIT|SECRETS_MATCHES:|SIZE_GT_5MB:' "$LATEST_AUD" | sed -n '1,20p' || true

# 5) Commit if something staged
if git diff --cached --quiet; then
  echo "NO_CHANGES_TO_COMMIT=1"
else
  echo "NO_CHANGES_TO_COMMIT=0"
  git -c commit.gpgsign=false commit -m "$MSG_TITLE" -m "$MSG_TRAILER"
fi

# 6) Proofs after commit
echo "--- LAST COMMIT (hash + body) ---"
echo -n "COMMIT_HASH="; git rev-parse HEAD

git --no-pager log -1 --pretty=%B

echo "--- AFTER (git status --porcelain) ---"
git status --porcelain | sed -n '1,200p'