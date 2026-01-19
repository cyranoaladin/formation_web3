#!/usr/bin/env bash
set -euo pipefail
cat > .warp/rules/10_no_inline_execution.rules.md <<'EOF'
# No Inline Execution
- Forbid inline heredocs longer than 5 lines
- Forbid mixed shell + output pasting
- Require script files under tools/steps/
EOF

cat > .warp/rules/20_proof_required.rules.md <<'EOF'
# Proof Required For Every Step
- Every step must define required proofs
- Proofs are command outputs or file contents
- Without proofs, next step is forbidden
EOF

cat > .warp/rules/30_step_atomicity.rules.md <<'EOF'
# Step Atomicity
- One step = one responsibility
- A step may touch only one subsystem (api, worker, ui, rag, infra)
- No refactor + feature in same step
EOF
