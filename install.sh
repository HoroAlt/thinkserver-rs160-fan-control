#!/bin/bash
set -euo pipefail
d=$(cd "$(dirname "$0")" && pwd)
install -m 755 "$d/fanctl" /usr/local/bin/fanctl
mkdir -p /usr/local/lib/fanctl-systemd
cp -r "$d/systemd" /usr/local/lib/fanctl-systemd/
echo "Installed fanctl. Run 'fanctl night' to enable night mode."