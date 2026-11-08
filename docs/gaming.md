# Gaming

Steam, Battle.net, the sim racing rig and the Quest 3. Configured in
`configuration.nix`, `simracing.nix` and `vr.nix`.

## Battle.net

Open Lutris → search "Battle.net" → Install. Lutris fetches its own Wine runner.
Alternative: add the Battle.net installer to Steam as a non-Steam game and force Proton.

## Steam tips

- Proton-GE is pre-installed; select it under Properties → Compatibility.
- Launch options: `gamemoderun mangohud %command%`
- **Tearing is off** (`general.allow_tearing = false` in
  `config/hypr/hyprland.lua`), so games stay vsynced at the monitor's refresh rate.
  The `games-allow-tearing` window rule is left in place but inert as a result;
  flipping `allow_tearing` back to `true` is all it takes to re-enable tearing, and
  its lower input lag, for Steam games.
- **VRR (adaptive sync) is off** (`misc.vrr = 0` in `config/hypr/hyprland.lua`),
  because neither monitor supports it. With it on, the driver retried VRR on every
  commit and filled the Hyprland log with
  `drm: No Adaptive sync support for output`.

  **The Samsung on DP-1 has no FreeSync.** The CJG5 line gates it per model: the
  manual carries a FreeSync section only for the 1080p C32JG53FD, not for the
  1440p variants, and this panel is 2560x1440 native. There is accordingly no
  FreeSync entry in the monitor's Game menu, the kernel reports `vrr_capable = 0`
  for DP-1, and Hyprland logs
  `aquamarine: drm: connector DP-1 crtc is incapable of vrr`. It is the monitor and
  not the driver: `nvidia_modeset`'s `conceal_vrr_caps` is `N`, so nothing is being
  hidden. Nothing in this repo can change that — it needs a monitor that supports
  adaptive sync.

  If a VRR-capable monitor ever replaces it, set `misc.vrr` back to `2` (fullscreen
  only — the desktop keeps a fixed refresh rate and only games get adaptive sync)
  and check:

  ```sh
  # want 1, not 0 (drm_info isn't installed; nix run fetches it on the fly)
  nix run nixpkgs#drm_info -- /dev/dri/card1 | grep -A1 vrr_capable
  hyprctl monitors | grep vrr   # vrr: true while something is fullscreen
  ```

  Two traps when testing with `misc.vrr = 2`: `vrr: false` on an idle desktop is
  expected, so you need a genuinely fullscreen window; and a transparent one never
  counts (kitty is 0.88 opacity) — `solitaryBlockedBy: not opaque` in
  `hyprctl monitors` is the tell. Also note the panel's EDID advertises
  `Monitor ranges: 50-144 Hz V`, which is just the GTF refresh range every monitor
  carries, not evidence of adaptive sync.
- **DP-1 runs at 120Hz, not the 144Hz the panel supports.** Long-standing, not a
  regression, and the cause is unresolved. Both monitor-side settings are already
  correct (Game → Refresh Rate = 144 Hz, System → DisplayPort Ver. = `1.2↑`) and
  the EDID validly advertises 1440p144 (586.58 MHz, under the monitor's 590 MHz DP
  ceiling) — but the Nvidia driver prunes that one mode at connector probe, before
  Hyprland ever sees it. `drm_info` lists only 120/100/60 Hz.

  Already ruled out, so they don't get re-tried:
  - **Not the OSD, and not a stale link.** A cold power-cycle (power pulled, 10s)
    leaves the EDID byte-identical and the mode list unchanged.
  - **Not forceable from the config.** Asking for the mode by name is silently
    ignored — the driver won't synthesise a mode it hasn't validated — and
    Hyprland 0.55's Lua config has no `modeline` support.
  - **Probably not the cable.** Mode pruning is validated against what the monitor
    advertises over DPCD, not the rate the link actually trained at; a marginal
    cable shows up as instability, not a missing mode.

  The leading (unconfirmed) theory is that the driver validates at 10bpc. Against
  DP 1.2's 17.28 Gbps payload budget, 1440p120 needs 14.93 and fits while 1440p144
  needs 17.60 and misses by 0.3 — which would prune exactly this one mode. At 8bpc
  both fit (11.95 and 14.08), so 144Hz ought to work. There is no supported lever:
  Nvidia exposes no `max bpc` connector property, and `hdmi_deepcolor` is
  HDMI-only.

  Nothing to change here if it's ever fixed — `mode = "highrr"` in
  `config/hypr/hyprland.lua` picks the highest rate the monitor advertises. Check
  with `hyprctl monitors | grep -A1 "^Monitor DP-1"`.

## Sim racing

