# Hardware

Ryzen 7 9800X3D, RTX 5090, ASUS ROG Strix X870-I, DDR5-6000, Crucial T700 NVMe.
Two monitors: a Samsung C32JG5x (DP-1, landscape, primary, left) and a Lenovo
T27h-2L (HDMI-A-1, portrait, right). Those port names are what `configuration.nix`,
`config/hypr/hyprland.lua` and `config/waybar/config.jsonc` refer to. The portrait
screen is positioned so its bottom edge is flush with the bottom of the landscape
one, which leaves its top sticking up above the main screen.

## BIOS (ASUS X870-I)

- Enable EXPO for the DDR5-6000 kit.
- Disable Secure Boot (or set up lanzaboote later).
- Enable Resizable BAR (Above 4G Decoding + ReBAR).
- Plug both monitors into the RTX 5090, not the motherboard. The 9800X3D has a small
  integrated GPU; set the primary display to PCIe (or disable the iGPU) so the boot
  splash and login appear on the 5090's screens.
- Leave ErP Ready **disabled** (Advanced → APM Configuration → ErP Ready). Enabling
  it cuts the USB standby rail at shutdown, which is a useful one-off tool for
  clearing a wedged Bluetooth controller but kills the HIVE II power button — see
  "When the BT function wedges" below.

## Headset lighting (Solaar)

The G733's RGB is the only lighting managed from here, and only to keep it switched
off: the lights cost battery, and the headset is on your head where you cannot see
them anyway. `hardware.logitech.wireless` in `configuration.nix` installs Solaar and
the udev rules it needs — `logitech-udev-rules` tags every `046d` hidraw with
`uaccess`, without which the receiver's node is root-only and Solaar shows no LED
controls at all — and a user service in `home.nix` keeps it running.

Turning the lights off is a one-time step; Solaar then remembers it per device serial:

```sh
solaar config "G733 Gaming Headset"                       # list settings + current values
solaar config "G733 Gaming Headset" led_control true      # hand the zones to Solaar
solaar config "G733 Gaming Headset" led_zone_65281 '{ID: 0}'
solaar config "G733 Gaming Headset" led_zone_65282 '{ID: 0}'
```

The headset has to be powered **on** when you run these: the LED features live on the
headset, not the receiver, so with it off Solaar cannot even see them. `led_control`
has to go first — the zone settings do nothing while the firmware still owns the LEDs.
`65281`/`65282` are zones `0xFF01`/`0xFF02` (the logo and the primary ring), and
effect `ID: 0` is `Disabled`. Other effect IDs, if you ever want them: `1` Static,
`2` Pulse, `3` Cycle, `4` Wave, `0x0A` Breathe — Static and Breathe take a `color`,
e.g. `'{ID: 1, color: 0xcba6f7}'`.

These land in `~/.config/solaar/config.yaml`, keyed by device serial — state outside
the repo, but re-derivable: the commands above *are* the recovery procedure, so there
is nothing here worth backing up.

### Why the daemon has to keep running

The headset stores nothing. It forgets any LED setting when it powers off, and it
powers itself off after 30 idle minutes (`adc_power_management = 30`). Meanwhile the
Lightspeed receiver stays enumerated throughout, so there is no `ACTION=="add"` udev
event to reapply on. Solaar's answer is to listen for HID++ device-connection
notifications and reapply its saved settings when the headset wakes — which is why it
runs as a session service instead of being invoked once at boot.

### The motherboard and GPU are left alone

OpenRGB was enabled here briefly as a way to reach the headset, then removed once
Solaar turned out to be the tool for that. It did work: it found the X870-I's Aura
controller over `i2c-piix4`, the 5090's ENE controller on the Nvidia i2c adapter, and
the headset over HID. But it could not *keep* the headset dark, and nothing else on
this machine needs it — the board shows no visible lighting, and the card's own
default is fine.

If that changes, `services.hardware.openrgb.enable = true` is the entire setup: the
module loads the right SMBus driver by following `hardware.cpu.amd.updateMicrocode`.
Its profiles are binary `.orp` files under `~/.config/OpenRGB` though, i.e. state
outside the repo, so prefer a one-shot `openrgb --device ... --color ...` call from
Nix over a profile clicked together in the GUI.

