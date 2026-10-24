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
- Enable ErP (Advanced → APM Configuration → ErP Ready → S4+S5): it cuts the
  USB standby rail at shutdown, which the MT7927's Bluetooth function needs to
  cold-initialise (see below). Trade-off: the USB ports stay unpowered while
  the machine is off, so nothing charges on standby.

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

The BT function can wedge: if its firmware load fails, the MT6639's onboard
state locks up and the USB function stops enumerating. The wedge survives
normal reboots, because the module keeps standby power — which is what the ErP
setting above cuts. Symptoms: boot stalls for ~60 seconds in the XHCI retry
loop on the dead port (`error -110` lines in `dmesg`), `lsusb` shows no `0489`
device and `/sys/class/bluetooth` is missing. This machine wedged during the
pre-7.2 kernel era, before the BT firmware was installed. A warm reboot does
not clear it; a full power drain does: shut down, switch the PSU off (or
unplug), wait 60 seconds, power on. With ErP on, the controller
cold-initialises after every shutdown, so the wedge cannot survive one.
