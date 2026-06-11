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

if [ -t 0 ] || [ -e /dev/tty ]; then
  printf "Install path [%s]: " "$DEFAULT_PATH"
  INSTALL_PATH=$(sh -c 'read -r p < /dev/tty; echo "$p"' 2>/dev/null) || INSTALL_PATH=""
else
  INSTALL_PATH=""
fi
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
