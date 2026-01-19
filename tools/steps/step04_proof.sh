#!/usr/bin/env bash
set -euo pipefail
for f in \
  .warp/skills/run_step.skill.md \
  .warp/skills/diagnose.skill.md \
  .warp/skills/verify.skill.md; do
  echo "Proof: $f"; ls -l "$f"; wc -l "$f"; sha256sum "$f" | awk '{print $1}'; echo;
done
