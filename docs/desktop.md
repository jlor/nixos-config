# Desktop

Hyprland, the bar, the launcher and the keys. Everything here is deployed from
`config/` in this repo.

## Look & feel

- **Boot:** silent boot with the Catppuccin Plymouth splash. The boot menu is hidden;
  hold **Space** while booting to show it (for rolling back).
- **Login:** ReGreet, a graphical greeter on the wallpaper.
- **Desktop:** frosted-glass bar, launcher and notifications; gradient window borders;
  spring animations; separate wallpapers for the landscape and portrait screens.
- **Lock screen:** blurred snapshot of your desktop, big clock, frosted password field.
  Locks after 10 min idle, screens off after 15. Fullscreen games and videos pause this.
- **Terminal:** kitty with a trailing-cursor animation, zsh with the Spaceship prompt
  (see [Terminal](terminal.md)).

Changing the look: edit files in `config/`, push, and comin applies it.
Reload Hyprland with `hyprctl reload`, and Waybar with `pkill waybar; waybar &`.

## At login

Four apps start themselves and land in the same place every time
(`config/hypr/hyprland.lua`, the autostart block):

| App | Where |
|---|---|
| Firefox | Portrait screen (workspace 6), top, with the previous session's tabs |
| Discord | Portrait screen (workspace 6), below Firefox |
| ZapZap | Tray only — no window until you click it |
| kitty | Main screen (workspace 1) |

Each one is launched with a window rule attached to that command alone, so
opening Firefox or Discord by hand later still puts the window wherever you are.
The rule covers the first window a command opens (Hyprland's
`misc:initial_workspace_tracking`), so if your last session had several Firefox
windows, the rest come back wherever Firefox puts them.

Firefox and Discord are ordered rather than just assigned a workspace, because
dwindle picks which side of a split a new window takes from where the cursor is,
and at login the cursor is on the main screen. So Firefox goes first, Discord
follows once Firefox has a window, and if the pair comes out upside down they're
swapped. Nothing about this changes how windows open the rest of the time.

Restored tabs come from Firefox's own session store, set by policy
(`Homepage.StartPage = "previous-session"` in `configuration.nix`). It's a default,
not a locked value, so Settings → General → Startup still works. ZapZap is started
with `--hideStart` rather than its own "Start minimized" checkbox, so the behaviour
lives in this repo instead of in `~/.config/ZapZap/ZapZap.conf`.

With only one screen connected, workspace 6 falls back onto it: Firefox and Discord
still open together on their own workspace, and the top/bottom stacking is skipped —
side by side on a landscape screen beats two short wide windows.

## Launcher (Walker)

**Super + Space** opens Walker, which searches apps by default. Type a prefix to switch
mode (same as Omarchy):

| Prefix | Mode |
|---|---|
| `.` | Files in your home folder |
| `:` | Emoji & symbols |
| `=` | Calculator |
| `$` | Clipboard history |
| `@` | Web search |
| `+` | Switch to an open window |
| `>` | Run a command |
| `*` | 1Password: copy a password |
| `;` | List all modes |

The power menu (Super + Escape, or ⏻ in the bar) is a Walker menu defined in
`config/elephant/menus/power.toml`; add your own menus next to it.

## Hyprland keys

| Keys | Action |
|---|---|
| Super + Enter | Terminal (kitty) |
| Super + Space | Launcher (Walker) |
| Super + E | File manager |
| Super + Q | Close window |
| Super + F | Fullscreen |
| Super + V | Toggle floating |
| Super + arrows | Move focus |
| Super + Shift + arrows | Move window |
| Super + 1–9 | Switch workspace (1–5 left screen, 6–9 right) |
| Super + Shift + 1–9 | Move window to workspace |
| Super + C | Clipboard history |
| Super + Ctrl + E | Emoji & symbols |
| Super + L | Lock |
| Super + K | Show this keybind list |
| Super + Escape | Power menu (lock, log out, reboot, shut down) |
| Super + Shift + E | Log out immediately |
| Print / Super + Shift + S | Screenshot a region (clipboard only) |
| Super + Print | Screenshot a window (point and click) |
| Super + Shift + Print | Screenshot a monitor (click the one you want) |
| Super + Ctrl + S | Screenshot a region and annotate it |

Screenshots come from [hyprshot](https://github.com/Gustash/Hyprshot). A region shot
goes to the clipboard and nowhere else — it's the throwaway one you paste straight into
a chat, and keeping every one of those just fills `~/Pictures` with files you can't tell
apart. Window and monitor shots are the deliberate ones, so they land on the clipboard
*and* in `~/Pictures`. The screen freezes while you select, so menus and tooltips stay
open long enough to capture. Annotation (arrows, boxes, blur) is
[satty](https://github.com/gabm/Satty), themed to match in `config/satty/config.toml`:
Enter copies and closes, Escape discards.
