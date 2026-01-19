#!/usr/bin/env bash
set -euo pipefail

mkdir -p tools/logs
TS="$(date +%Y%m%d_%H%M%S)"
LOG="tools/logs/docs_fix_security_${TS}.txt"

echo "STEP=013 rename SECURITYY.md -> SECURITY.md" | tee "$LOG" >/dev/null
sha() { sha256sum "$1" | awk '{print $1}'; }

IN_GIT=0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then IN_GIT=1; fi
echo "GIT_DETECTED=${IN_GIT}" | tee -a "$LOG" >/dev/null

# Idempotence checks
if [[ -f SECURITY.md ]]; then
  echo "STATUS=ALREADY_PRESENT SECURITY.md $(sha SECURITY.md)" | tee -a "$LOG" >/dev/null
  echo "ACTION=STOP (no rename)" | tee -a "$LOG" >/dev/null
else
  if [[ -f SECURITYY.md ]]; then
    pre_sha=$(sha SECURITYY.md)
    echo "PRE SECURITYY.md ${pre_sha}" | tee -a "$LOG" >/dev/null
    if [[ ${IN_GIT} -eq 1 ]]; then
      if git mv -f SECURITYY.md SECURITY.md 2>/dev/null; then
        ACTION=git_mv
      else
        mv SECURITYY.md SECURITY.md
        ACTION=mv
      fi
    else
      mv SECURITYY.md SECURITY.md
      ACTION=mv
    fi
    post_sha=$(sha SECURITY.md)
    echo "POST SECURITY.md ${post_sha}" | tee -a "$LOG" >/dev/null
    echo "RENAME_ACTION=${ACTION}" | tee -a "$LOG" >/dev/null
  else
    echo "STATUS=NO_SOURCE (SECURITYY.md not found)" | tee -a "$LOG" >/dev/null
  fi
fi

# Update references in root markdown files (exclude .warp/)
changed=0
for f in ./*.md; do
  [[ -f "$f" ]] || continue
  base=$(basename "$f")
  pre=$(sha "$f")
  # Replace only explicit file references
  sed -E -i \
    -e 's#\]\(SECURITYY\.md\)#](SECURITY.md)#g' \
    -e 's#<SECURITYY\.md>#<SECURITY.md>#g' \
    -e 's#`SECURITYY\.md`#`SECURITY.md`#g' \
    -e 's#(^|[^A-Za-z0-9_.-])SECURITYY\.md([^A-Za-z0-9_.-]|$)#\1SECURITY.md\2#g' \
    "$f"
  post=$(sha "$f")
  if [[ "$pre" != "$post" ]]; then
    echo "UPDATED $base $pre -> $post" | tee -a "$LOG" >/dev/null
    changed=$((changed+1))
  fi
done

echo "FILES_UPDATED=${changed}" | tee -a "$LOG" >/dev/null

echo "REPORT=$LOG" | tee -a "$LOG" >/dev/null
