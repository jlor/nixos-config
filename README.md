# NixOS desktop config (9800X3D + RTX 5090)

Hyprland desktop themed in Catppuccin Mocha with a mauve accent, from boot splash to
terminal. Everything, dotfiles included, is deployed from this repo by comin.

A reinstall gets back to this exact state with three things: install NixOS, run
`nix run github:jlor/nixos-config#bootstrap`, restore the backed-up keys.

## Documentation

| Guide | What's in it |
|---|---|
| [Desktop](docs/desktop.md) | Look & feel, what starts at login, Walker launcher, Hyprland keybindings, screenshots |
| [Terminal](docs/terminal.md) | zsh + Spaceship, fzf, vim, per-project dev shells (direnv) |
| [Security](docs/security.md) | 1Password, YubiKey (touch-to-sudo, disk unlock), sops secrets |
| [Deploying](docs/deploying.md) | comin GitOps, CI, Renovate update PRs |
| [Gaming](docs/gaming.md) | Steam, Battle.net, the sim racing rig, Quest 3 VR |
| [NAS shares](docs/nas.md) | On-demand NFS mounts under `~/nas` |
| [AI](docs/ai.md) | Claude Code and a local model on the 5090 |
| [Hardware](docs/hardware.md) | The machine, the monitors, BIOS settings |

[`CLAUDE.md`](CLAUDE.md) holds the working rules for Claude Code sessions on this repo.

## What's installed

- **Desktop:** Hyprland (UWSM) on Wayland, Waybar, Walker, mako, hyprlock/hypridle,
  ReGreet login screen, Plymouth boot splash — all Catppuccin Mocha.
- **Terminal:** kitty, zsh + Spaceship, vim, git/gh, fzf, ripgrep, fd, eza, bat, zoxide,
  direnv.
- **Apps:** Firefox (with uBlock Origin and SponsorBlock), 1Password, Discord,
  ZapZap (WhatsApp), VS Code, Nautilus.
- **Gaming:** Steam (Proton-GE, gamescope, gamemode), Lutris, MangoHud, the sim racing
  stack, WiVRn for the Quest 3.
- **AI:** Claude Code against Anthropic; omp against an abliterated Qwen3.8-27B
  served locally by NInfer on the 5090.
- **Under it:** Nvidia open driver, PipeWire, NetworkManager, Bluetooth, zram, nix-ld,
  OpenRGB for the Aura lighting.

## Repo layout

| Path | What it is |
|---|---|
| `flake.nix` | Entry point: nixpkgs 26.05, home-manager, sops-nix, comin; the `#bootstrap` app |
| `bootstrap.sh` | Sets up a fresh install against this repo (see Install) |
| `CLAUDE.md` | Working rules for Claude Code sessions on this repo |
| `configuration.nix` | System: drivers, boot splash, login screen, apps |
| `home.nix` | Your user: links the dotfiles below, GTK theme, cursor, shell |
| `config/hypr/` | Hyprland (`hyprland.lua`), lock screen, idle settings |
| `config/waybar/` | Top bar + power menu |
| `config/kitty/`, `config/mako/` | Terminal, notifications |
| `config/walker/`, `config/elephant/` | Launcher theme, power menu |
| `config/zsh/spaceship.zsh` | Shell prompt (Spaceship) |
| `docs/` | The guides linked above |
| `templates/` | Project dev shells (`devshell node` etc.) |
| `secrets.nix`, `.sops.yaml`, `secrets/` | Encrypted secrets (sops + age) |
| `security.nix` | 1Password, YubiKey (touch-to-sudo, disk unlock) |
| `nas.nix` | On-demand NFS mounts from the NAS under `~/nas` |
| `ai.nix`, `pkgs/` | Local AI: the NInfer server and its model, the engine (`ninfer.nix`) and the omp client (`omp.nix`) |
| `simracing.nix` | The sim rig: Moza R5 + pedals, GT Neo rim, haptics, dash boards |
| `vr.nix` | Quest 3 as a PC VR headset (WiVRn) |
| `.github/workflows/ci.yml`, `ci/` | CI: checks every push and pull request |
| `renovate.json` | Weekly update PRs (flake inputs, GitHub Actions) |
| `wallpapers/` | Landscape + portrait wallpapers (desktop and login screen) |

## Install

The same steps work for the first install and for a reinstall. Have your YubiKey plugged in
and your 1Password login (email, Secret Key, password) at hand.