The whole rig hangs off its own USB hub, which plugs straight into a rear port on the
PC (via a USB 3 extension cable, because the hub's own lead doesn't reach; the cable
makes no difference to anything here). Nothing in this config cares which port anything
is in — `pam_u2f` matches the YubiKey by credential, not by port.

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

It prompts, so don't background it. `winetricks` has to be on PATH or it stops before
doing anything — it's in `configuration.nix` for that reason. It brings its own Wine
(`~/linux-simracing-utils/bin/wine`, 11 or newer required), which is why no `wine` package
sits alongside it: a second, older wine on PATH is only a chance to use the wrong one.

This is the one part of the rig that can't be declarative: proprietary Windows software in
a user-owned Wine prefix. It lands in `~/linux-simracing-utils` (prefix under `pfx/`), and
**that directory holds every ShakeIt profile you tune**, so back it up — see
[What to back up](../README.md#what-to-back-up).

Two things the installer does *not* do, both per-prefix and manual:

- **Serial devices.** SimHub wants a COM port, not a `/dev/tty*`. Wine maps those itself
  when the prefix boots, by device number:

  ```
  com5 -> /dev/ttyUSB0     com7 -> /dev/ttyACM1
  com6 -> /dev/ttyACM0     com8 -> /dev/ttyACM2
  ```

  Those numbers are handed out in enumeration order and move between boots — the
  ForceFeel pad and the Moza base have already swapped on this machine. SimHub stores
  profiles against COM numbers, so after a shuffle it drives the wrong board silently.

  **Don't fix this by editing `dosdevices`.** Wine wipes and recreates those symlinks
  every time a program starts in the prefix, so hand-made links are gone by the next
  launch. The mechanism that persists is the registry key `HKLM\Software\Wine\Ports`,
  which Wine's auto-mapping leaves alone.

  Use COM numbers above Wine's own range so the two never collide, and point them at
  `/dev/serial/by-id/`, which names each board by USB id and serial
  (`ls -l /dev/serial/by-id/` lists what's attached):

  ```sh
  cd ~/linux-simracing-utils/bin
  export WINEPREFIX=~/linux-simracing-utils/pfx
  ./wine reg add 'HKLM\Software\Wine\Ports' /f /t REG_SZ \
    /v COM10 /d /dev/serial/by-id/usb-ForceFeel_ForceFeel_Pad-if00
  ./wine reg add 'HKLM\Software\Wine\Ports' /f /t REG_SZ \
    /v COM11 /d /dev/serial/by-id/usb-Unknown_SimHub_Controller_Remapper_Bridge_0123456789-if00
  ./wine reg add 'HKLM\Software\Wine\Ports' /f /t REG_SZ \
    /v COM12 /d /dev/serial/by-id/usb-FTDI_FT232R_USB_UART_A50285BI-if00-port0
  ./wineserver -k     # restart the prefix so it re-reads the key
  ```

  Then pick COM10–COM12 in SimHub, and ignore the `com1`–`com8` it also offers.

  The Moza base is deliberately not mapped in: Boxflat talks to it over the same serial
  port, and two programs holding it at once is a fight neither wins. Use Boxflat for the
  base and leave SimHub to the haptics and the boards.

  The udev rules in `simracing.nix` are what make these nodes openable in the first place.
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

### Reaching the desktop from inside the headset

WiVRn starts **wayvr** (formerly wlx-overlay-s) with the session: it puts this desktop's
windows and a virtual keyboard on top of whatever is running, reachable from the
controllers. Bring it up with the controller menu button.

You need it more than it sounds. With the headset on, the monitor is out of reach, and two
things live there:

- **A game's flat-screen menu.** Some titles render their UI only to the desktop window,
  so in the headset you get the car and the track but nothing to click.
- **Keyboard focus.** Keystrokes go to whichever surface the compositor has focused, which
  with a headset on means typing blind into whatever window happens to hold focus.

If a game's keyboard input isn't reaching it, check which window Hyprland has focused:

```sh
hyprctl clients | grep -iE "class|title|focus"
```

Notes:

- This PC is on ethernet, so the headset's hop to the router is the only wireless leg.
  Keep it on 5 GHz or 6 GHz; a congested 2.4 GHz band will stutter.
- `vr.nix` pins the encoder to NVENC + AV1, which is what the 5090 encodes and the Quest 3
  decodes best. The dashboard's encoder picker won't stick — change it in `vr.nix`.
- `steam.importOXRRuntimes` needs a logout to take effect after a fresh deploy.
- Le Mans Ultimate's VR is currently broken through the OpenVR translation layers (it
  bundles its own Windows OpenComposite). Assetto Corsa, ACC and AMS2 are the safe bets.
