#!/usr/bin/env bash
set -euo pipefail
for f in \
  .warp/workflows/infra_stabilisation.workflow.md \
  .warp/workflows/ui_bootstrap.workflow.md \
  .warp/workflows/rag_pipeline.workflow.md; do
  echo "Proof: $f"; ls -l "$f"; wc -l "$f"; sha256sum "$f" | awk '{print $1}'; echo;
done
