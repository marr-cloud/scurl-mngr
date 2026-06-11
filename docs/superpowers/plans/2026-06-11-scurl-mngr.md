# scurl-mngr Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a POSIX sh CLI (`conf-scurl`) that manages static-curl installations, plus a bootstrap script (`install.sh`).

**Architecture:** Two standalone shell scripts. `conf-scurl` is the main monolith with all logic (config management, platform detection, GitHub API interaction, download/install). `install.sh` is a minimal bootstrap that places `conf-scurl` and triggers first install.

**Tech Stack:** POSIX sh, jq, curl/wget, tar, GitHub Releases API

---

## File Structure

| File | Responsibility |
|------|---------------|
| `conf-scurl` | Main CLI: commands (install, update, remove, status, config), platform detection, GitHub API queries, download+extract logic, config file I/O |
| `install.sh` | Bootstrap: dependency check, download `conf-scurl`, trigger first install |
| `tests/test_conf_scurl.sh` | Integration tests using a test harness (shell-based) |
| `README.md` | Usage documentation |

---

### Task 1: Project scaffolding and test harness

**Files:**
- Create: `tests/test_conf_scurl.sh`
- Create: `conf-scurl`
- Create: `.gitignore`

- [ ] **Step 1: Create .gitignore**

```bash
# .gitignore
*.tar.xz
tmp/
```

- [ ] **Step 2: Create minimal test harness**

```sh
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

# Tests will be added in subsequent tasks

summary
```

- [ ] **Step 3: Create empty conf-scurl with shebang**

```sh
#!/bin/sh
set -eu
```

- [ ] **Step 4: Run tests to verify harness works**

Run: `chmod +x tests/test_conf_scurl.sh && sh tests/test_conf_scurl.sh`
Expected: `Results: 0 passed, 0 failed` with exit 0

- [ ] **Step 5: Commit**

```bash
git add .gitignore conf-scurl tests/test_conf_scurl.sh
git commit -m "chore: project scaffolding and test harness"
```

---

### Task 2: Dependency checking

**Files:**
- Modify: `conf-scurl`
- Modify: `tests/test_conf_scurl.sh`

- [ ] **Step 1: Write failing test for dependency check**

Append to `tests/test_conf_scurl.sh` (before `summary`):

```sh
# --- Test: dependency check ---
output=$(SCURL_SOURCED=1 sh -c '. ./conf-scurl && check_deps' 2>&1)
assert_exit $? 0 "check_deps succeeds when deps present"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `sh tests/test_conf_scurl.sh`
Expected: FAIL (check_deps not defined)

- [ ] **Step 3: Implement check_deps in conf-scurl**

```sh
#!/bin/sh
set -eu

