#!/usr/bin/env bash
set -euo pipefail

curl -sS -m 3 http://localhost:8000/health >/dev/null
curl -sS -m 3 http://localhost:3000/ >/dev/null || true

rm -rf /tmp/rbk_demo_submission /tmp/rbk_demo_submission.zip
mkdir -p /tmp/rbk_demo_submission/proofs

cat > /tmp/rbk_demo_submission/README.md <<'EOF'
# RBK Demo Submission
This is a smoke submission for RBK Labs.
EOF

cat > /tmp/rbk_demo_submission/proofs/audit_note.md <<'EOF'
## Audit Note (demo)
- Missing owner check: fixed in patch.diff
EOF

cat > /tmp/rbk_demo_submission/patch.diff <<'EOF'
diff --git a/program.rs b/program.rs
index 1111111..2222222 100644
--- a/program.rs
+++ b/program.rs
@@ -1,3 +1,4 @@
+// demo patch
 fn main() {}
EOF

(cd /tmp/rbk_demo_submission && zip -qr /tmp/rbk_demo_submission.zip .)

RESP="$(curl -sS -F student_id=stu_smoke -F lab_id=lab_demo -F file=@/tmp/rbk_demo_submission.zip http://localhost:8000/submissions/upload_zip)"
echo "$RESP"

SUB_ID="$(echo "$RESP" | python3 -c 'import sys,json; print(json.load(sys.stdin)["submission_id"])')"

for i in $(seq 1 120); do
  S="$(curl -sS http://localhost:8000/submissions/${SUB_ID})"
  STATUS="$(echo "$S" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("status",""))')"
  if [[ "$STATUS" != "queued" && "$STATUS" != "running" && "$STATUS" != "uploaded" ]]; then
    echo "$S"
    break
  fi
  sleep 1
done

S="$(curl -sS http://localhost:8000/submissions/${SUB_ID})"
echo "$S"

RUN_ID="$(echo "$S" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("latest_run_id",""))')"
if [[ -n "$RUN_ID" && "$RUN_ID" != "None" ]]; then
  curl -sS http://localhost:8000/runs/${RUN_ID} ; echo
fi

docker compose exec -T mongo mongosh "mongodb://localhost:27017/rbk_labs" --quiet --eval '
print("submissions=" + db.submissions.countDocuments({}));
print("runs=" + db.autograde_runs.countDocuments({}));
print("proof_bundles=" + db.proof_bundles.countDocuments({}));
print("--- latest submission ---");
db.submissions.find({}, { _id:0, submission_id:1, status:1, updated_at:1, latest_run_id:1 }).sort({updated_at:-1}).limit(1).forEach(printjson);
print("--- latest run ---");
db.autograde_runs.find({}, { _id:0, run_id:1, submission_id:1, status:1, updated_at:1, proof_bundle_id:1 }).sort({updated_at:-1}).limit(1).forEach(printjson);
print("--- latest proof bundle ---");
db.proof_bundles.find({}, { _id:0, proof_bundle_id:1, run_id:1, decision_hint:1, score:1, created_at:1 }).sort({created_at:-1}).limit(1).forEach(printjson);
'

docker compose logs --no-color --tail 120 worker || true