## Onboard Wi-Fi/BT (MediaTek MT7927)

The board's Wi-Fi 7 + Bluetooth 5.4 is the onboard MediaTek MT7927 combo chip
(PCIe `14c3:7927`; the BT side is the MT6639 controller, USB `0489:e13a`). It
needs kernel >= 7.2 (BT support merged in 7.1, Wi-Fi in 7.2), so
`configuration.nix` pins `boot.kernelPackages` to the 7.2 series from a
rev-pinned `nixpkgs-unstable` flake input — everything else stays on the
stable channel. When the repo moves to 26.11 (default kernel >= 7.2), delete
the pin and the input.

Firmware: the Wi-Fi blobs come from linux-firmware (`hardware.enableRedistributableFirmware`);
the BT blob is not in upstream linux-firmware yet and is extracted from the
pinned ASUS vendor driver zip (`pkgs/mt7927bt-firmware.nix`, wired via
`hardware.firmware`). If Wi-Fi/BT is missing after a kernel-related rebuild,
check `dmesg | grep -iE 'mt79|mt6639|btmtk'` for firmware-load errors.

## When the BT function wedges

If the BT firmware load fails, the MT6639's onboard state locks up and the USB
function stops enumerating. The wedge survives normal reboots, because the module
keeps standby power.

Symptoms:

- Boot stalls for ~60 seconds in the XHCI retry loop on the dead port (`error -110`
  lines in `dmesg`).
- `lsusb` shows no `0489:e13a` device, and `/sys/class/bluetooth` is empty.

### Recovery

1. **Check the firmware is actually there.** A failed load is what causes the wedge,
   so confirm the cause is gone before clearing the symptom:

   ```sh
   uname -r                                        # want >= 7.2
   ls /run/current-system/firmware/mediatek/mt7927 # want BT_RAM_CODE_MT6639_2_1_hdr.bin.zst
   dmesg | grep -iE 'mt79|mt6639|btmtk'            # want no firmware-load errors
   ```

2. **Cold power drain.** Shut down, switch the PSU off (or unplug), wait 60 seconds,
   power on. A warm reboot does not clear it.
3. **Only if it keeps coming back: enable ErP temporarily** (Advanced → APM
   Configuration → ErP Ready → S4+S5). That cuts the USB standby rail at every
   shutdown, so the controller cold-initialises every time and the wedge cannot
   survive one. Treat it as a tool, not a setting: turn it back off once BT has come
   up clean a couple of times. The costs are below.

This machine wedged during the pre-7.2 kernel era, before the BT firmware was
installed. With the 7.2 kernel and `pkgs/mt7927bt-firmware.nix` in place the load
succeeds, so the wedge has no cause to recur.

### What ErP costs while it is on

Everything that runs off the USB standby rail while the machine is off stops working:

- **The ROG STRIX HIVE II (USB `0b05:1bc4`) is dead in S5**, so its power button
  cannot start the PC — its button signals the board over USB, not over the panel
  header. Use the chassis power button, which is unaffected.
- No Wake-on-LAN, no USB keyboard/mouse wake, no RTC wake.
- No USB charging on standby, and no Aura lighting in the off state.

The board offers `Disabled` / `S4` / `S4+S5`, and `S4` is not a middle ground: it cuts
the standby rail for hibernate only, leaving it up through a normal shutdown — which is
exactly where the wedge has to be broken. This machine never hibernates, so `S4`
behaves like `Disabled`: the HIVE II button keeps working, and a wedge would keep
surviving shutdowns. Only `S4+S5` breaks the wedge, and only by paying the costs above.

Quick way to tell which side of that line a setting falls on: shut down and press the
HIVE II power button. If the PC starts, the standby rail survived the shutdown — and so
would a wedged controller.

There is no software substitute. A shutdown hook can unbind `btusb` and drop the USB
device, but it cannot power-cycle the controller, which is what actually clears the
lockup.

### Long-term setting

**ErP disabled**, with the cold drain above as the recovery if the wedge ever returns.
That trades one slow boot in a rare failure case for keeping the HIVE II power button
on every boot.
