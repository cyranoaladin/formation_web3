#!/usr/bin/env bash
# Minimal verification harness (spec-driven)
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
  local f="$1"; shift || true
  local re="${1-}"
  if [[ -n "$re" ]] && [[ -f "$f" ]] && grep -Eq "$re" "$f"; then
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

_trim() {
  # trim leading/trailing whitespace from $1
  local s="$1"
  s="${s#${s%%[![:space:]]*}}"   # leading
  s="${s%${s##*[![:space:]]}}"   # trailing
  printf '%s' "$s"
}

parse_spec() {
  local spec="$1"
  if [[ ! -f "$spec" ]]; then
    _log_fail "spec file not found: $spec"
    return
  fi
  local line op rest file regex
  while IFS= read -r line || [[ -n "$line" ]]; do
    line=$(_trim "$line")
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^# ]] && continue
    op=${line%%[[:space:]]*}
    rest=${line#"$op"}
    rest=${rest# }  # remove one leading space if present
    case "$op" in
      PATH)
        path_exists "$rest"
        ;;
      HTTP)
        http_ok "$rest"
        ;;
      CMD)
        cmd_ok "$rest"
        ;;
      CONTAINS)
        file=${rest%%[[:space:]]*}
        regex=${rest#"$file"}
        regex=${regex# }
        file_contains "$file" "$regex"
        ;;
      *)
        _log_fail "unknown spec op: $op"
        ;;
    esac
  done < "$spec"
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

# CLI
if [[ $# -ge 2 && "$1" == "--spec" ]]; then
  parse_spec "$2"
  _finish
fi

# Built-in demo assertions (self-contained, must pass)
if [[ $# -eq 0 ]]; then
  echo "Running built-in demo assertions..."
  path_exists "tools/run.sh"                                 # EXPECT PASS
  file_contains "tools/run.sh" "^#!/usr/bin/env bash"        # EXPECT PASS
  cmd_ok "true"                                              # EXPECT PASS
  _finish
fi

# If arguments are provided (non-spec), treat each as a command to evaluate using cmd_ok
for arg in "$@"; do
  cmd_ok "$arg"
done
_finish