1. **BIOS:** see [Hardware](docs/hardware.md) (EXPO, Resizable BAR, monitors on the 5090).
2. **Install NixOS** from the 26.05 graphical ISO. If it hangs with the 5090, pick the
   `nomodeset` boot entry (the installer doesn't have the open Nvidia driver yet).
   The installer's choices, step by step (this repo replaces the rest):
   - **Location / Keyboard:** Europe/Copenhagen, Danish. Only used until the bootstrap.
   - **Users:** create **`jlor`** (the config defines this user; any other name fails).
   - **Desktop:** **No desktop**. Hyprland comes from this repo, and a desktop chosen here
     would just be installed and thrown away. You get a text login to run the bootstrap.
   - **Unfree software:** either; the config enables it anyway (Nvidia, Steam, 1Password).
   - **Partitions:** **Erase disk**, and tick **Encrypt system** with a strong passphrase.
     This can only be chosen now; the YubiKey is added on top later, and the passphrase
     stays as fallback.
   - **Swap: "No swap"**. The config uses compressed RAM swap (zram), and an encrypted
     swap partition from the installer wouldn't carry over and would stall the boot.

   Reboot into the new system and log in as jlor at the text prompt.
3. **Run the bootstrap**, as jlor:

   ```sh
   nix --extra-experimental-features "nix-command flakes" run --refresh --no-write-lock-file github:jlor/nixos-config#bootstrap
   ```

   It clones the repo to `~/nixos-config`, adds this machine's hardware config, and sets
   up the sops keys and secrets. Your personal age key is generated and stored in
   1Password the first time, and fetched from it on a reinstall (or pasted, if you'd
   rather not sign in). With the YubiKey plugged in, it also registers it for
   touch-to-sudo, enrolls it to unlock the disk, and can add it as a second key for the
   secrets. Then it builds the full system and offers to commit and push the result.
   Every step is skipped when already done, so it's safe to re-run. Read
   [`bootstrap.sh`](bootstrap.sh) for the details.
4. **Reboot.** Touch the YubiKey (or type the passphrase) to unlock the disk, then pick
   **Hyprland (UWSM)** at the login screen (it's remembered). Check the driver with
   `nvidia-smi`.
5. **Finish 1Password** in the app (see [Security](docs/security.md#1password)): switch on
   the SSH agent and CLI integration, and set up commit signing.

## Day-to-day

- Update: `nix flake update`, commit and push `flake.lock`; comin deploys it.
- Quick local test without pushing: `sudo nixos-rebuild test --flake ~/nixos-config#desktop`
- Roll back a bad update: hold Space at boot and pick an older generation.
- Flakes only see files tracked by git, so `git add` new files before rebuilding.
- Changes reach the machine through a PR to `main`; see [Deploying](docs/deploying.md).

## What to back up

The repo restores the whole system and every setting. These live outside it:

| What | Where | Why |
|---|---|---|
| Your personal age key | 1Password, item "nixos-config age key" | Only way (besides the YubiKey, if added) to open the secrets after a reinstall. Bootstrap stores it there. |
| Your YubiKey | Your keychain | Optional second key for the secrets; touch-to-sudo and disk unlock fall back to passwords without it. |
| Disk passphrase | 1Password | Unlocks the disk when the YubiKey isn't at hand. |
| Your home folder's data | `~/` (documents, projects) | Personal files aren't config. Code lives in git remotes anyway. SSH keys live in 1Password. |
| Game libraries | `~/.local/share/Steam`, Lutris prefixes | Large but re-downloadable; back up save games that don't use cloud saves. |
| App logins | 1Password, Firefox, Discord, WhatsApp, Steam, Claude Code, `gh` | Sign in again after a reinstall. Firefox Sync covers the browser. |
| Firefox's open tabs | `~/.mozilla/firefox/*/sessionstore-backups/` | The tabs restored at login (see [Desktop](docs/desktop.md#at-login)) come from the local profile. Sync covers bookmarks and tabs across devices, but a reinstall starts the session empty. |
| Firefox extension settings | The browser profile under `~/.mozilla/firefox/` | The extensions themselves are installed by policy (see [Desktop](docs/desktop.md#firefox-extensions)), but what you tuned inside them — uBlock's filter lists, SponsorBlock's categories — isn't in this repo and starts at the defaults. |
| Local AI model | `/var/lib/ninfer` | 20 GiB, re-downloaded, checksum-verified and re-upgraded automatically after a reinstall. |
| Wheel and rim settings | The Moza base's and the GT Neo's own firmware | Live in the hardware, not on the PC, so a reinstall doesn't touch them. Note down anything you tuned — nothing here can read them back out. |
| SimHub + its ShakeIt profiles | `~/linux-simracing-utils/` | Windows software in a Wine prefix, so it can't be declarative. Reinstalling is one command; the hand-tuned haptics profiles are the part you can't get back. |
| Quest 3 headset settings | The headset | WiVRn's client keeps its own resolution/bitrate settings on the headset. |

Not needed: the desktop's own age key (a reinstall makes a new one, and bootstrap
re-encrypts the secrets for it), `hardware-configuration.nix` (regenerated), and the YubiKey
registrations (stored encrypted in the repo; disk enrollment is redone by bootstrap).
