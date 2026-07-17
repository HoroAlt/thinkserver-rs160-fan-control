# thinkserver-rs160-fan-control

Control fan speed on Lenovo ThinkServer RS160 (and possibly RS260/TS460/TS560) via IPMI.

Works on BMC 1.36, 2.50, 3.20 — all on ASPEED AST2400.

## The problem

RS160 fans sit at 7800–8400 RPM even when idle. No fan profile in web UI, and standard IPMI raw commands all return `Invalid command`.

## The fix

```bash
# 10% → fans drop to ~3000 RPM
ipmitool raw 0x3a 0x01 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a

# restore automatic control
ipmitool raw 0x3a 0x01 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00
```

Last 8 bytes = PWM duty per channel (`0x00` = 0%, `0x64` = 100%). Same value for all channels.

ASRock Rack OEM command, works on ThinkServer TMM. Lenovo doesn't document it.

## Quick start

```bash
sudo apt install ipmitool
sudo ipmitool raw 0x3a 0x01 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a
```

Fans drop to ~3000 RPM, CPU idle stays at 40–45°C.

To go back to auto:
```bash
sudo ipmitool raw 0x3a 0x01 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00
```

## One-command setup

```bash
sudo ./install.sh          # copies fanctl + systemd units to /usr/local
fanctl 10                  # set 10%
fanctl max                 # set 100%
fanctl half                # set 50%
fanctl auto                # back to BMC
fanctl status              # show RPM + temps
```

### Night mode (23:00–07:00)

```bash
fanctl night               # 10% at night, auto at 7AM
fanctl day                 # disable
```

Survives reboot. No cron.

## Going further

See [`examples/`](examples/):

| File | What it does |
|------|-------------|
| [`temp-monitor.sh`](examples/temp-monitor.sh) | Adjusts fans by CPU temp |
| [`per-channel.sh`](examples/per-channel.sh) | Different speeds per fan |
| [`examples/README.md`](examples/README.md) | Cron, loop, systemd |

```bash
ipmitool raw 0x3a 0x01 <ch0> <ch1> <ch2> <ch3> <ch4> <ch5> <ch6> <ch7>
```

Each byte = PWM duty: `0x00`=0%, `0x64`=100%, `0x0a`=10%. All zeroes = back to BMC.

## Effects at 10%

All fans settle at ~3000–3100 RPM. CPU idle 40–45°C.

| Node | BMC  | Before     | After    |
|------|------|------------|----------|
| PVE-1 | 2.50 | 8300/8400/6500 | ~3100 |
| PVE-2 | 3.20 | 7800/7800/5700 | ~3000 |
| PVE-3 | 1.36 | 8200/8100/6500 | ~3100 |

## Disclaimer

- Manual mode **does not ramp up under load**. Don't set below 10% and walk away.
- Resets on BMC reboot (power cycle, firmware update, `mc reset cold`).
- OEM command, undocumented. Your call.
