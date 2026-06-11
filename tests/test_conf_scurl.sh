#!/bin/sh
# tests/test_conf_scurl.sh
# Minimal test harness for conf-scurl

PASS=0
FAIL=0

assert_eq() {
  if [ "$1" = "$2" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: expected '$2', got '$1'" >&2
    echo "  at: $3" >&2
  fi
}

assert_contains() {
  if echo "$1" | grep -q "$2"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: '$1' does not contain '$2'" >&2
    echo "  at: $3" >&2
  fi
}

assert_exit() {
  if [ "$1" -eq "$2" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: exit code $1, expected $2" >&2
    echo "  at: $3" >&2
  fi
}

summary() {
  echo ""
  echo "Results: $PASS passed, $FAIL failed"
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
}

# --- Test: dependency check ---
output=$(SCURL_SOURCED=1 sh -c '. ./conf-scurl && check_deps' 2>&1)
assert_exit $? 0 "check_deps succeeds when deps present"

summary
