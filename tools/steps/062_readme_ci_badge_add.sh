#!/usr/bin/env bash
# Step 062 — readme_ci_badge_add
# Goal: Add CI badge to README if GitHub remote is known, otherwise add a placeholder note.
# Proofs: show README head after patch; git status; commit with message.

set -euo pipefail

README="README.md"

get_slug() {
  # Try to get GitHub slug owner/repo from remotes
  local url
  url=$(git remote get-url origin 2>/dev/null || true)
  if [[ -z "$url" ]]; then
    echo ""; return 0
  fi
  # Normalize
  # Supports: git@github.com:OWNER/REPO.git or https://github.com/OWNER/REPO(.git)
  url=${url%.git}
  if [[ "$url" =~ github.com[:/]+([^/]+)/([^/]+)$ ]]; then
    echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"; return 0
  fi
  echo ""; return 0
}

slug=$(get_slug)

python3 - <<PY
from pathlib import Path
readme=Path("README.md")
s=readme.read_text(encoding="utf-8")
if "[![CI](https://github.com/" in s:
    print("README_BADGE_PRESENT=1")
else:
    import os
    slug=os.environ.get("SLUG","")
    if slug:
        badge=f"[![CI](https://github.com/{slug}/actions/workflows/ci.yml/badge.svg)](https://github.com/{slug}/actions/workflows/ci.yml)\n\n"
    else:
        badge=(
            "<!-- CI badge placeholder: set remote to GitHub and replace OWNER/REPO -->\n"
            "[![CI](https://github.com/OWNER/REPO/actions/workflows/ci.yml/badge.svg)](https://github.com/OWNER/REPO/actions/workflows/ci.yml)\n\n"
        )
    readme.write_text(badge + s, encoding="utf-8")
    print("README_BADGE_PRESENT=0 -> INSERTED")
PY

# Proof: print head
sed -n '1,20p' "$README"

# Commit change

echo "--- git status --porcelain ---"
git status --porcelain | sed -n '1,160p'

git add README.md || true

msg=$(cat <<'MSG'
Docs: add CI badge to README (Step 062)

- Adds GitHub Actions CI badge (or placeholder if remote unknown)

Co-Authored-By: Warp <agent@warp.dev>
MSG
)

git commit -m "$msg" || echo "No changes to commit."
