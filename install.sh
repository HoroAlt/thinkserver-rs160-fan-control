#!/bin/bash
set -euo pipefail

echo "Installing fanctl to /usr/local/bin..."
cp fanctl /usr/local/bin/fanctl
chmod +x /usr/local/bin/fanctl

echo "Done. Run 'fanctl --help' to get started."
