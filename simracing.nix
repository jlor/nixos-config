{ pkgs, ... }:

# Sim racing hardware. On the rig's own USB hub: a Moza R5 wheelbase with
# SR-P Lite pedals, a Simagic GT Neo rim on a MagLink, a Realteus ForceFeel
# haptic pad, a SimHub remapper bridge and an FT232 board.
#
# The force feedback itself needs nothing from this file. Linux 6.15 gained
# hid-universal-pidff, a driver for wheelbases that speak the USB HID PID
# force-feedback spec, and its device table claims the R5 (usb 346e:0004). The
# 6.18 kernel in 26.05 ships it, udev autoloads it on plug-in, and games see a
# wheel with working FFB — native or under Proton. The pedals ride along on the
# same USB device, because SR-P Lite plugs into the base's pedal port rather
# than into the PC, so the base reports wheel and pedal axes together.
#
# What this file adds is the parts around the driver: the settings app, and
# access to the side channels the settings apps talk over.
#
# The wheel and the rim keep their settings in their own firmware, and the
# SimHub side lives in a Wine prefix, so none of that is in this repo and none
# of it is restored by a reinstall. See "What to back up" in the README.

let
  # These rules have to be installed as a package rather than through
  # services.udev.extraRules, and the reason is pure file ordering.
  #
  # TAG+="uaccess" does not itself grant anything. systemd's own
  # 73-seat-late.rules is what turns the tag into an ACL:
  #
  #   TAG=="uaccess", ENV{MAJOR}!="", RUN{builtin}+="uaccess"
  #
  # udev reads its rule files in lexical order, so a rule that adds the tag
  # must sort before 73. extraRules is hardcoded to 99-local.rules, which is
  # read *after* 73-seat-late has already looked for the tag and not found it:
  # the tag lands in the udev database, no ACL is applied, and the device stays
  # unreadable. (The next event on that device does work, because by then the
  # tag is in the database — which is why this looked intermittent. /run/udev
  # is tmpfs, so a reboot puts it back to broken.)
  #
  # Hence 60-: before 73-seat-late, after 60-serial.rules which sets up the
  # ID_VENDOR_ID properties. services.udev.packages reads <pkg>/lib/udev/rules.d.
  simracingRules = pkgs.writeTextFile {
    name = "simracing-udev-rules";
    destination = "/lib/udev/rules.d/60-simracing.rules";
    text = ''
      # Simagic GT Neo rim on a MagLink (3670:0805). It's a plain HID gamepad —
      # buttons, encoders, clutch paddles, no force feedback — so games already
      # see it with no driver and no rule: the kernel gives it a js*/event*
      # node, and logind ACLs those by itself. This opens its hidraw node
      # instead, which is what Simagic's SimPro Manager needs to remap buttons.
      #
      # Matched on the vendor alone, so a second Simagic device is covered too.
      # Older Simagic hardware answers to 0483 rather than 3670.
      KERNEL=="hidraw*", ATTRS{idVendor}=="3670", TAG+="uaccess"

      # Realteus ForceFeel haptic pad: a CDC serial device (/dev/ttyACM*),
      # driven by SimHub's ShakeIt plugin.
      SUBSYSTEM=="tty", ATTRS{idVendor}=="04d8", ATTRS{idProduct}=="ee96", TAG+="uaccess"

      # SimHub Controller Remapper Bridge: serial in, virtual gamepad out. The
      # gamepad half already works — logind ACLs input devices by itself. This
      # is for the serial half that SimHub drives it through.
      SUBSYSTEM=="tty", ATTRS{idVendor}=="8888", ATTRS{idProduct}=="9778", TAG+="uaccess"

      # FT232R UART — the Arduino-style board on the rig (wind sim / dash).
      SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", TAG+="uaccess"
    '';
  };
in
{
  # Boxflat is the Linux stand-in for Moza Pit House: FFB strength, steering
  # angle, pedal curves, wheel LEDs. It reaches the base over the CDC serial
  # interface the base exposes next to its HID one (/dev/ttyACM*), and the
  # package ships the udev rules that let a logged-in user open that device.
  #
  # It deliberately cannot flash firmware. Base firmware updates still mean
  # Pit House on Windows — the one thing here that isn't reproducible from Nix.
  environment.systemPackages = [ pkgs.boxflat ];

  # boxflat's own rules file is 99-boxflat.rules, so its uaccess tag is too
  # late for the same reason as above — but it also sets MODE="0666" on the
  # base's ttyACM, which needs no builtin, so Boxflat works regardless.
  services.udev.packages = [ pkgs.boxflat simracingRules ];

  # Boxflat presents the base's stalk switches and hub buttons to games as a
  # virtual joystick, which it creates through /dev/uinput.
  hardware.uinput.enable = true;

  # Everything else on the rig talks over a USB serial port or a raw HID node,
  # and neither kind is readable by a logged-in user on NixOS by default: tty
  # devices come up root:dialout 0660 and hidraw root:root 0600, with no ACL.
  # The rules above are what open them, one entry per box — which doubles as
  # the inventory of what's on the rig. Get the ids of anything new from
  # `lsusb`, and add it there rather than here.
  #
  # uaccess rather than putting jlor in the `dialout` group, so that a UART
  # adapter plugged in later for something unrelated doesn't silently become
  # readable as well.

  # If a game or Proton title ignores a device, it is almost always SDL
  # guessing: it only treats an input device as a wheel if it looks like one,
  # or if its vendor/product is on SDL's list. The per-game escape hatch is a
  # launch option, e.g.
  #   SDL_JOYSTICK_WHEEL_DEVICES=0x346e/0x0004 %command%
  # Nothing here needs it today; it's the first thing to try if something does.
}
