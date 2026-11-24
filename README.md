# OmaT6

Use an **MCT Trigger 6** USB display adapter or dock (sold as "T6 USB Station", and inside many j5create and StarTech USB-to-HDMI/DP adapters) as an extra monitor on [Omarchy](https://omarchy.org/) (Arch Linux + Hyprland).

> Independent community project, not affiliated with MCT, Omarchy or Hyprland. Tested on one machine (see below).

## Why this exists

These adapters send video over USB, like DisplayLink docks, but use a different chip from a different company. [OmaDisplayLink](https://github.com/bmaltais/OmaDisplayLink) and the `displaylink` driver **only work with DisplayLink (Synaptics) chips**. Plug a T6 in and nothing happens.

MCT publishes its own open-source (GPL-2.0) driver, [`triggerdm`](https://github.com/mcttrigger/triggerdm), written for ChromeOS. It runs as a normal program and needs **EVDI** (the virtual display kernel module) to create the screen. Once EVDI is installed, it builds and runs on Arch as is. This repo puts the pieces together:

1. installs `evdi-dkms` from the AUR (skipped if already there, for example from OmaDisplayLink)
2. builds `triggerdm` from MCT's repo (git submodule)
3. installs it as a systemd service that starts at boot and restarts if it crashes

`triggerdm` notices plugging and unplugging by itself, so no udev rule is needed.

## Is my device a Trigger 6?

```
lsusb | grep 0711:5
```

Something like `ID 0711:5601 Magic Control Technology Corp. T6 USB Station` means yes. The driver accepts `0711:56xx` and `0711:57xx`.

## Install

```
git clone --recursive https://github.com/<you>/OmaT6.git
cd OmaT6
./install.sh --preview   # shows what it will do
./install.sh             # asks for your password where needed
```

The screen appears in `hyprctl monitors` as `DVI-I-1` (or similar) and you can place it in `monitors.lua` like any other monitor.

## Uninstall

```
./uninstall.sh
```

Removes the service and the binary. It leaves `evdi-dkms` installed, since other tools may use it.

## Limits

- **4K runs at 30 Hz at most.** That's the chip's limit (`triggerdm` has 3840x2160@30 built in). 1080p runs at 60 Hz.
- The picture is compressed and sent over USB, so fast motion uses more CPU than a native port. Use a USB 3 port.
- The kernel log fills with harmless `evdi ... Update was already requested - ignoring` warnings.
- After a kernel update DKMS rebuilds EVDI automatically. If the screen stays black, run `sudo dkms autoinstall` and restart the service: `sudo systemctl restart triggerdm`.

## Tested hardware

| | |
|---|---|
| Adapter | MCT T6 USB Station (`0711:5601`), on USB 3 (5 Gbps) |
| Monitor | 1920x1080 at 60 Hz over HDMI |
| GPU | Intel integrated |
| Software | Omarchy, Hyprland 0.56, kernel 7.2, evdi 1.15.1, triggerdm `a9328ca` |

Got it running on something else? Open an issue with your `lsusb` line, GPU and whether it worked.

## Credits

- [MCT / mcttrigger](https://github.com/mcttrigger/triggerdm) for the driver (GPL-2.0)
- [DisplayLink/evdi](https://github.com/DisplayLink/evdi)
- [cyrozap/mct-usb-display-adapter-re](https://github.com/cyrozap/mct-usb-display-adapter-re) for the protocol research
- [bmaltais/OmaDisplayLink](https://github.com/bmaltais/OmaDisplayLink), which inspired this

## License

MIT for the scripts in this repo. `triggerdm` is GPL-2.0 under its own license (submodule, not copied here).
