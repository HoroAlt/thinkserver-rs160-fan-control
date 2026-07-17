#!/bin/bash
set -euo pipefail
d=$(cd "$(dirname "$0")" && pwd)

command -v ipmitool >/dev/null || {
    echo "install: ipmitool not found." >&2
    echo "  Install it first:" >&2
    echo "    sudo apt install ipmitool      # Debian/Ubuntu" >&2
    echo "    sudo dnf install ipmitool      # RHEL/Fedora" >&2
    exit 1
}

if ! lsmod | grep -q ipmi_si; then
    echo "install: WARNING — ipmi_si kernel module not loaded." >&2
    echo "  ipmitool will fail until you load it:" >&2
    echo "    sudo modprobe ipmi_si ipmi_devintf" >&2
fi

install -m 755 "$d/fanctl" /usr/local/bin/fanctl
mkdir -p /usr/local/lib/fanctl-systemd
cp -r "$d/systemd" /usr/local/lib/fanctl-systemd/

# Smoke test: read-only BMC query, confirms IPMI access works
if ipmitool sdr list >/dev/null 2>&1; then
    echo "Installed fanctl. BMC responding. Run 'fanctl night' to enable night mode."
else
    echo "Installed fanctl." >&2
    echo "" >&2
    echo "WARNING: BMC is not responding. fanctl will fail until you fix one of:" >&2
    echo "  - ipmi_si module not loaded:    sudo modprobe ipmi_si ipmi_devintf" >&2
    echo "  - IPMI disabled in BIOS:        Server Mgmt → BMC Settings" >&2
    echo "  - Need LAN access (KVM-only):   sudo ipmitool -I lanplus -H <ip> sdr list" >&2
    echo "  - BMC requires auth:            see TROUBLESHOOTING.md" >&2
fi