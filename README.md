# thinkserver-rs160-fan-control

Control fan speed on **Lenovo ThinkServer RS160** (and potentially RS260/TS460/TS560) via IPMI.

Works on BMC versions 1.36, 2.50, and 3.20 — all share the same ASPEED AST2400 chip.

## The problem

RS160 fans run at **7800–8400 RPM** by default even when the server is idle. The BMC has no user-adjustable fan profile in the web UI, and all standard IPMI raw commands (`0x30 0x30 0x01 0x00`, etc.) return `Invalid command`.

## The fix

```bash
# 10% duty cycle — drops fans to ~3000 RPM
ipmitool raw 0x3a 0x01 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a

# restore automatic control
ipmitool raw 0x3a 0x01 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00
```

The last 8 bytes are PWM duty per fan channel (`0x00` = 0%, `0x64` = 100%). Send the same value for all channels.

This is an ASRock Rack OEM command that happens to work on ThinkServer TMM — undocumented by Lenovo.

## Quick start (5 seconds)

```bash
sudo apt install ipmitool
sudo ipmitool raw 0x3a 0x01 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a
```

That's it. Fans drop from 8000→~3000 RPM. CPU stays at 40–45°C idle.

To restore automatic control:
```bash
sudo ipmitool raw 0x3a 0x01 0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00
```

Go ahead, copy-paste it. The rest of this README is details for when you want to automate or fine-tune.

## For beginners — one-command setup

The `fanctl` script wraps the raw command into something you can remember:

```bash
sudo ./install.sh          # copies fanctl to /usr/local/bin
fanctl 10                  # quiet mode
fanctl auto                # back to BMC control
fanctl status              # show RPM + temps
```

### Night mode (23:00 → 07:00)

```bash
fanctl night               # fans at 10% at night, auto at 7AM
```

No cron, no config. Comes back after reboot. Disable with:
```bash
fanctl day
```

## Going further

Check the [`examples/`](examples/) directory:

| File | What it does |
|------|-------------|
| [`temp-monitor.sh`](examples/temp-monitor.sh) | Adjusts fans based on CPU temp (PID-light) |
| [`per-channel.sh`](examples/per-channel.sh) | Different speeds per fan channel |
| [`examples/README.md`](examples/README.md) | Cron, loop, systemd, DIY |

The command itself is dead simple:

```bash
ipmitool raw 0x3a 0x01 <ch0> <ch1> <ch2> <ch3> <ch4> <ch5> <ch6> <ch7>
```

Each byte is PWM duty: `0x00`=0%, `0x64`=100%, `0x0a`=10%. Send all zeroes to give control back to the BMC.

## Effects at 10%

All fans settle at **~3000–3100 RPM** across all BMC versions. CPU idle temp stays at 40–45°C.

| Node | BMC  | Before     | After    |
|------|------|------------|----------|
| PVE-1 | 2.50 | 8300/8400/6500 | ~3100 |
| PVE-2 | 3.20 | 7800/7800/5700 | ~3000 |
| PVE-3 | 1.36 | 8200/8100/6500 | ~3100 |

## ⚠️ Disclaimer

- Manual mode **won't ramp up under load** — don't set below 10% and forget.
- Settings **reset on BMC reboot** (power cycle, firmware update, `mc reset cold`).
- The command is **OEM, undocumented, use at your own risk**.

## Credits

Discovered by poking around — not documented anywhere for ThinkServer. Based on the [ASRock Rack AST2400 FAQ](https://www.asrockrack.com/support/faq.de.asp?id=38).
