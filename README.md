# NixOS desktop config (9800X3D + RTX 5090)

Hyprland desktop themed in Catppuccin Mocha with a mauve accent, from boot splash to
terminal. Everything, dotfiles included, is deployed from this repo by comin.

## Repo layout

| Path | What it is |
|---|---|
| `flake.nix` | Entry point: nixpkgs 26.05, home-manager, comin |
| `configuration.nix` | System: drivers, boot splash, login screen, apps |
| `home.nix` | Your user: links the dotfiles below, GTK theme, cursor, shell |
| `config/hypr/` | Hyprland (`hyprland.lua`), lock screen, idle settings |
| `config/waybar/` | Top bar + power menu |
| `config/kitty/`, `config/fuzzel/`, `config/mako/` | Terminal, launcher, notifications |
| `config/starship.toml` | Shell prompt |
| `wallpapers/` | Landscape + portrait wallpapers (desktop and login screen) |

## Install

1. **Boot the installer.** Use the NixOS 26.05 graphical ISO. If it hangs with the 5090,
   pick the `nomodeset` boot entry (the installer won't have the open Nvidia driver yet).
2. Partition and install as normal (the Calamares installer is fine). Create the user
   **`jlor`**, which must match `username` in `configuration.nix`. Reboot.
3. Follow the **Bootstrap** steps under "GitOps with comin" below.
4. Reboot. You'll get the boot splash, then the graphical login: pick
   **Hyprland (UWSM)** as the session (it's remembered). Check the driver with `nvidia-smi`.

## Look & feel

- **Boot:** silent boot with the Catppuccin Plymouth splash. The boot menu is hidden;
  hold **Space** while booting to show it (for rolling back).
- **Login:** ReGreet, a graphical greeter on the wallpaper.
- **Desktop:** frosted-glass bar, launcher and notifications; gradient window borders;
  spring animations; separate wallpapers for the landscape and portrait screens.
- **Lock screen:** blurred snapshot of your desktop, big clock, frosted password field.
  Locks after 10 min idle, screens off after 15. Fullscreen games and videos pause this.
- **Terminal:** kitty with a trailing-cursor animation and the Starship prompt; `ls`, `ll`
  and `tree` use eza with icons, `cat` uses bat. Run `fastfetch` for a system summary.

Changing the look: edit files in `config/`, push, and comin applies it.
Reload Hyprland with `hyprctl reload`, and Waybar with `pkill waybar; waybar &`.

## Hyprland keys

| Keys | Action |
|---|---|
| Super + Enter | Terminal (kitty) |
| Super + D | App launcher |
| Super + E | File manager |
| Super + Q | Close window |
| Super + F | Fullscreen |
| Super + V | Toggle floating |
| Super + J | Toggle split direction |
| Super + arrows / H / K | Move focus |
| Super + Shift + arrows | Move window |
| Super + 1–9 | Switch workspace (1–5 left screen, 6–9 right) |
| Super + Shift + 1–9 | Move window to workspace |
| Super + S | Scratchpad (Shift: send window there) |
| Super + C | Clipboard history |
| Super + L | Lock |
| Super + Escape | Power menu (lock, log out, reboot, shut down) |
| Super + Shift + E | Log out immediately |
| Print | Screenshot region to clipboard |
| Super + Print | Full screenshot to ~/Pictures |

## Day-to-day

- Update: `nix flake update`, commit and push `flake.lock`; comin deploys it.
- Quick local test without pushing: `sudo nixos-rebuild test --flake ~/nixos-config#desktop`
- Roll back a bad update: hold Space at boot and pick an older generation.
- Flakes only see files tracked by git, so `git add` new files before rebuilding.

## GitOps with comin

Once comin is running, the git repo is the source of truth: push to `main` and the
desktop deploys it within about a minute. Commits that fail to build are not deployed.

Bootstrap (one time, on the freshly installed PC):
1. `nix-shell -p git gh` then `gh auth login`
2. `git clone https://github.com/jlor/nixos-config ~/nixos-config && cd ~/nixos-config`
3. `cp /etc/nixos/hardware-configuration.nix . && git add hardware-configuration.nix`
4. `sudo nixos-rebuild switch --flake .#desktop` (this also creates `flake.lock`)
5. `git add flake.lock && git commit -m "Add hardware config and lock file" && git push`

From then on, just push. The repo is public, so comin needs no token. Never commit
secrets (passwords, tokens, SSH keys) here; if you need them later, use sops-nix or agenix.

Tips:
- `comin status` shows what's deployed and what's pending.
- Try risky changes on a testing branch first (see comin's docs on testing branches).
- Updating Nvidia drivers or the kernel needs a reboot, and games may misbehave
  until you do. Avoid pushing those changes mid-session.

## Battle.net

Open Lutris → search "Battle.net" → Install. Lutris fetches its own Wine runner.
Alternative: add the Battle.net installer to Steam as a non-Steam game and force Proton.

## Steam tips

- Proton-GE is pre-installed; select it under Properties → Compatibility.
- Launch options: `gamemoderun mangohud %command%`

## BIOS (ASUS X870-I)

- Enable EXPO for the DDR5-6000 kit.
- Disable Secure Boot (or set up lanzaboote later).
- Enable Resizable BAR (Above 4G Decoding + ReBAR).
- Plug both monitors into the RTX 5090, not the motherboard. The 9800X3D has a small
  integrated GPU; set the primary display to PCIe (or disable the iGPU) so the boot
  splash and login appear on the 5090's screens.
