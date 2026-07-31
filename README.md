# thinkserver-rs160-fan-control

[![CI](https://github.com/HoroAlt/thinkserver-rs160-fan-control/actions/workflows/ci.yml/badge.svg)](https://github.com/HoroAlt/thinkserver-rs160-fan-control/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![BMC verified](https://img.shields.io/badge/BMC-1.36%7C2.50%7C3.20-informational.svg)](#compatibility)

> Quiet fans on a Lenovo ThinkServer RS160 via IPMI. Tested on Proxmox VE;
> BMC firmware 1.36 / 2.50 / 3.20.

If your RS160 sounds like a hairdryer at idle and Lenovo's web UI offers no
fan profile, this is for you.

## Contents

- [Features](#features)
- [Why this exists](#why-this-exists)
- [Compatibility](#compatibility)
- [Quick check](#quick-check)
- [Install](#install)
- [Commands](#commands)
- [Configuration](#configuration)
- [Benchmarks](#benchmarks)
- [⚠️ Safety](#safety)
- [Troubleshooting](#troubleshooting)
- [License](#license)
- [Acknowledgments](#acknowledgments)

## Features

- **`fanctl <1-100>`** — set every fan to N percent. No hex, no PWM curves.
- **`fanctl per-channel <p0> ... <p7>`** — different speeds per channel, or
  `0` to hand one channel back to the BMC.
- **`fanctl -n` / `--dry-run`** — preview the `ipmitool` call without sending.
- **`fanctl set <N>`, `max`, `half`, `auto`** — the four commands you'll
  reach for in practice.
- **`fanctl status`** — RPM and temperatures as a table, no manual
  `ipmitool sdr list` chaff.
- **Boot-restore** (`fanctl-boot-apply.service`) — your last manual mode
  survives a reboot. State lives in `/var/lib/fanctl/mode`, written atomically.
- **Night schedule** via systemd timers (`fanctl night` → 23:00 / `fanctl day`
  → disable). The night-mode percent comes from `/etc/default/fanctl`, no
  reinstalling.
- **Watchdog** (`fanctl watch`) — polls CPU temp via IPMI, hands control
  back to BMC auto at a configurable threshold. Defaults: 10s, 85°C.

## Why this exists

RS160 fans sit at 7800–8400 RPM at idle. There's no fan profile in the web
UI, and standard IPMI raw commands all return `Invalid command` from this
BMC. The fix uses an undocumented ASRock Rack OEM NetFn (`0x3a`) that
Lenovo's ThinkServer TMM firmware accepts. Lenovo doesn't publish it;
ASRock Rack's own [FAQ](https://www.asrockrack.com/support/faq.asp?k=ipmitool)
does.

## Compatibility

Tested on **Proxmox VE + Lenovo ThinkServer RS160** (BMC firmware 1.36 /
2.50 / 3.20). It works there.

The fan-control mechanism is a firmware-specific OEM NetFn (`0x3a`) that
ThinkServer TMM happens to accept. Behavior on other BMCs and distributions
isn't guaranteed, since the protocol isn't published by Lenovo.

- **Proxmox VE + ThinkServer RS160, `install.sh` failing?** See
  [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
- **Different hardware or hypervisor?** Fix-it-yourself project. The
  protocol bytes are visible in `fanctl`, the install steps assume a
  Debian/Ubuntu layout with systemd, and common gotchas are listed in
  [TROUBLESHOOTING.md](TROUBLESHOOTING.md). Patches and PRs that add
  support for other distributions or BMC firmware versions are welcome.
- **Porting to something else?** Start from the ASRock Rack command
  reference at <https://www.asrockrack.com/support/faq.asp?k=ipmitool>.

## Quick check

Before installing, confirm the BMC accepts the NetFn this tool relies on:

```bash
sudo ipmitool raw 0x3a 0x01 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a
```

Fans should drop to ~3000 RPM. If you see `Invalid command`, your BMC
firmware doesn't accept this NetFn — stop here, `fanctl` won't help.

## Install

Get on your Proxmox VE host (e.g. over SSH as `root`) and run the four
blocks below. Each is small; copy-paste them one at a time if you'd rather
see what's happening.

```bash
# 1. Prereqs. On Proxmox VE / Debian / Ubuntu both are usually already
#    installed; the line below is the worst case.
sudo apt update
sudo apt install -y ipmitool git

# Kernel modules for the BMC interface — not always auto-loaded.
sudo modprobe ipmi_si ipmi_devintf
# Persist across reboots:
echo -e "ipmi_si\nipmi_devintf" | sudo tee /etc/modules-load.d/ipmi.conf

# 2. Clone this repo. HTTPS is fine; SSH works if you have a GitHub key
#    on the server (rare, so HTTPS is the default).
git clone https://github.com/HoroAlt/thinkserver-rs160-fan-control.git
cd thinkserver-rs160-fan-control

# 3. Install. Probes the BMC, exits with a clear error if NetFn 0x3a
#    isn't accepted (so you find out before rebooting, not after).
sudo ./install.sh

# 4. Try it.
sudo fanctl 10         # all fans to 10%
sudo fanctl status     # show RPM + temps
```

The probe in `install.sh` temporarily sets fans to BMC auto — this is the
documented behavior. On non-Debian systems (`dnf install ipmitool git-core`,
`pacman -S ipmitool git`, …) replace block 1 accordingly; the rest of the
flow assumes a Debian/Ubuntu systemd layout and may need local porting —
see [Compatibility](#compatibility).

### What got installed

| Path | What it is |
|------|-----------|
| `/usr/local/bin/fanctl` | The CLI |
| `/etc/systemd/system/fanctl-boot-apply.service` | Re-applies the last manual mode after reboot |
| `/etc/systemd/system/quiet-night.{service,timer}` | Runs `fanctl set ${NIGHT_PCT}` at 23:00 (after `fanctl night`) |
| `/etc/systemd/system/loud-day.{service,timer}` | Runs `fanctl auto` at 07:00 (after `fanctl night`) |
| `/etc/default/fanctl` | `NIGHT_PCT=10` — change this to set the night-mode fan speed |
| `/var/lib/fanctl/mode` | State file, written atomically on every non-dry-run set/auto; read by boot-restore |

## Commands

| Command | Effect |
|---------|--------|
| `fanctl <1-100>` | All fans to N percent |
| `fanctl set <1-100>` | Same, more explicit |
| `fanctl auto` | Hand control back to the BMC |
| `fanctl max` | All fans to 100 percent |
| `fanctl half` | All fans to 50 percent |
| `fanctl per-channel <p0> ... <p7>` | Per-channel, `0` = auto for that channel, unspecified = 100 |
| `fanctl status` | Show RPM + temperatures as a table |
| `fanctl watch` | Watchdog; polls every `WATCH_INTERVAL` sec, hands to auto at `WATCH_CRIT` °C |
| `fanctl night` / `fanctl day` | Enable / disable the systemd night schedule |
| `fanctl restore` | Re-apply the last manual mode (used by boot-restore) |
| `fanctl -n <cmd>` | Dry-run: print the `ipmitool` command, don't execute |
| `fanctl --version` / `-h` / `help` | Version / help |

All speed values are in percent (`5`, `10`, `25`, `50`, `100`). Internally
that becomes a byte the BMC understands; you never see the hex.

For a full description, run `fanctl --help`.

## Configuration

| Variable | Where read | Default | Effect |
|----------|-----------|---------|--------|
| `NIGHT_PCT` | `/etc/default/fanctl` (sourced by `quiet-night.service` via `EnvironmentFile=`) | `10` | Fan percent the night-mode service sets at 23:00 |
| `WATCH_INTERVAL` | Environment on `fanctl watch` | `10` | Seconds between CPU-temperature polls |
| `WATCH_CRIT` | Environment on `fanctl watch` | `85` | CPU temperature (°C) at which `watch` hands control back to BMC auto |
| `FANCTL_STATE_DIR` | Environment | `/var/lib/fanctl` | Override the state file location (useful for non-root testing) |

### Night mode (default 23:00 → 10%, 07:00 → auto)

```bash
sudo fanctl night               # 10% at night, auto at 7AM
sudo fanctl day                 # disable
```

Survives reboot. Change the night-mode percentage without reinstalling:

```bash
sudo $EDITOR /etc/default/fanctl    # set NIGHT_PCT=15
sudo systemctl restart quiet-night.service
```

Schedule **times** (23:00 / 07:00) live in the `.timer` units and stay
hardcoded; edit those files if you want different times.

### Boot-time restore (modes lost from BMC RAM on reboot)

```bash
sudo systemctl enable --now fanctl-boot-apply.service
```

After enabling, the last manual mode (`fanctl 10`, `fanctl night`, etc.) is
re-applied automatically after every boot. State lives in
`/var/lib/fanctl/mode`; `fanctl day` clears it to `auto`.

### Watchdog (safety net for unattended low-fan use)

```bash
fanctl watch               # poll CPU every 10s, hand to BMC auto at ≥85°C
WATCH_INTERVAL=5 WATCH_CRIT=80 fanctl watch
```

If `watch` itself fails to read the temperature, it also reverts to auto
(rather than stay silent on a stuck sensor).

For a once-per-minute cron-style alternative that hands control back to
the BMC at temperature thresholds instead of polling, see
[`examples/temp-monitor.sh`](examples/temp-monitor.sh) and its
[README](examples/README.md).

## Benchmarks

Real numbers from three live nodes. All three settle at ~3000 RPM at 10%
after `fanctl 10`, with CPU idle around 40–45 °C:

| Node  | BMC  | Before (RPM)   | After  | CPU idle |
|-------|------|---------------|--------|----------|
| PVE-1 | 2.50 | 8300/8400/6500 | ~3100  | ~42 °C   |
| PVE-2 | 3.20 | 7800/7800/5700 | ~3000  | ~41 °C   |
| PVE-3 | 1.36 | 8200/8100/6500 | ~3100  | ~43 °C   |

"Before" is the BMC's default after a cold boot; "after" is 10 percent on
all channels, settled.

## ⚠️ Safety

- **Manual mode does not ramp up under load.** Set 10% as the floor and
  walk away from it.
- For unattended low-fan use, also run `fanctl watch`. Polls CPU temp via
  IPMI every 10s and reverts to BMC auto at ≥85°C. Thresholds overridable
  via `WATCH_INTERVAL`, `WATCH_CRIT`. If `watch` itself fails to read
  temperature, it also reverts to auto.
- Don't run on a hot day with poor ventilation. CPU thermal throttling is
  your friend; fan failure is not.
- **This is OEM undocumented territory — use at your own risk.**

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for `ipmitool` not found,
kernel module issues, `Invalid command` errors, and other common
pitfalls.

## License

MIT — see [LICENSE](LICENSE).

## Acknowledgments

The ASRock Rack OEM NetFn `0x3a` is documented in
[ASRock Rack's ipmitool FAQ](https://www.asrockrack.com/support/faq.asp?k=ipmitool).
Without that page, `fanctl` wouldn't exist.
