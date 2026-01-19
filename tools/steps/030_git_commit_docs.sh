#!/usr/bin/env bash
# Step 030 — commit_docs_and_warp_bootstrap (atomic commit)
# - Un seul commit atomique des docs, .warp, verify harness et steps
# - NINJA RULES: ne modifie aucun fichier (hors ce script), ne commit PAS tools/logs/
# - Idempotent: si rien à committer, s'arrête proprement

set -euo pipefail

msg_title="docs: normalize repo docs + warp execution framework"
msg_trailer="Co-Authored-By: Warp <agent@warp.dev>"

# 1) Status avant
echo "--- BEFORE STATUS (git status --porcelain) ---"
git status --porcelain

# 2) Staging sélectif
#   - *.md racine (s'ils existent)
#   - SECURITY.md
#   - .warp/
#   - tools/verify.sh tools/verify.spec
#   - tools/steps/
#   - NE PAS inclure tools/logs/

# Racine *.md
shopt -s nullglob
md_files=( *.md )
if (( ${#md_files[@]} )); then
  git add --update -- "${md_files[@]}" 2>/dev/null || true
  git add -- "${md_files[@]}" 2>/dev/null || true
fi
shopt -u nullglob

# SECURITY.md explicite (au cas où)
if [[ -f SECURITY.md ]]; then git add SECURITY.md; fi

# .warp (complet)
if [[ -d .warp ]]; then git add .warp; fi

# verify harness
[[ -f tools/verify.sh ]] && git add tools/verify.sh || true
[[ -f tools/verify.spec ]] && git add tools/verify.spec || true

# steps (complet)
if [[ -d tools/steps ]]; then git add tools/steps; fi

# 3) Assertion: aucun tools/logs/ ne doit être staged
echo "--- STAGED FILES (git diff --cached --name-only) ---"
git diff --cached --name-only
if git diff --cached --name-only | grep -q '^tools/logs/'; then
  echo "ERROR: tools/logs/* are staged — aborting" >&2
  exit 1
else
  echo "ASSERTION: no tools/logs staged — OK"
fi

# 4) Commit si besoin
if git diff --cached --quiet; then
  echo "NO_CHANGES_TO_COMMIT=1"
else
  echo "NO_CHANGES_TO_COMMIT=0"
  git -c commit.gpgsign=false commit -m "$msg_title" -m "$msg_trailer"
fi

# 5) Preuves après
echo "--- AFTER STATUS (git status --porcelain) ---"
git status --porcelain

echo "--- LAST COMMIT (git --no-pager log -1 --stat) ---"
git --no-pager log -1 --stat

echo -n "COMMIT_HASH="
# Si aucun commit encore dans le repo, ceci échouera; mais repo est initialisé
(git rev-parse HEAD) 2>/dev/null || true