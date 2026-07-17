# Examples

You don't have to use `fanctl`. Here are alternative approaches — pick whatever fits your setup.

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

## per-channel.sh

Different speeds per fan — let FAN2 run faster if it's near CPU, while keeping FAN1 and FAN3 slow.

```bash
./per-channel.sh  10 30 10
# FAN1=10%  FAN2=30%  FAN3=10%
```