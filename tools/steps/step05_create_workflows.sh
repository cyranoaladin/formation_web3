#!/usr/bin/env bash
set -euo pipefail
cat > .warp/workflows/infra_stabilisation.workflow.md <<'EOF'
# Workflow: infra_stabilisation
- api health
- mongo availability
- worker idle loop
- proof: health endpoints
EOF

cat > .warp/workflows/ui_bootstrap.workflow.md <<'EOF'
# Workflow: ui_bootstrap
- node version
- package.json existence
- vite dev server running
- proof: curl localhost:3000
EOF

cat > .warp/workflows/rag_pipeline.workflow.md <<'EOF'
# Workflow: rag_pipeline
- ingestion
- chunking
- embeddings
- retrieval
- proof: answer with citations
EOF
