# thinkserver-rs160-fan-control

Quiet fans on a Lenovo ThinkServer RS160 via IPMI. Tested on BMC 1.36, 2.50,
3.20 (ASPEED AST2400, ThinkServer TMM firmware).

If your RS160 sounds like a hairdryer at idle and Lenovo's web UI offers no
fan profile, this is for you.

## Prerequisites

```bash
sudo apt install ipmitool      # or yum/dnf equivalent
sudo modprobe ipmi_si ipmi_devintf   # kernel modules (often not auto-loaded)
```

You'll need `sudo` or root — `ipmitool` talks to `/dev/ipmi0` (or to the BMC
over LAN).

## The problem

RS160 fans sit at 7800–8400 RPM even when idle. There is no fan profile option
in the web UI and standard IPMI raw commands all return `Invalid command` from
this BMC.

The fix uses an undocumented ASRock Rack OEM NetFn (`0x3a`) that the ThinkServer
TMM firmware accepts. Lenovo doesn't publish it; ASRock Rack's own
[FAQ](https://www.asrockrack.com/support/faq.asp?k=ipmitool) does.

## Compatibility

This project has been tested on **Proxmox VE + Lenovo ThinkServer RS160**
(BMC firmware 1.36 / 2.50 / 3.20). It works there.

The fan-control mechanism is an undocumented ASRock Rack OEM NetFn (`0x3a`)
that Lenovo's ThinkServer TMM firmware happens to accept. Other BMCs and
distributions are not officially tested — they may work the same way or they
may not, since the protocol isn't published and behavior on different firmware
isn't guaranteed.

- **Proxmox VE + ThinkServer RS160, `install.sh` failing?** See
  [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
- **Different hardware or hypervisor?** Treat this as fix-it-yourself. The
  protocol bytes are visible in `fanctl`, the install steps assume a
  Debian/Ubuntu layout with systemd, and the common BMC-side gotchas are
  listed in [TROUBLESHOOTING.md](TROUBLESHOOTING.md). Patches and PRs that
  add support for other distributions or BMC firmware versions are welcome.
- **Porting to something else?** Start from the ASRock Rack command reference
  at <https://www.asrockrack.com/support/faq.asp?k=ipmitool>.

## Quick check

```bash
sudo ipmitool raw 0x3a 0x01 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a 0x0a
```

Fans should drop to ~3000 RPM. If you see `Invalid command`, your BMC doesn't
accept this NetFn — stop here, this tool won't help.

## One-command setup

```bash
sudo ./install.sh          # probes BMC, copies fanctl + units + config
fanctl 10                  # all fans at 10 percent
fanctl set 25              # same, more explicit
fanctl per-channel 10 30 10   # FAN1=10 FAN2=30 FAN3=10, rest 100
fanctl max                 # 100 percent
fanctl half                # 50 percent
fanctl auto                # back to BMC
fanctl status              # show RPM + temps as a table
fanctl -n 10               # dry-run: show what would be sent, don't send
```

All speed values are in **percent** (`5`, `10`, `25`, `50`, `100`). Internally
that becomes a byte the BMC understands; you never see the hex.

`install.sh` verifies the BMC accepts NetFn `0x3a` before installing — exits
with a clear error if not, so you know up front instead of after rebooting.
The probe temporarily sets fans to BMC auto; this is the documented behavior
(see comments in `install.sh`).

### Night mode (default 23:00 → 10%, 07:00 → auto)

```bash
fanctl night               # 10 percent at night, auto at 7AM
fanctl day                 # disable
```

Survives reboot. Uses systemd timers, no cron. Change the night-mode percentage
without reinstalling:

```bash
sudo $EDITOR /etc/default/fanctl    # set NIGHT_PCT=15
sudo systemctl restart quiet-night.service
```

The schedule **times** (23:00 / 07:00) live in the `.timer` units and stay
hardcoded; edit those files if you want different times.

### Boot-time restore (modes lost from BMC RAM on reboot)

```bash
sudo systemctl enable --now fanctl-boot-apply.service
```

After enabling, the last manual mode (`fanctl 10`, `fanctl night`, etc.) is
re-applied automatically after every boot. State lives in
`/var/lib/fanctl/mode`. `fanctl day` clears it.

### Watchdog (safety net for unattended low-fan use)

```bash
fanctl watch               # poll CPU every 10s, hand to BMC auto at ≥85°C
WATCH_INTERVAL=5 WATCH_CRIT=80 fanctl watch
```

If `watch` itself fails to read the temperature, it also reverts to auto.

## ⚠️ Safety

- Manual mode **does not ramp up under load**. Set 10% as the floor, walk
  away from it.
- For unattended low-fan use, run `fanctl watch` alongside. Polls CPU temp via
  IPMI every 10s and reverts to BMC auto at ≥85°C. Thresholds overridable via
  `WATCH_INTERVAL`, `WATCH_CRIT`. If `watch` itself fails to read temperature,
  it also reverts to auto.
- Don't run on a hot day with poor ventilation. CPU thermal throttling is your
  friend; fan failure is not.
- This is OEM undocumented territory — use at your own risk.

## Having issues?

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for `ipmitool` not found,
kernel module issues, `Invalid command` errors, and other common pitfalls.

## Going further

| File | What it does | When to use |
|------|-------------|-------------|
| [`examples/temp-monitor.sh`](examples/temp-monitor.sh) | Auto-adjusts fans by CPU temp, with hysteresis | Cron / standalone, no install needed |
| `fanctl per-channel <p0> ... <p7>` | Different speeds per fan | Installed path |
| `fanctl -n <cmd>` | Show what `ipmitool` would be invoked with | Testing config before committing |

`temp-monitor.sh` ramps `10 → 20 → 40 → auto` at 45/55/65°C and includes
hysteresis (5°C) to avoid oscillating at thresholds. State file:
`/var/lib/fanctl/temp-monitor-mode`. Run from cron every minute:

```bash
* * * * * /usr/local/bin/temp-monitor.sh
```

See [`examples/README.md`](examples/README.md) for cron/loop setup.

## Effects at 10%

All fans settle at ~3000–3100 RPM. CPU idle 40–45°C.

| Node  | BMC  | Before          | After   |
|-------|------|-----------------|---------|
| PVE-1 | 2.50 | 8300/8400/6500  | ~3100   |
| PVE-2 | 3.20 | 7800/7800/5700  | ~3000   |
| PVE-3 | 1.36 | 8200/8100/6500  | ~3100   |

## License

[MIT](LICENSE) — do what you want, just keep the copyright notice.
