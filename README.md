# thinkserver-rs160-fan-control

[![CI](https://github.com/HoroAlt/thinkserver-rs160-fan-control/actions/workflows/ci.yml/badge.svg)](https://github.com/HoroAlt/thinkserver-rs160-fan-control/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![BMC verified](https://img.shields.io/badge/BMC-1.36%7C2.50%7C3.20-informational.svg)](#compatibility)

> Quiet fans on a Lenovo ThinkServer RS160 via IPMI. Tested on Proxmox VE;
> BMC firmware 1.36 / 2.50 / 3.20. See [Compatibility](#compatibility) for what
> this means on other hardware.

If your RS160 sounds like a hairdryer at idle and Lenovo's web UI offers
no fan profile, this is for you.

## Contents

- [Install](#install)
- [Why this exists](#why-this-exists)
- [What it does](#what-it-does)
- [Compatibility](#compatibility)
- [Quick check](#quick-check)
- [What got installed](#what-got-installed)
- [Commands](#commands)
- [Configuration](#configuration)
- [Benchmarks](#benchmarks)
- [Safety](#safety)
- [Troubleshooting](#troubleshooting)
- [License](#license)
- [Acknowledgments](#acknowledgments)

## Install

Proxmox VE / Debian / Ubuntu — get to a root shell (or use `sudo` per line)
and run:

```bash
sudo apt update
sudo apt install -y ipmitool git
sudo modprobe ipmi_si ipmi_devintf
echo -e "ipmi_si\nipmi_devintf" | sudo tee /etc/modules-load.d/ipmi.conf
git clone https://github.com/HoroAlt/thinkserver-rs160-fan-control.git
cd thinkserver-rs160-fan-control
sudo ./install.sh
sudo fanctl 10
```

That's the whole path. Explanations of each line, what landed on disk,
and alternatives for non-Debian systems are below.

`install.sh` probes the BMC first and exits with a clear error if your
firmware doesn't accept NetFn `0x3a`. The probe resets fans to BMC auto
momentarily — that's the documented behavior, not a bug. No reboot needed
for the install itself.

## Why this exists

RS160 fans sit at 7800–8400 RPM at idle. There's no fan profile in the
web UI, and standard IPMI raw commands all return `Invalid command` from
this BMC. The fix uses an undocumented ASRock Rack OEM NetFn (`0x3a`)
that Lenovo's ThinkServer TMM firmware accepts. Lenovo doesn't publish it;
ASRock Rack's own [FAQ](https://www.asrockrack.com/support/faq.asp?k=ipmitool)
does.

## What it does

- **`fanctl <1-100>`** — set every fan to N percent. No hex, no PWM curves.
- **`fanctl per-channel <p0> ... <p7>`** — different speeds per channel,
  or `0` to hand one channel back to the BMC.
- **`fanctl -n` / `--dry-run`** — preview the `ipmitool` call without
  sending.
- **`fanctl set <N>`, `max`, `half`, `auto`** — the four commands you'll
  reach for in practice.
- **`fanctl status`** — RPM and temperatures as a table.
- **Boot-restore** (`fanctl-boot-apply.service`) — your last manual mode
  survives a reboot. State lives in `/var/lib/fanctl/mode`, written
  atomically.
- **Night schedule** via systemd timers (`fanctl night` / `fanctl day`).
  Night-mode percent comes from `/etc/default/fanctl`, no reinstalling.
- **Watchdog** (`fanctl watch`) — polls CPU temp via IPMI, hands control
  back to BMC auto at a configurable threshold. Defaults: 10s, 85 °C.

## Compatibility

Tested on **Proxmox VE + Lenovo ThinkServer RS160** (BMC firmware 1.36 /
2.50 / 3.20). It works there.

The fan-control mechanism is a firmware-specific OEM NetFn (`0x3a`) that
ThinkServer TMM happens to accept. Behavior on other BMCs and distributions
isn't guaranteed, since the protocol isn't published by Lenovo.

- **Proxmox VE + ThinkServer RS160, `install.sh` failing?** See
  [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
- **Different hardware or hypervisor?** Fix-it-yourself project. The
  protocol bytes are visible in `fanctl`, common gotchas are listed in
  [TROUBLESHOOTING.md](TROUBLESHOOTING.md). Patches welcome.
- **Porting to something else?** Start from the ASRock Rack command
  reference at <https://www.asrockrack.com/support/faq.asp?k=ipmitool>.

## Quick check

Run this once — before installing, or any time later to confirm the BMC
still accepts the protocol:

```bash
sudo ipmitool raw 0x3a 0x01 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a
```

Fans should drop to ~3000 RPM. If you see `Invalid command`, your BMC
firmware doesn't accept this NetFn — `fanctl` won't help.

## What got installed

On disk after `install.sh`:

- `/usr/local/bin/fanctl` — the CLI.
- `/etc/systemd/system/fanctl-boot-apply.service` — boot-restore; enable
  with `sudo systemctl enable --now fanctl-boot-apply.service`.
- `/etc/systemd/system/quiet-night.{service,timer}` — runs
  `fanctl set ${NIGHT_PCT}` at 23:00. Active once you run `sudo fanctl night`.
- `/etc/systemd/system/loud-day.{service,timer}` — runs `fanctl auto` at
  07:00. Active once you run `sudo fanctl night`.
- `/etc/default/fanctl` — single key, `NIGHT_PCT=10`. Edit and run
  `sudo systemctl restart quiet-night.service` to change.
- `/var/lib/fanctl/mode` — boot-restore state. Written atomically on every
  non-dry-run `set` / `auto`; read once at boot.

On non-Debian systems the layout assumption breaks down — see
[Compatibility](#compatibility).

## Commands

| Command | Effect |
|---------|--------|
| `fanctl <1-100>` | All fans to N percent |
| `fanctl set <1-100>` | Same, more explicit |
| `fanctl auto` | Hand control back to the BMC |
| `fanctl max` | All fans to 100 percent |
| `fanctl half` | All fans to 50 percent |
| `fanctl per-channel <p0> ... <p7>` | Per-channel, `0` = auto for that channel, unspecified = 100 |
| `fanctl status` | Show RPM and temperatures as a table |
| `fanctl watch` | Watchdog; polls every `WATCH_INTERVAL` sec, hands to auto at `WATCH_CRIT` °C |
| `fanctl night` / `fanctl day` | Enable / disable the systemd night schedule |
| `fanctl restore` | Re-apply the last manual mode (used by boot-restore) |
| `fanctl -n <cmd>` | Dry-run: print the `ipmitool` command, don't execute |
| `fanctl --version` / `-h` / `help` | Version / help |

All speed values are in percent. Internally that becomes a byte the BMC
understands; you never see the hex.

For a full description, run `fanctl --help`.

## Configuration

| Variable | Where | Default | Effect |
|----------|-------|---------|--------|
| `NIGHT_PCT` | `/etc/default/fanctl` (sourced by `quiet-night.service` via `EnvironmentFile=`) | `10` | Fan percent set at 23:00 |
| `WATCH_INTERVAL` | Environment on `fanctl watch` | `10` | Seconds between CPU-temperature polls |
| `WATCH_CRIT` | Environment on `fanctl watch` | `85` | °C at which `watch` hands control back to BMC auto |
| `FANCTL_STATE_DIR` | Environment | `/var/lib/fanctl` | Override the state file location (useful for non-root testing) |

### Night mode (default 23:00 → 10%, 07:00 → auto)

```bash
sudo fanctl night               # 10% at night, auto at 7AM
sudo fanctl day                 # disable
```

Change the night-mode percent without reinstalling:

```bash
sudo $EDITOR /etc/default/fanctl       # set NIGHT_PCT=15
sudo systemctl restart quiet-night.service
```

Schedule **times** (23:00 / 07:00) live in the `.timer` units and stay
hardcoded; edit those files if you want different times.

### Boot-time restore (modes lost from BMC RAM on reboot)

```bash
sudo systemctl enable --now fanctl-boot-apply.service
```

After enabling, the last manual mode is re-applied automatically after every
boot. State lives in `/var/lib/fanctl/mode`; `fanctl day` clears it.

### Watchdog (safety net for unattended low-fan use)

```bash
fanctl watch               # poll CPU every 10s, hand to BMC auto at ≥85 °C
WATCH_INTERVAL=5 WATCH_CRIT=80 fanctl watch
```

If `watch` itself fails to read the temperature, it also reverts to auto.

For a once-per-minute cron-style alternative that hands control back at
temperature thresholds instead of polling, see
[`examples/temp-monitor.sh`](examples/temp-monitor.sh).

## Benchmarks

Real numbers from three live nodes. All settle at ~3000 RPM at 10%:

| Node  | BMC  | Before (RPM)   | After  | CPU idle |
|-------|------|---------------|--------|----------|
| PVE-1 | 2.50 | 8300/8400/6500 | ~3100  | ~42 °C   |
| PVE-2 | 3.20 | 7800/7800/5700 | ~3000  | ~41 °C   |
| PVE-3 | 1.36 | 8200/8100/6500 | ~3100  | ~43 °C   |

"Before" is the BMC's default after a cold boot; "after" is 10% on all
channels, settled.

## Safety

- **Manual mode does not ramp up under load.** Set 10% as the floor and
  walk away from it.
- For unattended low-fan use, also run `fanctl watch`. Polls CPU temp via
  IPMI every 10 s and reverts to BMC auto at ≥85 °C. Thresholds overridable
  via `WATCH_INTERVAL`, `WATCH_CRIT`. If `watch` itself fails to read
  temperature, it also reverts to auto.
- Don't run on a hot day with poor ventilation. CPU thermal throttling is
  your friend; fan failure is not.
- **This is OEM undocumented territory — use at your own risk.**

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for `ipmitool` not found,
kernel module issues, `Invalid command` errors, and other common pitfalls.

## License

MIT — see [LICENSE](LICENSE).

## Acknowledgments

The ASRock Rack OEM NetFn `0x3a` is documented in
[ASRock Rack's ipmitool FAQ](https://www.asrockrack.com/support/faq.asp?k=ipmitool).
Without that page, `fanctl` wouldn't exist.
