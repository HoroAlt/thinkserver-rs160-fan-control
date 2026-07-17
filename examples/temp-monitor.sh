#!/bin/bash
# ponytail: set_pct here mirrors fanctl: keep in sync if protocol changes.
set -euo pipefail

TEMP_IDLE=45
TEMP_WARM=55
TEMP_HOT=65
HYST=5
LOW_PCT=10
MED_PCT=20
HIGH_PCT=40

STATE_DIR="${FANCTL_STATE_DIR:-/var/lib/fanctl}"
STATE_FILE="$STATE_DIR/temp-monitor-mode"

command -v ipmitool >/dev/null || { echo "temp-monitor: ipmitool not found" >&2; exit 1; }

TEMP=$(ipmitool sdr type temperature 2>/dev/null | \
       grep -iE 'cpu' | \
       sed -nE 's/.*\| *([0-9]{1,3}) degrees.*/\1/p' | \
       sort -rn | head -1)

if [ -z "$TEMP" ]; then
    echo "temp-monitor: no CPU temperature, no change"
    exit 0
fi

LAST=$(cat "$STATE_FILE" 2>/dev/null || true)

target=$LOW_PCT
if   [ "$TEMP" -gt "$TEMP_HOT"  ]; then target=auto
elif [ "$TEMP" -gt "$TEMP_WARM" ]; then target=$HIGH_PCT
elif [ "$TEMP" -gt "$TEMP_IDLE" ]; then target=$MED_PCT
fi

case "${LAST:-start}:${target}" in
    start:*|auto:auto|*:auto) ;;     # first run, or already at auto
    *:"$LAST") ;;                     # no change
    *)  case "$LAST:$target" in
            "$HIGH_PCT:$MED_PCT"|"$HIGH_PCT:$LOW_PCT")
                [ "$TEMP" -lt "$((TEMP_WARM - HYST))" ] || target=$LAST ;;
            "$MED_PCT:$LOW_PCT")
                [ "$TEMP" -lt "$((TEMP_IDLE - HYST))" ] || target=$LAST ;;
            "auto:"*)
                # ponytail: gate exiting auto by extra HYST to suppress edge oscillation
                [ "$TEMP" -lt "$((TEMP_HOT - 2 * HYST))" ] || target=$LAST ;;
        esac ;;
esac

[ -n "${LAST:-}" ] && [ "$LAST" = "$target" ] && exit 0

# ponytail: state dir bootstrap; silently skipped if not writable (cron-style deploys).
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true

set_pct() {
    if [ "$1" = auto ]; then
        ipmitool raw 0x3a 0x01 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00
        return
    fi
    local h
    h=$(printf '0x%02x' "$1")
    ipmitool raw 0x3a 0x01 "$h" "$h" "$h" "$h" "$h" "$h" "$h" "$h"
}

echo "temp-monitor: ${TEMP}°C -> ${target}% (was ${LAST:-unset})"
set_pct "$target"
printf '%s\n' "$target" > "$STATE_FILE" 2>/dev/null || true