check_deps() {
  missing=""
  command -v jq >/dev/null 2>&1 || missing="$missing jq"
  command -v tar >/dev/null 2>&1 || missing="$missing tar"
  if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    missing="$missing curl/wget"
  fi
  if [ -n "$missing" ]; then
    echo "Error: missing required dependencies:$missing" >&2
    echo "Install with:" >&2
    echo "  Debian/Ubuntu: apt install jq curl tar xz-utils" >&2
    echo "  macOS: brew install jq curl" >&2
    echo "  Alpine: apk add jq curl tar xz" >&2
    return 1
  fi
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `sh tests/test_conf_scurl.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add conf-scurl tests/test_conf_scurl.sh
git commit -m "feat: add dependency checking"
```

---

### Task 3: Config file I/O

**Files:**
- Modify: `conf-scurl`
- Modify: `tests/test_conf_scurl.sh`

- [ ] **Step 1: Write failing tests for config read/write**

Append to `tests/test_conf_scurl.sh` (before `summary`):

```sh
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `sh tests/test_conf_scurl.sh`
Expected: FAIL (write_config/read_config not defined)

- [ ] **Step 3: Implement config I/O functions**

Add to `conf-scurl`:

```sh
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/scurl"
CONFIG_FILE="$CONFIG_DIR/config"

write_config() {
  mkdir -p "$CONFIG_DIR"
  cat > "$CONFIG_FILE" <<EOF
VERSION=$VERSION
INSTALL_PATH=$INSTALL_PATH
BINARY_NAME=$BINARY_NAME
OS=$OS
ARCH=$ARCH
LIBC=$LIBC
EOF
}

read_config() {
  if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
  fi
}

config_exists() {
  [ -f "$CONFIG_FILE" ]
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `sh tests/test_conf_scurl.sh`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add conf-scurl tests/test_conf_scurl.sh
git commit -m "feat: add config file read/write"
```

---

### Task 4: Platform detection

**Files:**
- Modify: `conf-scurl`
- Modify: `tests/test_conf_scurl.sh`

- [ ] **Step 1: Write failing tests for platform detection**

Append to `tests/test_conf_scurl.sh` (before `summary`):

```sh
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `sh tests/test_conf_scurl.sh`
Expected: FAIL (detect_os/detect_arch not defined)

- [ ] **Step 3: Implement platform detection**

Add to `conf-scurl`:

```sh
detect_os() {
  case "$(uname -s)" in
    Linux)  OS="linux" ;;
    Darwin) OS="macos" ;;
    *)      echo "Error: unsupported OS '$(uname -s)'" >&2; return 1 ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    x86_64)         ARCH="x86_64" ;;
    aarch64|arm64)  ARCH="aarch64" ;;
    armv7l)         ARCH="armv7" ;;
    i686|i386)      ARCH="i686" ;;
    *)              echo "Error: unsupported architecture '$(uname -m)'" >&2; return 1 ;;
  esac
}

detect_libc() {
  if [ "$OS" != "linux" ]; then
    LIBC=""
    return
  fi
  if ldd --version 2>&1 | grep -qi musl; then
    suggested="musl"
  else
    suggested="glibc"
  fi
  printf "LibC detected: %s. Use this? [Y/n] " "$suggested"
  read -r answer
  case "$answer" in
    [nN]*) 
      if [ "$suggested" = "glibc" ]; then LIBC="musl"; else LIBC="glibc"; fi
      ;;
    *)
      LIBC="$suggested"
      ;;
  esac
}

asset_arch() {
  # macOS assets use "arm64" not "aarch64"
  if [ "$OS" = "macos" ] && [ "$ARCH" = "aarch64" ]; then
    echo "arm64"
  else
    echo "$ARCH"
  fi
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `sh tests/test_conf_scurl.sh`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add conf-scurl tests/test_conf_scurl.sh
git commit -m "feat: add platform detection"
```

---

### Task 5: GitHub API interaction

**Files:**
- Modify: `conf-scurl`
- Modify: `tests/test_conf_scurl.sh`

- [ ] **Step 1: Write failing test for fetching latest version**

Append to `tests/test_conf_scurl.sh` (before `summary`):

```sh
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `sh tests/test_conf_scurl.sh`
Expected: FAIL (fetch_latest_version not defined)

- [ ] **Step 3: Implement GitHub API functions**

Add to `conf-scurl`:

```sh
REPO="stunnel/static-curl"
API_URL="https://api.github.com/repos/$REPO/releases"

http_get() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1"
  else
    wget -qO- "$1"
  fi
}

fetch_latest_version() {
  REMOTE_VERSION=$(http_get "$API_URL/latest" | jq -r '.tag_name')
  if [ -z "$REMOTE_VERSION" ] || [ "$REMOTE_VERSION" = "null" ]; then
    echo "Error: cannot reach GitHub API. Check your internet connection." >&2
    return 1
  fi
}

get_download_url() {
  _version="${1:-$REMOTE_VERSION}"
  _arch=$(asset_arch)
  if [ "$OS" = "linux" ]; then
    _pattern="curl-${OS}-${_arch}-${LIBC}-${_version}.tar.xz"
  else
    _pattern="curl-${OS}-${_arch}-${_version}.tar.xz"
  fi
  DOWNLOAD_URL=$(http_get "$API_URL/tags/$_version" | jq -r --arg name "$_pattern" '.assets[] | select(.name == $name) | .browser_download_url')
  if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
    echo "Error: no release found for $_pattern" >&2
    echo "Available assets for $_version:" >&2
    http_get "$API_URL/tags/$_version" | jq -r '.assets[].name' >&2
    return 1
  fi
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `sh tests/test_conf_scurl.sh`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add conf-scurl tests/test_conf_scurl.sh
git commit -m "feat: add GitHub API interaction"
```

---

### Task 6: Download and install logic

**Files:**
- Modify: `conf-scurl`
- Modify: `tests/test_conf_scurl.sh`

- [ ] **Step 1: Write failing test for download function**

Append to `tests/test_conf_scurl.sh` (before `summary`):

```sh
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `sh tests/test_conf_scurl.sh`
Expected: FAIL (download_and_install not defined)

- [ ] **Step 3: Implement download_and_install**

Add to `conf-scurl`:

```sh
download_and_install() {
  _tmpdir=$(mktemp -d)
  _archive="$_tmpdir/curl.tar.xz"
  echo "Downloading $(basename "$DOWNLOAD_URL")..."
  http_get "$DOWNLOAD_URL" > "$_archive"
  tar -xJf "$_archive" -C "$_tmpdir"
  # Find the curl binary in extracted contents
  _bin=$(find "$_tmpdir" -name "curl" -type f | head -1)
  if [ -z "$_bin" ]; then
    echo "Error: curl binary not found in archive" >&2
    rm -rf "$_tmpdir"
    return 1
  fi
  mkdir -p "$INSTALL_PATH"
  mv "$_bin" "$INSTALL_PATH/$BINARY_NAME"
  chmod +x "$INSTALL_PATH/$BINARY_NAME"
  rm -rf "$_tmpdir"
  echo "✓ $BINARY_NAME v$VERSION installed in $INSTALL_PATH/$BINARY_NAME"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `sh tests/test_conf_scurl.sh`
Expected: All PASS (requires network — downloads real binary)

- [ ] **Step 5: Commit**

```bash
git add conf-scurl tests/test_conf_scurl.sh
git commit -m "feat: add download and install logic"
```

---

### Task 7: Command dispatch and install command

**Files:**
- Modify: `conf-scurl`
- Modify: `tests/test_conf_scurl.sh`

- [ ] **Step 1: Write failing test for command dispatch**

Append to `tests/test_conf_scurl.sh` (before `summary`):

```sh
# --- Test: command dispatch ---
output=$(sh ./conf-scurl status 2>&1) || true
assert_contains "$output" "scurl" "status command produces output"

output=$(sh ./conf-scurl --help 2>&1) || true
assert_contains "$output" "Usage" "help shows usage"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `sh tests/test_conf_scurl.sh`
Expected: FAIL

- [ ] **Step 3: Implement command dispatch and install command**

Add a sourcing guard at the end of `conf-scurl`. Wrap the dispatch in a check so that sourcing the file (for tests) doesn't trigger command execution:

```sh
usage() {
  cat <<EOF
Usage: conf-scurl <command> [args]

Commands:
  install [version]  Install scurl (latest or specific version)
  update             Update to latest version
  remove             Remove scurl and conf-scurl
  status             Show installed version and update availability
  config [key] [val] View or edit configuration

EOF
}

cmd_install() {
  _target_version="${1:-}"
  check_deps
  if config_exists; then
    read_config
  else
    detect_os
    detect_arch
    detect_libc
    INSTALL_PATH="${INSTALL_PATH:-$HOME/.local/bin}"
    BINARY_NAME="${BINARY_NAME:-scurl}"
    printf "Install path [%s]: " "$INSTALL_PATH"
    read -r _path
    [ -n "$_path" ] && INSTALL_PATH="$_path"
  fi
  if [ -n "$_target_version" ]; then
    VERSION="$_target_version"
    REMOTE_VERSION="$_target_version"
  else
    fetch_latest_version
    VERSION="$REMOTE_VERSION"
  fi
  get_download_url "$VERSION"
  download_and_install
  write_config
}

cmd_update() {
  check_deps
  if ! config_exists; then
    echo "Error: scurl not installed. Run 'conf-scurl install' first." >&2
    return 1
  fi
  read_config
  fetch_latest_version
  if [ "$VERSION" = "$REMOTE_VERSION" ]; then
    echo "$BINARY_NAME v$VERSION is already the latest version."
    return 0
  fi
  echo "Updating $BINARY_NAME v$VERSION → v$REMOTE_VERSION..."
  VERSION="$REMOTE_VERSION"
  get_download_url "$VERSION"
  download_and_install
  write_config
}

cmd_remove() {
  if ! config_exists; then
    echo "Error: scurl not installed." >&2
    return 1
  fi
  read_config
  rm -f "$INSTALL_PATH/$BINARY_NAME"
  rm -f "$INSTALL_PATH/conf-scurl"
  rm -rf "$CONFIG_DIR"
  echo "✓ $BINARY_NAME removed."
}

cmd_status() {
  if ! config_exists; then
    echo "scurl is not installed. Run 'conf-scurl install'."
    return 0
  fi
  read_config
  echo "$BINARY_NAME v$VERSION"
  echo "Path: $INSTALL_PATH/$BINARY_NAME"
  printf "OS: %s | Arch: %s" "$OS" "$ARCH"
  [ -n "${LIBC:-}" ] && printf " | LibC: %s" "$LIBC"
  echo ""
  if fetch_latest_version 2>/dev/null; then
    if [ "$VERSION" = "$REMOTE_VERSION" ]; then
      echo "Latest available: v$REMOTE_VERSION (up to date)"
    else
      echo "Latest available: v$REMOTE_VERSION (update available!)"
    fi
  else
    echo "Latest available: (could not check — no network?)"
  fi
}

cmd_config() {
  if ! config_exists; then
    echo "Error: no configuration found. Run 'conf-scurl install' first." >&2
    return 1
  fi
  if [ $# -eq 0 ]; then
    cat "$CONFIG_FILE"
  elif [ $# -eq 1 ]; then
    grep "^${1}=" "$CONFIG_FILE" | cut -d= -f2-
  else
    _key="$1"
    _val="$2"
    if grep -q "^${_key}=" "$CONFIG_FILE"; then
      sed -i "s|^${_key}=.*|${_key}=${_val}|" "$CONFIG_FILE"
    else
      echo "${_key}=${_val}" >> "$CONFIG_FILE"
    fi
    echo "✓ ${_key}=${_val}"
  fi
}

# Only run dispatch when executed directly (not sourced)
if [ "${SCURL_SOURCED:-0}" != "1" ]; then
  case "${1:-}" in
    install) shift; cmd_install "$@" ;;
    update)  cmd_update ;;
    remove)  cmd_remove ;;
    status)  cmd_status ;;
    config)  shift; cmd_config "$@" ;;
    --help|-h|"") usage ;;
    *)       echo "Error: unknown command '$1'" >&2; usage; exit 1 ;;
  esac
fi
```

Note: Tests source the script with `SCURL_SOURCED=1 . ./conf-scurl` to access functions without triggering dispatch.

- [ ] **Step 4: Run test to verify it passes**

Run: `sh tests/test_conf_scurl.sh`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add conf-scurl tests/test_conf_scurl.sh
git commit -m "feat: add command dispatch and all commands"
```

---

### Task 8: Bootstrap install script

**Files:**
- Create: `install.sh`
- Modify: `tests/test_conf_scurl.sh`

- [ ] **Step 1: Write test for install.sh syntax validity**

Append to `tests/test_conf_scurl.sh` (before `summary`):

```sh
# --- Test: install.sh syntax ---
sh -n ./install.sh 2>&1
assert_exit $? 0 "install.sh has valid syntax"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `sh tests/test_conf_scurl.sh`
Expected: FAIL (install.sh does not exist)

- [ ] **Step 3: Create install.sh**

```sh
#!/bin/sh
set -eu

REPO="marr-cloud/scurl-mngr"
DEFAULT_PATH="$HOME/.local/bin"

echo "scurl-mngr installer"
echo "===================="

# Check dependencies
for cmd in jq tar; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: '$cmd' is required but not found." >&2
    echo "  Debian/Ubuntu: apt install jq tar xz-utils" >&2
    echo "  macOS: brew install jq" >&2
    echo "  Alpine: apk add jq tar xz" >&2
    exit 1
  fi
done
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
  echo "Error: 'curl' or 'wget' is required but neither found." >&2
  exit 1
fi

printf "Install path [%s]: " "$DEFAULT_PATH"
read -r INSTALL_PATH
INSTALL_PATH="${INSTALL_PATH:-$DEFAULT_PATH}"
mkdir -p "$INSTALL_PATH"

# Download conf-scurl
echo "Downloading conf-scurl..."
CONF_URL="https://raw.githubusercontent.com/$REPO/main/conf-scurl"
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$CONF_URL" -o "$INSTALL_PATH/conf-scurl"
else
  wget -qO "$INSTALL_PATH/conf-scurl" "$CONF_URL"
fi
chmod +x "$INSTALL_PATH/conf-scurl"

echo "conf-scurl installed to $INSTALL_PATH/conf-scurl"

# Ensure path is available for immediate use
export PATH="$INSTALL_PATH:$PATH"

# Run first install
"$INSTALL_PATH/conf-scurl" install
```

- [ ] **Step 4: Run test to verify it passes**

Run: `sh tests/test_conf_scurl.sh`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add install.sh tests/test_conf_scurl.sh
git commit -m "feat: add bootstrap install script"
```

---

### Task 9: README and final cleanup

**Files:**
- Create: `README.md`
- Modify: `conf-scurl` (add chmod +x)

- [ ] **Step 1: Create README.md**

```markdown
# scurl-mngr

Manage [static-curl](https://github.com/stunnel/static-curl) installations.

## Quick Install

```sh
curl -fsSL https://raw.githubusercontent.com/marr-cloud/scurl-mngr/main/install.sh | sh
```

## Requirements

- `jq`
- `curl` or `wget`
- `tar` with xz support

## Commands

```
conf-scurl install [version]  # Install (latest or specific version)
conf-scurl update             # Update to latest version
conf-scurl remove             # Remove scurl and conf-scurl
conf-scurl status             # Show version and update info
conf-scurl config [key] [val] # View or edit configuration
```

## Configuration

Stored in `~/.config/scurl/config`:

| Key | Description |
|-----|-------------|
| VERSION | Installed version |
| INSTALL_PATH | Directory for binaries |
| BINARY_NAME | Name of the curl binary (default: scurl) |
| OS | Operating system |
| ARCH | Architecture |
| LIBC | C library (Linux only: glibc/musl) |
```

- [ ] **Step 2: Make conf-scurl executable**

Run: `chmod +x conf-scurl install.sh`

- [ ] **Step 3: Run full test suite**

Run: `sh tests/test_conf_scurl.sh`
Expected: All PASS, 0 failures

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: add README"
```

- [ ] **Step 5: Final integration test (manual)**

Run the full install flow in a temp directory:

```bash
TEST_DIR=$(mktemp -d)
INSTALL_PATH="$TEST_DIR" sh install.sh
# Verify scurl works
"$TEST_DIR/scurl" --version
# Verify status
"$TEST_DIR/conf-scurl" status
# Cleanup
rm -rf "$TEST_DIR"
```

Expected: scurl reports version, status shows installed info.
