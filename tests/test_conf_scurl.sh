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

# --- Test: config I/O ---
TEST_CONFIG_DIR=$(mktemp -d)
TEST_CONFIG_FILE="$TEST_CONFIG_DIR/config"

# Source conf-scurl functions
SCURL_SOURCED=1 . ./conf-scurl

# Test write_config
CONFIG_DIR="$TEST_CONFIG_DIR"
CONFIG_FILE="$TEST_CONFIG_FILE"
VERSION="8.20.0"
INSTALL_PATH="/tmp/test"
BINARY_NAME="scurl"
OS="linux"
ARCH="x86_64"
LIBC="glibc"

write_config
assert_contains "$(cat "$TEST_CONFIG_FILE")" "VERSION=8.20.0" "write_config writes VERSION"
assert_contains "$(cat "$TEST_CONFIG_FILE")" "INSTALL_PATH=/tmp/test" "write_config writes INSTALL_PATH"

# Test read_config
VERSION=""
INSTALL_PATH=""
read_config
assert_eq "$VERSION" "8.20.0" "read_config reads VERSION"
assert_eq "$INSTALL_PATH" "/tmp/test" "read_config reads INSTALL_PATH"

# Cleanup
rm -rf "$TEST_CONFIG_DIR"

# --- Test: platform detection ---
SCURL_SOURCED=1 . ./conf-scurl

detect_os
assert_contains "linux macos" "$OS" "detect_os returns linux or macos"

detect_arch
# Just verify it sets ARCH to something non-empty
if [ -n "$ARCH" ]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: detect_arch returned empty ARCH" >&2
fi

# --- Test: GitHub API ---
SCURL_SOURCED=1 . ./conf-scurl

# Test fetch_latest_version (requires network)
fetch_latest_version
if echo "$REMOTE_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: fetch_latest_version returned '$REMOTE_VERSION', expected semver" >&2
fi

# --- Test: download and install ---
SCURL_SOURCED=1 . ./conf-scurl

TEST_INSTALL_DIR=$(mktemp -d)
INSTALL_PATH="$TEST_INSTALL_DIR"
BINARY_NAME="scurl"
OS="linux"
ARCH="x86_64"
LIBC="glibc"

fetch_latest_version
VERSION="$REMOTE_VERSION"
get_download_url "$VERSION"
download_and_install

# Verify binary exists and is executable
if [ -x "$TEST_INSTALL_DIR/scurl" ]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: scurl not installed or not executable in $TEST_INSTALL_DIR" >&2
fi

# Cleanup
rm -rf "$TEST_INSTALL_DIR"

summary
