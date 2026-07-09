#!/bin/bash
# Simple temperature-aware fan control
# Saves you from melting your CPU while keeping noise low.
#
# Usage: run as a oneshot from cron every minute, or as a daemon.
#
#   crontab -e
#   * * * * * /usr/local/bin/temp-monitor.sh
#
# Or run in a loop (ctrl+c to stop):
#   while true; do ./temp-monitor.sh; sleep 30; done

set -euo pipefail

# ── config ──────────────────────────────────────────────
TEMP_IDLE=45          # below this → low speed
TEMP_WARM=55          # below this → medium speed
TEMP_HOT=65           # below this → high speed, above this → auto

LOW_PCT=10            # quiet
MED_PCT=20
HIGH_PCT=40

# ── read CPU temp ───────────────────────────────────────
TEMP=$(ipmitool sdr type temperature 2>/dev/null | \
       grep -i cpu | head -1 | \
       sed 's/.*| *\([0-9]\{1,3\}\) degrees.*/\1/')

if [ -z "$TEMP" ]; then
    TEMP=$(ipmitool sdr type temperature 2>/dev/null | \
           head -1 | \
           sed 's/.*| *\([0-9]\{1,3\}\) degrees.*/\1/')
fi

if [ -z "$TEMP" ]; then
    echo "temp-monitor: couldn't read CPU temperature, giving up"
    exit 1
fi

# ── decide speed ────────────────────────────────────────
if   [ "$TEMP" -gt "$TEMP_HOT" ]; then
    echo "temp-monitor: ${TEMP}°C → auto (BMC control)"
    ipmitool raw 0x3a 0x01 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00
elif [ "$TEMP" -gt "$TEMP_WARM" ]; then
    echo "temp-monitor: ${TEMP}°C → ${HIGH_PCT}%"
    ipmitool raw 0x3a 0x01 "$(printf '0x%02x' "$HIGH_PCT")" \
                                   "$(printf '0x%02x' "$HIGH_PCT")" \
                                   "$(printf '0x%02x' "$HIGH_PCT")" \
                                   "$(printf '0x%02x' "$HIGH_PCT")" \
                                   "$(printf '0x%02x' "$HIGH_PCT")" \
                                   "$(printf '0x%02x' "$HIGH_PCT")" \
                                   "$(printf '0x%02x' "$HIGH_PCT")" \
                                   "$(printf '0x%02x' "$HIGH_PCT")"
elif [ "$TEMP" -gt "$TEMP_IDLE" ]; then
    echo "temp-monitor: ${TEMP}°C → ${MED_PCT}%"
    ipmitool raw 0x3a 0x01 "$(printf '0x%02x' "$MED_PCT")" \
                                   "$(printf '0x%02x' "$MED_PCT")" \
                                   "$(printf '0x%02x' "$MED_PCT")" \
                                   "$(printf '0x%02x' "$MED_PCT")" \
                                   "$(printf '0x%02x' "$MED_PCT")" \
                                   "$(printf '0x%02x' "$MED_PCT")" \
                                   "$(printf '0x%02x' "$MED_PCT")" \
                                   "$(printf '0x%02x' "$MED_PCT")"
else
    echo "temp-monitor: ${TEMP}°C → ${LOW_PCT}%"
    ipmitool raw 0x3a 0x01 "$(printf '0x%02x' "$LOW_PCT")" \
                                   "$(printf '0x%02x' "$LOW_PCT")" \
                                   "$(printf '0x%02x' "$LOW_PCT")" \
                                   "$(printf '0x%02x' "$LOW_PCT")" \
                                   "$(printf '0x%02x' "$LOW_PCT")" \
                                   "$(printf '0x%02x' "$LOW_PCT")" \
                                   "$(printf '0x%02x' "$LOW_PCT")" \
                                   "$(printf '0x%02x' "$LOW_PCT")"
fi
