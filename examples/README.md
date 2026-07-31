# Examples

You don't have to use `fanctl` for these — copy a script and run it directly.
Pick whatever fits your setup.

## When to use `fanctl` vs these scripts

| If you have… | Reach for… | Reason |
|--------------|-----------|--------|
| `fanctl` installed (`./install.sh`) | `fanctl <command>` | One source of truth, atomic state, `--dry-run`, `--version`, per-channel |
| Just the cloned repo, no install | The script under `examples/` | Standalone, no install required, no systemd |

The standalone scripts intentionally don't depend on `fanctl` being on PATH —
so you can `cp temp-monitor.sh /usr/local/bin/` and forget about the project.
If you do have `fanctl`, prefer it: the protocol bytes live in one place there.

## temp-monitor.sh

Bash script that reads CPU temperature and adjusts fans accordingly:

- `<45°C` → 10%
- `45–55°C` → 20%
- `55–65°C` → 40%
- `>65°C` → auto (hands control back to BMC)

**Cron (simplest no-dependency setup):**

```bash
sudo cp temp-monitor.sh /usr/local/bin/
chmod +x /usr/local/bin/temp-monitor.sh
crontab -e
# add this line:
* * * * * /usr/local/bin/temp-monitor.sh
```

**Loop mode (no cron, runs forever):**

```bash
nohup bash -c 'while true; do temp-monitor.sh; sleep 30; done' &
```

If you have `fanctl` installed and want the same behavior under cron, you can
shell out to it instead — but the script covers what you need either way.

## See also

The same per-channel control is built into `fanctl` once installed:

```bash
fanctl per-channel 10 30 10      # FAN1=10%  FAN2=30%  FAN3=10%, rest 100
fanctl per-channel 5 0 5 0 0 0 0 0   # 0 = auto for that channel
```

If you only need temp-driven control, `temp-monitor.sh` above is the
self-contained option. Use `fanctl -n <cmd>` to preview ipmitool calls
without touching BMC.
