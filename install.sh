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

echo "Probing BMC for ASRock Rack OEM NetFn (0x3a)..."
probe_out=$(ipmitool raw 0x3a 0x01 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00 2>&1) || probe_rc=$?
probe_rc=${probe_rc:-0}
if [ "$probe_rc" -ne 0 ]; then
    if echo "$probe_out" | grep -qi 'invalid command'; then
        echo "install: BMC rejected NetFn 0x3a." >&2
        echo "  Your BMC firmware does not accept the ASRock Rack OEM command" >&2
        echo "  set this project targets (ThinkServer TMM)." >&2
        echo "  See TROUBLESHOOTING.md ('Invalid command')." >&2
        exit 1
    fi
    echo "install: cannot talk to BMC." >&2
    echo "  - ipmi_si not loaded:    sudo modprobe ipmi_si ipmi_devintf" >&2
    echo "  - IPMI disabled in BIOS: Server Mgmt -> BMC Settings" >&2
    echo "  - Need LAN access:       sudo ipmitool -I lanplus -H <ip> sdr list" >&2
    echo "  - BMC requires auth:     see TROUBLESHOOTING.md" >&2
    exit 1
fi
echo "  OK -- NetFn 0x3a accepted."

install -m 755 "$d/fanctl" /usr/local/bin/fanctl

mkdir -p /usr/local/lib/fanctl-systemd/systemd
for f in "$d"/systemd/*; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    case "$base" in
        fanctl-boot-apply.service)
            install -m 644 "$f" /etc/systemd/system/ ;;
        *)
            install -m 644 "$f" /usr/local/lib/fanctl-systemd/systemd/ ;;
    esac
done

install -m 755 -d /var/lib/fanctl

cat <<EOF

Installed.
  fanctl:        /usr/local/bin/fanctl
  schedule:      /usr/local/lib/fanctl-systemd/systemd/  (used by 'fanctl night')
  boot-restore:  /etc/systemd/system/fanctl-boot-apply.service
  state dir:     /var/lib/fanctl/   (holds last manual mode across reboots)

Next:
  fanctl night    # nightly schedule (23:00 -> 10%, 07:00 -> auto)
  fanctl 10       # set 10% now and persist for boot-restore
  systemctl enable --now fanctl-boot-apply.service
EOF
