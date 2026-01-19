#!/usr/bin/env bash
set -euo pipefail
# Create tools/verify.sh with minimal assertions and a demo test suite
mkdir -p tools
cat > tools/verify.sh <<'EOF'
#!/usr/bin/env bash
# Minimal verification harness
# Assertions:
#   - path_exists <path>
#   - file_contains <file> <regex>
#   - http_ok <url>
#   - cmd_ok "<command>"
# Exits 0 if all pass, else 1. Prints a PASS/FAIL summary.

set -u
PASS=0
FAIL=0
TOTAL=0

_log_pass() { echo "PASS: $1"; PASS=$((PASS+1)); TOTAL=$((TOTAL+1)); }
_log_fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); TOTAL=$((TOTAL+1)); }

path_exists() {
  local p="$1"
  if [[ -e "$p" ]]; then _log_pass "path_exists $p"; else _log_fail "path_exists $p"; fi
}

file_contains() {
  local f="$1"; shift
  local re="$1"
  if [[ -f "$f" ]] && grep -Eq "$re" "$f"; then
    _log_pass "file_contains $f /$re/"
  else
    _log_fail "file_contains $f /$re/"
  fi
}

http_ok() {
  local url="$1"
  local code
  code=$(curl -ksS -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || echo "000")
  # consider 200..399 as OK
  if [[ "$code" =~ ^2[0-9]{2}$|^3[0-9]{2}$ ]]; then
    _log_pass "http_ok $url ($code)"
  else
    _log_fail "http_ok $url ($code)"
  fi
}

cmd_ok() {
  local cmd="$1"
  bash -lc "$cmd" >/dev/null 2>&1
  local rc=$?
  if [[ $rc -eq 0 ]]; then _log_pass "cmd_ok $cmd"; else _log_fail "cmd_ok $cmd (exit=$rc)"; fi
}

_finish() {
  if [[ $FAIL -eq 0 ]]; then
    echo "RESULT: PASS ($PASS passed, 0 failed)"
    exit 0
  else
    echo "RESULT: FAIL ($PASS passed, $FAIL failed)"
    exit 1
  fi
}

# Built-in demo assertions (run when no args supplied)
if [[ $# -eq 0 ]]; then
  echo "Running built-in demo assertions..."
  path_exists "tools/run.sh"              # EXPECT PASS
  file_contains ".warp/README.md" "Warp Configuration"  # EXPECT PASS
  path_exists "NON_EXISTENT_FILE_12345"   # EXPECT FAIL
  _finish
fi

# If arguments are provided, treat each as a command to evaluate using cmd_ok
for arg in "$@"; do
  cmd_ok "$arg"
done
_finish
EOF
chmod +x tools/verify.sh
