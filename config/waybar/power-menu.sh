#!/bin/sh
# Power menu shown via fuzzel. Bound to the ⏻ button in waybar and SUPER+Escape.
choice=$(printf '󰌾  Lock\n󰍃  Log out\n󰜉  Reboot\n󰐥  Shut down\n' \
  | fuzzel --dmenu --lines 4 --width 18 --prompt '  ')

case "$choice" in
  *Lock)       loginctl lock-session ;;
  *"Log out")  hyprctl dispatch 'hl.dsp.exit()' ;;
  *Reboot)     systemctl reboot ;;
  *"Shut down") systemctl poweroff ;;
esac
