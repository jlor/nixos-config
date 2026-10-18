# Gaming

Steam, Battle.net, the sim racing rig and the Quest 3. Configured in
`configuration.nix`, `simracing.nix` and `vr.nix`.

## Battle.net

Open Lutris → search "Battle.net" → Install. Lutris fetches its own Wine runner.
Alternative: add the Battle.net installer to Steam as a non-Steam game and force Proton.

## Steam tips

- Proton-GE is pre-installed; select it under Properties → Compatibility.
- Launch options: `gamemoderun mangohud %command%`

## Sim racing

The whole rig hangs off its own USB hub, which plugs into the HIVE II (via a USB 3
extender cable, because the hub's own lead doesn't reach the back of the PC). Nothing in
this config cares which port anything is in — `pam_u2f` matches the YubiKey by credential,
not by port — so the hub and the YubiKey just need two free HIVE II slots between them.

| Device | How Linux sees it | Needs |
|---|---|---|
| Moza R5 base + SR-P Lite pedals | One USB device, `346e:0004`; the pedals plug into the base | `hid-universal-pidff`, already in the kernel |
| Simagic GT Neo rim (MagLink) | `3670:0805`, a plain HID gamepad on its own `js*` | Nothing for games; a udev rule for SimPro Manager |
| Realteus ForceFeel pad | CDC serial, `/dev/ttyACM*` | udev rule + SimHub |
| SimHub Controller Remapper Bridge | Serial in, virtual gamepad out | udev rule + SimHub |
| FT232R board (wind sim / dash) | `/dev/ttyUSB0` | udev rule + SimHub |

Force feedback needs no setup. The 6.18 kernel's `hid-universal-pidff` driver has the R5
in its device table and loads itself on plug-in. After connecting the base, check:

```sh
sudo dmesg | grep -i pidff        # should name the Moza base
ls /dev/input/by-id/              # one *-event-joystick per device
```

`simracing.nix` grants the logged-in user access to the serial and raw-HID nodes, which
NixOS otherwise leaves at `root:dialout 0660` and `root:root 0600`. Each device is listed
there by vendor/product id — **add a line when you add a box to the rig**, or its
`/dev/ttyACM*` stays unopenable.

Add it to the `60-simracing.rules` block in that file, not to `services.udev.extraRules`.
`TAG+="uaccess"` only grants anything if systemd's `73-seat-late.rules` sees the tag, and
udev reads rule files in lexical order — `extraRules` is hardcoded to `99-local.rules`,
which is read too late, so the tag is set but no ACL is ever applied.

**Settings:** run `boxflat` for the Moza side (FFB strength, steering angle, pedal curves,
LEDs). It's the Linux stand-in for Pit House and cannot flash firmware, so base firmware
updates still need Pit House on Windows. Simagic's SimPro Manager is Windows-only too: add
its installer to Steam, force Proton Experimental, and launch it with
`PROTON_ENABLE_HIDRAW=1 %command%`.

**If a game doesn't see a device,** it's almost always SDL's wheel detection. Add a launch
option naming it, e.g. `SDL_JOYSTICK_WHEEL_DEVICES=0x346e/0x0004 %command%` (ids from
`lsusb`).

**Assetto Corsa EVO** needs nothing installed — Steam, Proton and the wheel are already
set up. It's a DX12 title, so it runs through VKD3D, and if the launcher fails to appear
set the launch option:

```
VKD3D_CONFIG=force_raw_va_cbv %command%
```

Expect some stuttering at certain track locations; that's a DX12-on-Linux limitation, not
a configuration problem. The AMD interior/mirror glitches reported upstream are a Mesa
issue and don't apply to the 5090.

### SimHub (haptics, dash, wind)

The ForceFeel pad, the remapper bridge and the FT232 board all exist to be driven by
SimHub, which is Windows-only .NET. It does run here, but only under Wine — and a game's
telemetry lives in shared memory that a Wine-hosted app can't normally see, so it needs a
bridge. [linux-simracing-utils](https://github.com/srounce/linux-simracing-utils) installs
SimHub (and CrewChief) into its own Wine prefix and sets up Winecarte to replicate that
shared memory across prefixes. It detects NixOS and pins its own nixpkgs revision for the
loader and runtime libraries, so it needs nothing from this config:

```sh
curl -fsSL https://raw.githubusercontent.com/srounce/linux-simracing-utils/HEAD/install.sh | bash
```

This is the one part of the rig that can't be declarative: proprietary Windows software in
a user-owned Wine prefix. It lands in `~/linux-simracing-utils` (prefix under `pfx/`), and
**that directory holds every ShakeIt profile you tune**, so back it up — see
[What to back up](../README.md#what-to-back-up).

Two things the installer does *not* do, both per-prefix and manual:

- **Serial devices.** SimHub looks for a COM port, not a `/dev/tty*`. Map each board into
  the prefix with a symlink under `dosdevices`.

  Use the `/dev/serial/by-id/` path, never `/dev/ttyACM0`. The `ttyACM` numbers are
  handed out in enumeration order and move between boots — the ForceFeel pad and the
  Moza base have already swapped numbers on this machine. A `com*` symlink pointing at a
  number will silently address the wrong board. `ls -l /dev/serial/by-id/` lists them:

  ```sh
  cd ~/linux-simracing-utils/pfx/dosdevices
  ln -s /dev/serial/by-id/usb-ForceFeel_ForceFeel_Pad-if00 com1
  ln -s /dev/serial/by-id/usb-Unknown_SimHub_Controller_Remapper_Bridge_0123456789-if00 com2
  ln -s /dev/serial/by-id/usb-FTDI_FT232R_USB_UART_A50285BI-if00-port0 com3
  ```

  If a board still doesn't appear, add the same paths under `HKLM\Software\Wine\Ports`
  in that prefix (`"COM1"="/dev/serial/by-id/…"`) — older Wine wants the registry entry
  as well as the symlink. The udev rules in `simracing.nix` are what make the node
  openable in the first place.
- **Raw HID.** Wine gates hidraw behind an `EnableHidraw` registry list; the installer
  ships a helper that adds a device to it.

## VR (Quest 3)

Meta's Quest Link is Windows-only, so the headset streams from this machine over the LAN
with [WiVRn](https://wivrn.github.io/) instead. The server is already running (as your
user, from login). One-time setup on the headset:

1. Install **WiVRn** from the Meta Horizon Store (free).
2. Put the headset on the same network as this machine — it finds `desktop` by mDNS.
3. Open WiVRn on the headset and pair; confirm the pairing in `wivrn-dashboard` here.

Then launch a VR game from Steam, or from the headset via WiVRn's application list.
OpenVR (SteamVR) titles are redirected into WiVRn by xrizer, with OpenComposite as a
fallback the dashboard can switch to per game — SteamVR itself is not installed.

Notes:

- This PC is on ethernet, so the headset's hop to the router is the only wireless leg.
  Keep it on 5 GHz or 6 GHz; a congested 2.4 GHz band will stutter.
- `vr.nix` pins the encoder to NVENC + AV1, which is what the 5090 encodes and the Quest 3
  decodes best. The dashboard's encoder picker won't stick — change it in `vr.nix`.
- `steam.importOXRRuntimes` needs a logout to take effect after a fresh deploy.
- Le Mans Ultimate's VR is currently broken through the OpenVR translation layers (it
  bundles its own Windows OpenComposite). Assetto Corsa, ACC and AMS2 are the safe bets.
