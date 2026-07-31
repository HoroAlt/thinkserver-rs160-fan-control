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
# ponytail: probe sends the auto command (0x00), which hands fans back to BMC
# even if they were set manually. Most users are already at auto when running
# install, so this is benign in practice. Replace with a true read-only probe
# once an ASRock Rack "get fan speed" NetFn is documented.
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
echo "  OK -- NetFn 0x3a accepted (fans reset to BMC auto; this is expected)."

# fanctl binary -> /usr/local/bin
install -m 755 "$d/fanctl" /usr/local/bin/fanctl

# systemd units -> /etc/systemd/system/ (one place, no /usr/local/lib split)
for f in "$d"/systemd/*; do
    [ -f "$f" ] || continue
    install -m 644 "$f" /etc/systemd/system/
done

# state dir
install -m 755 -d /var/lib/fanctl

# schedule config (only if missing) — single key, sample value
SCHEDULE_FILE=/etc/default/fanctl
[ -f "$SCHEDULE_FILE" ] || printf 'NIGHT_PCT=10\n' > "$SCHEDULE_FILE"

cat <<'EOF'

Installed.

Next:
  fanctl 10                    # set 10 percent now
  fanctl night                 # nightly 23:00 -> 10%, 07:00 -> auto
  systemctl enable --now fanctl-boot-apply.service
EOF
