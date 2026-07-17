# Troubleshooting

If `fanctl` isn't working, walk through these in order. Each entry has the
error message you'll see and what to do about it.

## `ipmitool: command not found`

`ipmitool` isn't installed.

```bash
# Debian / Ubuntu
sudo apt install ipmitool

# RHEL / Fedora / Rocky
sudo dnf install ipmitool

# Arch
sudo pacman -S ipmitool
```

## `Could not open device at /dev/ipmi0` or `Get Device ID command failed`

Kernel modules for IPMI aren't loaded. This is common on fresh installs.

```bash
sudo modprobe ipmi_si ipmi_devintf
```

Make it persistent across reboots:

```bash
echo -e "ipmi_si\nipmi_devintf" | sudo tee /etc/modules-load.d/ipmi.conf
```

Verify the device appeared:

```bash
ls -l /dev/ipmi0
```

## `Invalid command` on `ipmitool raw 0x3a 0x01 ...`

Your BMC firmware doesn't accept the ASRock Rack OEM NetFn `0x3a`. This tool
targets ASPEED AST2400 running ThinkServer TMM firmware specifically. If
your board is different, or your BMC firmware is from a vendor build that
stripped this NetFn, the command won't work and there's no software fix —
only a BMC firmware change.

`./install.sh` checks for this and exits with a clear message instead of
silently installing a tool that won't work.

## `install: cannot talk to BMC`

`install.sh` couldn't reach the BMC. Most common causes:

- `ipmi_si` kernel module not loaded
- IPMI disabled in BIOS (`Server Mgmt → BMC Settings`)
- Need LAN access instead of `/dev/ipmi0`: `sudo ipmitool -I lanplus -H <ip> sdr list`
- BMC requires auth: see `man ipmitool` for `-A` / `-U` / `-P`

## `fanctl night` says `systemd units not found — run install.sh first`

You ran `fanctl night` before `install.sh`. Either:

- Run `./install.sh` once from the cloned repo directory, or
- Run `fanctl night` from the cloned repo directory directly (it auto-detects
  `systemd/` relative to itself).

## `fanctl status` shows no fans or temps

`status` uses `ipmitool sdr` which needs working IPMI access. If `fanctl 10`
works but `status` doesn't, the IPMI driver may be flaky. Try the raw command:

```bash
sudo ipmitool sdr list
```

If that errors with permission issues, your user doesn't have access to
`/dev/ipmi0`. Either run as root, or add yourself to a group with access:

```bash
sudo groupadd ipmi 2>/dev/null
sudo usermod -aG ipmi $USER
sudo chmod g+rw /dev/ipmi0
```

(Log out and back in for the group change to take effect.)

## Fans went back to 100% after a reboot

Expected behavior. Manual mode lives in BMC RAM. After a power cycle, BMC
firmware update, or `mc reset cold`, the BMC falls back to its default
**auto** mode. Two ways to restore:

1. **One-off:** re-run `fanctl 10` (or `fanctl night` for the timed schedule).
2. **Automatic:** enable the boot unit and it restores the last manual mode
   after every boot:

   ```bash
   sudo systemctl enable --now fanctl-boot-apply.service
   ```

   State file: `/var/lib/fanctl/mode`. `fanctl auto` and `fanctl day` reset
   it to `auto`.

## Fan RPM didn't change after `fanctl 10`

- The BMC accepts the command but the chassis fan controller ignores it:
  check `fanctl status` for current RPM after a few seconds.
- BMC version outside tested set (1.36, 2.50, 3.20). Check `mc info`.
- `ipmitool raw` exits 0 even when BMC rejects the payload (e.g. value out of
  range). `fanctl` enforces 1..100 for manual mode; auto (`fanctl auto`)
  accepts any value.

## `fanctl watch` exits with "temp read failed"

`watch` couldn't read CPU temperature from IPMI sensors. It hands control back
to BMC auto and exits 1 as a safety measure (better to land on auto than stay
on 10% with no thermometer). Investigate `sudo ipmitool sdr type temperature`.
