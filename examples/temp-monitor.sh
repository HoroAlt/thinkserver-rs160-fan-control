#!/bin/bash
set -euo pipefail

TEMP_IDLE=45
TEMP_WARM=55
TEMP_HOT=65
LOW_PCT=10
MED_PCT=20
HIGH_PCT=40

TEMP=$(ipmitool sdr type temperature 2>/dev/null | \
       grep -i cpu | head -1 | \
       sed 's/.*| *\([0-9]\{1,3\}\) degrees.*/\1/')

if [ -z "$TEMP" ]; then
    echo "temp-monitor: couldn't read CPU temperature, giving up"
    exit 1
fi

set_pct() {
    local h=$(printf '0x%02x' "$1")
    ipmitool raw 0x3a 0x01 "$h" "$h" "$h" "$h" "$h" "$h" "$h" "$h"
}

if   [ "$TEMP" -gt "$TEMP_HOT"  ]; then echo "temp-monitor: ${TEMP}°C → auto (BMC control)"; set_pct 0
elif [ "$TEMP" -gt "$TEMP_WARM" ]; then echo "temp-monitor: ${TEMP}°C → ${HIGH_PCT}%";  set_pct "$HIGH_PCT"
elif [ "$TEMP" -gt "$TEMP_IDLE" ]; then echo "temp-monitor: ${TEMP}°C → ${MED_PCT}%";   set_pct "$MED_PCT"
else                                  echo "temp-monitor: ${TEMP}°C → ${LOW_PCT}%";   set_pct "$LOW_PCT"
fi