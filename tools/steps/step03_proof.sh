#!/usr/bin/env bash
set -euo pipefail
for f in \
  .warp/rules/10_no_inline_execution.rules.md \
  .warp/rules/20_proof_required.rules.md \
  .warp/rules/30_step_atomicity.rules.md; do
  echo "Proof: $f"; ls -l "$f"; wc -l "$f"; sha256sum "$f" | awk '{print $1}'; echo;
done
