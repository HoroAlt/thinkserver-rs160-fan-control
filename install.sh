#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing fanctl to /usr/local/bin..."
cp "$SCRIPT_DIR/fanctl" /usr/local/bin/fanctl
chmod +x /usr/local/bin/fanctl

echo "Installing systemd units..."
cp -r "$SCRIPT_DIR/systemd" /usr/local/lib/fanctl-systemd

echo "Done. Run 'fanctl --help' to get started."
