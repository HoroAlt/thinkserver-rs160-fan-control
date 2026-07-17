# Troubleshooting

If `fanctl` isn't working, walk through these in order. Each entry has the error
message you'll see and what to do about it.

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
**auto** mode. Just re-run `fanctl 10` (or `fanctl night` for the timed
schedule).

## Fan RPM didn't change after `fanctl 10`

- The BMC accepts the command but the chassis fan controller ignores it: check `fanctl status` for current RPM.
- BMC version outside tested set (1.36, 2.50, 3.20). Try `mc info` to see yours.