# NixOS desktop config (9800X3D + RTX 5090)

## Install

1. **Boot the installer.** Use the NixOS 26.05 graphical ISO. If it hangs with the 5090,
   pick the `nomodeset` boot entry (the installer won't have the open Nvidia driver yet).
2. Partition and install as normal (the Calamares installer is fine). Create the user
   **`jlor`**, which must match `username` in `configuration.nix`. Reboot.
3. Follow the **Bootstrap** steps under "GitOps with comin" below.
4. `mkdir -p ~/.config/hypr && ln -s ~/nixos-config/hyprland.conf ~/.config/hypr/hyprland.conf`
5. Reboot, log in at the text greeter, and Hyprland starts. Check the driver with `nvidia-smi`.

## Hyprland keys

| Keys | Action |
|---|---|
| Super + Enter | Terminal (kitty) |
| Super + D | App launcher |
| Super + Q | Close window |
| Super + F | Fullscreen |
| Super + V | Toggle floating |
| Super + 1–9 | Switch workspace |
| Super + Shift + 1–9 | Move window to workspace |
| Super + L | Lock |
| Super + Shift + E | Log out |
| Print | Screenshot region to clipboard |

## Day-to-day

- Update: `nix flake update`, commit and push `flake.lock`; comin deploys it.
- Quick local test without pushing: `sudo nixos-rebuild test --flake ~/nixos-config#desktop`
- Roll back a bad update: pick an older generation in the boot menu.
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
- Optional: enable Resizable BAR (Above 4G Decoding + ReBAR).
