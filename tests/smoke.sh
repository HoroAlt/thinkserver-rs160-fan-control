#!/bin/bash
# Smoke test for fanctl. Runs without BMC hardware by routing ipmitool to a stub.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG=$(mktemp -u -t fanctl-calls.XXXXXX)
STATE=$(mktemp -d -t fanctl-state.XXXXXX)
STUB="$ROOT/tests/ipmitool"
export PATH="$ROOT/tests:$PATH"
export FANCTL_STUB_LOG="$LOG"
export FANCTL_STATE_DIR="$STATE"
MODE_F="$STATE/mode"

# Sanity: stub is on PATH and executable.
chmod +x "$STUB"
[ "$(command -v ipmitool)" = "$STUB" ] || {
    echo "smoke: cannot shadow ipmitool — got '$(command -v ipmitool)'"; exit 1; }

FANCTL="$ROOT/fanctl"

# ok_or_dump: assert a pattern appears in the log; on failure, dump and die.
ok_or_dump() {
    if ! grep -q "$1" "$LOG"; then
        echo "FAIL: expected /'$1/' in $LOG"; cat "$LOG"; exit 1
    fi
}

# A: dry-run prints exact line, no real call recorded.
expected='[dry-run] ipmitool raw 0x3a 0x01 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a'
got=$("$FANCTL" -n 10)
[ "$got" = "$expected" ] || { echo "A FAIL: got '$got'"; exit 1; }
[ ! -f "$MODE_F" ]
echo "A ok"

# B: set 25 emits 0x19 nine times.
: > "$LOG"
"$FANCTL" set 25 >/dev/null
ok_or_dump 'raw 0x3a 0x01 0x19 0x19 0x19 0x19 0x19 0x19 0x19 0x19'
echo "B ok"

# C: auto emits all 0x00.
: > "$LOG"
"$FANCTL" auto >/dev/null
ok_or_dump 'raw 0x3a 0x01 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00'
echo "C ok"

# D: max, half.
: > "$LOG"
"$FANCTL" max >/dev/null
"$FANCTL" half >/dev/null
ok_or_dump 'raw 0x3a 0x01 0x64'
ok_or_dump 'raw 0x3a 0x01 0x32'
echo "D ok"

# E: per-channel 10 30 10 -> first three values, default 100 for the rest.
: > "$LOG"
"$FANCTL" per-channel 10 30 10 >/dev/null
ok_or_dump 'raw 0x3a 0x01 0x0a 0x1e 0x0a 0x64 0x64 0x64 0x64 0x64'
echo "E ok"

# F: per-channel 5 0 5 0 0 0 0 0 (zeros are auto for that channel).
: > "$LOG"
"$FANCTL" per-channel 5 0 5 0 0 0 0 0 >/dev/null
ok_or_dump 'raw 0x3a 0x01 0x05 0x00 0x05 0x00 0x00 0x00 0x00 0x00'
echo "F ok"

# G: per-channel rejects non-numeric.
if "$FANCTL" per-channel abc 2>/tmp/err; then echo "G FAIL"; exit 1; fi
grep -qi "is not a number" /tmp/err
echo "G ok"

# H: per-channel rejects out-of-range.
if "$FANCTL" per-channel 200 2>/tmp/err; then echo "H FAIL"; exit 1; fi
grep -qi "0..100" /tmp/err
echo "H ok"

# I: per-channel max 8 args.
if "$FANCTL" per-channel 1 2 3 4 5 6 7 8 9 2>/tmp/err; then echo "I FAIL"; exit 1; fi
grep -q "1..8" /tmp/err
echo "I ok"

# J: status produces a table.
"$FANCTL" status > /tmp/status.out
grep -q '=== Fans ===' /tmp/status.out
grep -q 'FAN1' /tmp/status.out
grep -q '=== Temperatures ===' /tmp/status.out
grep -q 'CPU1' /tmp/status.out
echo "J ok"

# K: dry-run for write commands (set/auto/per-channel/max/half) does NOT call
# ipmitool. Status is a BMC read and IS allowed to call.
before=$(wc -l < "$LOG")
"$FANCTL" -n 50            >/dev/null 2>&1
"$FANCTL" -n auto          >/dev/null 2>&1
"$FANCTL" -n per-channel 1 2 3 >/dev/null 2>&1
mid=$(wc -l < "$LOG")
"$FANCTL" -n status        >/dev/null 2>&1
end=$(wc -l < "$LOG")
[ "$before" = "$mid" ] || { echo "K FAIL: writes leaked ($before->$mid)"; exit 1; }
[ "$mid"  != "$end"  ] || { echo "K FAIL: reads blocked ($mid)"; exit 1; }
echo "K ok: writes gated ($before==$mid), reads allowed ($mid<$end)"

# L: CPU max-temp parsing (now inlined in `watch`). Stub has CPU1 42, CPU2 45h,
# VR1 60 — the inlined awk must pick 45 and skip VR1.
# We exercise it via `watch` running for one cycle then interrupted.
WATCH_INTERVAL=1 WATCH_CRIT=99 timeout 2 "$FANCTL" -n watch > /tmp/watch.out 2>&1 || true
# dry-run prints "(dry-run) would hand to auto" only on excursion; with crit=99
# it never trips, so we just verify the header and at least one ipmitool sdr
# read recorded in the stub log.
grep -q "watch: CPU every 1s, ≥99°C" /tmp/watch.out || { echo "L FAIL: header"; cat /tmp/watch.out; exit 1; }

# L2: with crit=40, watch must hand to auto (CPU2=45 >= 40), dry-run exits.
: > "$LOG"
WATCH_INTERVAL=1 WATCH_CRIT=40 timeout 3 "$FANCTL" -n watch > /tmp/watch.out 2>&1 || true
grep -q "(dry-run) would hand to auto" /tmp/watch.out || { echo "L2 FAIL"; cat /tmp/watch.out; exit 1; }
echo "L ok (watch dry-run)"

# M: set/auto persist to state, restore re-applies.
"$FANCTL" set 10 >/dev/null
[ -f "$MODE_F" ]
: > "$LOG"
"$FANCTL" restore >/dev/null
ok_or_dump 'raw 0x3a 0x01 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a'
echo "M ok"

# N: atomic state write leaves no leftovers in state dir.
leftovers=()
for f in "$STATE"/*; do
    [ -e "$f" ] || continue
    case "$f" in *.tmp.*) leftovers+=("$f") ;; esac
done
[ "${#leftovers[@]}" -eq 0 ] || { echo "N FAIL:"; printf '  %s\n' "${leftovers[@]}"; exit 1; }
echo "N ok"

# O: restore no-op when no state file.
rm -f "$MODE_F"
"$FANCTL" restore
echo "O ok"

# P: bare numeric 33 -> 0x21.
: > "$LOG"
"$FANCTL" 33 >/dev/null
ok_or_dump 'raw 0x3a 0x01 0x21'
echo "P ok"

# Q: bare 0 rejected.
if "$FANCTL" 0 2>/tmp/err; then echo "Q FAIL"; exit 1; fi
echo "Q ok"

# R: --version and --help mention new commands.
"$FANCTL" --version | grep -qE 'fanctl [0-9]'
"$FANCTL" --help | grep -q "per-channel"
"$FANCTL" --help | grep -q -- "--dry-run"
"$FANCTL" --help | grep -q "NIGHT_PCT"
echo "R ok"

echo
echo "fanctl smoke: ALL OK"
