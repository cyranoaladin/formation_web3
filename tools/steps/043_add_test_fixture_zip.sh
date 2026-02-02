#!/usr/bin/env bash
# Step 043 — add_test_fixture_zip (tests/fixtures)
# Create a deterministic test fixture: tests/fixtures/minimal.zip containing README.txt
# Idempotent; no commits here.

set -euo pipefail

FIXDIR="tests/fixtures"
ZIPREL="${FIXDIR}/minimal.zip"
ZIPABS="$(pwd)/${ZIPREL}"
TMPDIR="/tmp/fixture_minimal_$$"

# 1) Prepare deterministic workspace
rm -rf "$TMPDIR"
mkdir -p "$TMPDIR" "$FIXDIR"

# Fixed content and timestamp
cat >"$TMPDIR/README.txt" <<'EOF'
RBK minimal fixture
EOF
# Set fixed timestamp (UTC 2020-01-01 00:00)
TZ=UTC touch -t 202001010000 "$TMPDIR/README.txt"

# 2) Build zip deterministically (-X: no extra attrs)
mkdir -p "$(dirname "$ZIPABS")"
cd "$TMPDIR"
zip -X -q -9 "$ZIPABS" README.txt
cd - >/dev/null

# 3) Proofs
echo "--- ls -la ${ZIPREL} ---"
ls -la "$ZIPREL"

echo "--- sha256sum ${ZIPREL} ---"
sha256sum "$ZIPREL"

echo "--- unzip -l ${ZIPREL} (head) ---"
unzip -l "$ZIPREL" | sed -n '1,20p'

# 4) Repo status (no commit in this step)
echo "--- git status --porcelain (raw) ---"
git status --porcelain | sed -n '1,120p'