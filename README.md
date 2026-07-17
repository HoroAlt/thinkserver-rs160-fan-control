# thinkserver-rs160-fan-control

Control fan speed on Lenovo ThinkServer RS160 via IPMI. Tested on BMC 1.36, 2.50, 3.20 (ASPEED AST2400).

## Prerequisites

```bash
sudo apt install ipmitool      # or yum/dnf equivalent
sudo modprobe ipmi_si ipmi_devintf   # kernel modules (often not auto-loaded)
```

You'll need `sudo` or root — `ipmitool` talks to `/dev/ipmi0` (or to BMC over LAN).

## The problem

RS160 fans sit at 7800–8400 RPM even when idle. No fan profile in web UI, and standard IPMI raw commands all return `Invalid command`.

The fix uses an undocumented ASRock Rack OEM NetFn (`0x3a`) that the ThinkServer TMM firmware accepts. Lenovo doesn't publish it; ASRock Rack's own [FAQ](https://www.asrockrack.com/support/faq.asp?k=ipmitool) does.

## Quick check

```bash
sudo ipmitool raw 0x3a 0x01 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a
```

Fans should drop to ~3000 RPM. If you see `Invalid command`, your BMC doesn't accept this NetFn — stop here, this tool won't help.

## One-command setup

```bash
sudo ./install.sh          # copies fanctl + systemd units to /usr/local
fanctl 10                  # set 10%
fanctl max                 # set 100%
fanctl half                # set 50%
fanctl auto                # back to BMC
fanctl status              # show RPM + temps
```

### Night mode (23:00 → 10%, 07:00 → auto)

```bash
fanctl night               # 10% at night, auto at 7AM
fanctl day                 # disable
```

Survives reboot. No cron.

## ⚠️ Safety

- Manual mode **does not ramp up under load**. Set 10% as the floor, walk away from it.
- For unattended low-fan use, run `fanctl watch` alongside. It polls CPU temp via IPMI every 10s and reverts to BMC auto at ≥85°C. Thresholds overridable via `WATCH_INTERVAL`, `WATCH_CRIT` env vars. (If the BMC reboots while in manual mode, settings are lost from RAM and the BMC returns to auto automatically.)
- Don't run on a hot day with poor ventilation. CPU thermal throttling is your friend; fan failure is not.
- This is OEM undocumented territory — use at your own risk.

## Having issues?

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for `ipmitool` not found, kernel module issues, `Invalid command` errors, and other common pitfalls.

## Going further

| File | What it does |
|------|-------------|
| [`examples/temp-monitor.sh`](examples/temp-monitor.sh) | Auto-adjusts fans by CPU temp |
| [`examples/per-channel.sh`](examples/per-channel.sh) | Different speeds per fan |

See [`examples/README.md`](examples/README.md) for cron/loop setup.

## Effects at 10%

All fans settle at ~3000–3100 RPM. CPU idle 40–45°C.

| Node | BMC  | Before     | After    |
|------|------|------------|----------|
| PVE-1 | 2.50 | 8300/8400/6500 | ~3100 |
| PVE-2 | 3.20 | 7800/7800/5700 | ~3000 |
| PVE-3 | 1.36 | 8200/8100/6500 | ~3100 |

## License

[MIT](LICENSE) — do what you want, just keep the copyright notice.