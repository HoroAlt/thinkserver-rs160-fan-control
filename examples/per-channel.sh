#!/bin/bash
# Set different speeds per fan channel.
#
# RS160 usually only has 3 fans connected (channels 0,1,2).
# Leftover channels don't do anything.
#
# Examples:
#
#   ./per-channel.sh
#     (runs the default below)
#
#   ./per-channel.sh 10 20 30
#     FAN1=10%, FAN2=20%, FAN3=30%, rest=0

set -euo pipefail

# ── defaults: FAN1=10%, FAN2=30%, FAN3=10%, rest=0 ──
CH0="${1:-10}"
CH1="${2:-30}"
CH2="${3:-10}"
CH3="${4:-0}"
CH4="${5:-0}"
CH5="${6:-0}"
CH6="${7:-0}"
CH7="${8:-0}"

to_hex() { printf '0x%02x' "$1"; }

echo "Setting: FAN1=${CH0}%  FAN2=${CH1}%  FAN3=${CH2}%  ch3=${CH3}%  ch4=${CH4}%  ch5=${CH5}%  ch6=${CH6}%  ch7=${CH7}%"
ipmitool raw 0x3a 0x01 \
    "$(to_hex "$CH0")" "$(to_hex "$CH1")" "$(to_hex "$CH2")" "$(to_hex "$CH3")" \
    "$(to_hex "$CH4")" "$(to_hex "$CH5")" "$(to_hex "$CH6")" "$(to_hex "$CH7")"
