# NixOS desktop config (9800X3D + RTX 5090)

Hyprland desktop themed in Catppuccin Mocha with a mauve accent, from boot splash to
terminal. Everything, dotfiles included, is deployed from this repo by comin.

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
| `templates/` | Project dev shells (`devshell node` etc.) |
| `secrets.nix`, `.sops.yaml`, `secrets/` | Encrypted secrets (sops + age) |
| `security.nix` | 1Password, YubiKey (touch-to-sudo, disk unlock) |
| `nas.nix` | On-demand NFS mounts from the NAS under `~/nas` |
| `simracing.nix` | The sim rig: Moza R5 + pedals, GT Neo rim, haptics, dash boards |
| `vr.nix` | Quest 3 as a PC VR headset (WiVRn) |
| `.github/workflows/ci.yml`, `ci/` | CI: checks every push and pull request |
| `renovate.json` | Weekly update PRs (flake inputs, GitHub Actions) |
| `wallpapers/` | Landscape + portrait wallpapers (desktop and login screen) |

## Install

The same steps work for the first install and for a reinstall. Have your YubiKey plugged in
and your 1Password login (email, Secret Key, password) at hand.

1. **BIOS:** see "BIOS" at the end (EXPO, Resizable BAR, monitors on the 5090).
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
5. **Finish 1Password** in the app (see "1Password" below): switch on the SSH agent and
   CLI integration, and set up commit signing.

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
| Local AI models | `/var/lib/ollama` | Re-downloaded automatically after a reinstall. |
| Wheel and rim settings | The Moza base's and the GT Neo's own firmware | Live in the hardware, not on the PC, so a reinstall doesn't touch them. Note down anything you tuned — nothing here can read them back out. |
| SimHub + its ShakeIt profiles | `~/linux-simracing-utils/` | Windows software in a Wine prefix, so it can't be declarative. Reinstalling is one command; the hand-tuned haptics profiles are the part you can't get back. |
| Quest 3 headset settings | The headset | WiVRn's client keeps its own resolution/bitrate settings on the headset. |

Not needed: the desktop's own age key (a reinstall makes a new one, and bootstrap
re-encrypts the secrets for it), `hardware-configuration.nix` (regenerated), and the YubiKey
registrations (stored encrypted in the repo; disk enrollment is redone by bootstrap).

## 1Password

The app, the `op` CLI and the Firefox extension are installed by the config, and the app
starts with Hyprland (in the tray). One-time steps in the app after signing in:

1. **Settings → Developer → "Use the SSH agent"**: your SSH keys stay in 1Password and
   ssh/git use them through `~/.1password/agent.sock` (already configured).
2. **Settings → Developer → "Integrate with 1Password CLI"**: `op` and Walker unlock
   through the app instead of asking for your password.
3. **Commit signing:** create an SSH key in 1Password (or use your existing one), add it to
   GitHub as both an *authentication* and a *signing* key (Settings → SSH and GPG keys),
   and put its public key in `home.nix` → `sshSigningKey`. Commits then show "Verified".

In Walker, type `*` and a name to find a login and copy its password; the clipboard is
cleared after 5 seconds. Vaults searched: `config/elephant/1password.toml`.

## YubiKey

| Use | How |
|---|---|
| sudo, admin prompts | Touch the key instead of typing your password (password still works) |
| Lock screen | Press Enter on the empty field, then touch the key when it asks |
| Disk unlock at boot | Touch the key (PIN if set), or type the passphrase |
| Secrets (optional) | Opens `secrets/secrets.yaml` like your 1Password key does |

On the lock screen the touch prompt only appears once PAM is running, and PAM only
starts when you submit the field — so Enter first, on an empty field, then touch.
Typing your password works too, but with the key plugged in you wait for `pam_u2f`
to time out before the password is even checked; pull the key to skip that.

The login screen still asks for your password, because that also unlocks the keyring.
`ykman info` shows the key's state. The bootstrap registers one YubiKey. A replacement or
second key needs a manual step (passwords keep working meanwhile):
`pamu2fcfg -n -o pam://desktop -i pam://desktop` appends to `u2f_keys` in
`sops secrets/secrets.yaml`, and `sudo systemd-cryptenroll --fido2-device=auto <disk>` adds
it to the disk.

## Look & feel

- **Boot:** silent boot with the Catppuccin Plymouth splash. The boot menu is hidden;
  hold **Space** while booting to show it (for rolling back).
- **Login:** ReGreet, a graphical greeter on the wallpaper.
- **Desktop:** frosted-glass bar, launcher and notifications; gradient window borders;
  spring animations; separate wallpapers for the landscape and portrait screens.
- **Lock screen:** blurred snapshot of your desktop, big clock, frosted password field.
  Locks after 10 min idle, screens off after 15. Fullscreen games and videos pause this.
- **Terminal:** kitty with a trailing-cursor animation, zsh with the Spaceship prompt
  (see "Terminal" below).

Changing the look: edit files in `config/`, push, and comin applies it.
Reload Hyprland with `hyprctl reload`, and Waybar with `pkill waybar; waybar &`.

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

## Terminal

- **Shell:** zsh with the Spaceship prompt, autosuggestions and syntax highlighting.
  The prompt ends in 👍 when the last command succeeded and 👎 when it failed. It shows
  git status, the active Nix dev shell, and language/tool versions (node, java, kubectl,
  terraform, ...) when they apply. Settings: `config/zsh/spaceship.zsh`.
- **fzf:** Ctrl+R searches history, Ctrl+T inserts a file path, Alt+C jumps into a
  directory. Uses fd, so it respects `.gitignore`.
- **Search tools:** `rg` (ripgrep, smart-case, includes dotfiles), `fd` (find), `jq` (JSON).
- **cd = zoxide:** `cd proj` jumps to the most-used directory matching "proj";
  `cdi` picks interactively. Plain paths work as before.
- **Editor:** vim everywhere (`$EDITOR`, git, sudoedit), Catppuccin colours, persistent undo.
- **Aliases:** `ls`/`ll`/`tree` use eza, `cat` uses bat, `vi` is vim. `fastfetch` shows a system summary.
- **Git:** set up for the command line, with `gh` handling GitHub logins. Your commit email
  is a sops secret (`git_email`), so it stays out of this public repo but still comes back
  on a reinstall. Change it with `sops secrets/secrets.yaml`. GitHub's noreply address
  (Settings → Emails) keeps it private on commits too.

### Project environments (direnv + Nix dev shells)

Each project declares its tools in a `flake.nix`, with exact versions pinned in
`flake.lock`. direnv loads them when you `cd` into the project and unloads them when you
leave. Commit both files and the whole team, CI included, gets identical tools.

```sh
mkdir myapp && cd myapp && git init
devshell node        # or: java, python, go, default (empty)
node --version       # available inside the folder only
```

- Change tools: edit `packages` in `flake.nix`; direnv reloads on the next prompt.
  Find package names with `nix search nixpkgs <name>`.
- Update versions: `nix flake update`, then commit `flake.lock`.
- Other machines: `nix develop` gives the same shell without direnv.
- Templates live in `templates/` in this repo; add your own there.

`nix-ld` stays enabled for the odd prebuilt binary (VS Code extensions, npm packages with
native parts).

## AI

- **Claude Code:** `claude` (log in on first run).
- **Local models:** Ollama runs on the 5090 with CUDA and downloads `qwen3-coder:30b`
  (~19 GB) in the background after the first boot; `ollama ps` shows what's loaded.
  - `claude-local` runs Claude Code against the local model instead of Anthropic's API.
    Pick another model with `CLAUDE_LOCAL_MODEL=<name> claude-local`.
  - `ollama run qwen3-coder:30b` for a plain chat in the terminal.
  - Local models are far weaker than Claude at multi-step coding; good for offline use,
    quick questions and privacy-sensitive code.
- CUDA builds come from `cache.nixos-cuda.org` (set in `configuration.nix`), so Ollama
  doesn't have to compile on your machine.

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

## Day-to-day

- Update: `nix flake update`, commit and push `flake.lock`; comin deploys it.
- Quick local test without pushing: `sudo nixos-rebuild test --flake ~/nixos-config#desktop`
- Roll back a bad update: hold Space at boot and pick an older generation.
- Flakes only see files tracked by git, so `git add` new files before rebuilding.

## GitOps with comin

Once comin is running, the git repo is the source of truth: push to `main` and the
desktop deploys it within about a minute. Commits that fail to build are not deployed.

Changes go through pull requests (see CI below); the bootstrap's own commit is the one
exception, pushed directly because you're the repo admin. The repo is public, so
comin needs no token. Never commit plaintext secrets (passwords, tokens, SSH keys) here;
use sops (see Secrets below).

Tips:
- `comin status` shows what's deployed and what's pending.
- Try risky changes on a testing branch first (see comin's docs on testing branches).
- Updating Nvidia drivers or the kernel needs a reboot, and games may misbehave
  until you do. Avoid pushing those changes mid-session.

## CI

Every push and pull request runs [`.github/workflows/ci.yml`](.github/workflows/ci.yml),
which evaluates the full system (including home-manager) and every dev shell template.
That catches broken options, removed or renamed packages and typos, which covers nearly
everything that can go wrong in a config. It doesn't do a full build: this desktop
(Nvidia, Steam, CUDA) is too big for a free GitHub runner. Comin still refuses to deploy
anything that fails to build on the machine itself.

`main` is protected: a commit can only land there once **Evaluate NixOS config** has
passed, so comin only ever deploys checked commits. The usual flow:

```sh
git switch -c my-change
# edit, then
git commit -am "Describe the change" && git push
gh pr create --fill        # CI runs on the PR
gh pr merge --squash       # once it's green; comin deploys within a minute
```

As repo admin you can still push straight to `main` in an emergency (the rule isn't
enforced for admins), but then nothing checks the commit first.

### What a lock file PR actually changes

"flake.lock updated" says nothing about what moves, so any PR touching `flake.lock`
gets a **What changed** comment: the kernel, Nvidia and Hyprland versions before and
after, plus every package whose version differs. A PR that moves the kernel or the
Nvidia driver is labelled **needs-reboot**, since those can also interrupt a running
game when comin deploys them.

It reads versions at evaluation time ([`ci/package-versions.nix`](ci/package-versions.nix)),
so like the rest of CI it never builds. The limit of that: a package rebuilt without a
version change (a patch, a changed dependency) doesn't show up. Use `nvd diff` on the
machine itself for a true closure comparison.

## Updates (Renovate)

[`renovate.json`](renovate.json) opens update pull requests every Monday morning:

- **flake inputs:** one PR updating `flake.lock` (nixpkgs, home-manager, sops-nix, comin)
- **GitHub Actions:** one PR bumping the workflow action versions

CI evaluates each PR; merge it and comin deploys the update. The Dependency Dashboard
issue Renovate creates lists everything pending and lets you trigger a run early.
Major NixOS release bumps (e.g. `nixos-26.05` → `nixos-26.11`) stay manual: change the
branch names in `flake.nix` and read the release notes first.

Requires the Renovate GitHub App: install it from
[github.com/apps/renovate](https://github.com/apps/renovate) for `nixos-config`.

Mend (who host the app) default an account to **Silent**, which scans the repo but never
opens PRs, branches or the dashboard — it looks exactly like Renovate not running at all.
`"mode": "full"` in `renovate.json` overrides that from the repo, so the setting lives in
git rather than in the Mend portal. Job logs are at
[developer.mend.io](https://developer.mend.io) if a run needs checking.

## Secrets (sops + age)

Secrets are stored encrypted in `secrets/secrets.yaml`, so they can live in this public
repo. At boot, sops-nix decrypts them with the desktop's own key into `/run/secrets/`
(in RAM, never in the Nix store). Two keys can decrypt: yours, to edit, and the desktop's,
to use them, plus optionally your YubiKey. All set up by the bootstrap.

- Edit secrets: `sops secrets/secrets.yaml` (decrypts into vim, re-encrypts on save).
- Use a secret: add it with `sops`, then declare it in `secrets.nix`:

  ```nix
  (lib.mkIf (has "github_token") { secrets.github_token = { owner = "jlor"; }; })
  # → /run/secrets/github_token
  ```

  then point whatever needs it at that path.
- Already in use: `git_email` (rendered into a git config snippet that git includes),
  `u2f_keys` (the YubiKey registration for touch-to-sudo) and `nas_host` (the NAS
  address, see "NAS shares").
- A secret's feature switches on by itself once the key exists in the file: `secrets.nix`
  reads the key names, which sops leaves unencrypted.
- After a reinstall the desktop has a new key; bootstrap swaps it into `.sops.yaml` and
  re-encrypts the file (`sops updatekeys`). That needs your personal key, so keep it safe.

## NAS shares

Two NFS shares from the NAS appear under `~/nas`:

| Path | Share on the NAS |
|---|---|
| `~/nas/media` | `/volume1/media` |
| `~/nas/backup` | `/volume2/backup` |

They're mounted on demand by autofs (`nas.nix`): nothing is mounted until you `cd` into
one, and it unmounts again after 10 idle minutes. **Away from the home network nothing
breaks** — there's no mount to fail at boot and no unit left in a failed state. `ls ~/nas`
still lists both directories; only reaching inside one fails, after about 6 seconds
(`soft,timeo=30,retrans=2`), with an I/O error instead of a hung process.

The NAS address is the secret `nas_host`, so it's not in this public repo. autofs is used
instead of `fileSystems`/`x-systemd.automount` precisely because it reads its map at
runtime: a `fileSystems.<path>.device` would put the address in `/etc/fstab` and the
world-readable Nix store. The share paths and mount options are not secret and stay in
`nas.nix`.

Day-to-day:

```sh
ls ~/nas/media              # triggers the mount
findmnt -t nfs              # what's mounted right now
systemctl status autofs     # and journalctl -u autofs if a mount fails
```

- **Changing a share or an option:** edit `shares` / `nfsOptions` in `nas.nix`.
- **Changing the NAS address:** `sops secrets/secrets.yaml`. sops-nix re-renders the map
  and reloads autofs; a share already mounted from the old address stays until it goes
  idle (or `sudo umount ~/nas/<share>`).
- **Ownership:** the mounts use NFSv3, which passes numeric uid/gid through unchanged, so
  files owned by uid 1000 on the NAS show up as yours. The NAS also offers NFSv4, but
  without a shared idmapd domain v4 would report everything as `nobody:nobody`.

`~/nas` itself is created by autofs and holds no data of its own, so it needs no backup.

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
**that directory holds every ShakeIt profile you tune**, so back it up — see What to back up.

Two things the installer does *not* do, both per-prefix and manual:

- **Serial devices.** SimHub looks for a COM port, not a `/dev/tty*`. For each board,
  symlink it into the prefix and add the matching registry entry:
  ```sh
  cd ~/linux-simracing-utils/pfx/dosdevices && ln -s /dev/ttyUSB0 com5
  ```
  then add `"COM5"="/dev/ttyUSB0"` under `HKLM\Software\Wine\Ports` in that prefix. The
  udev rules in `simracing.nix` are what make the node openable in the first place.
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

## BIOS (ASUS X870-I)

- Enable EXPO for the DDR5-6000 kit.
- Disable Secure Boot (or set up lanzaboote later).
- Enable Resizable BAR (Above 4G Decoding + ReBAR).
- Plug both monitors into the RTX 5090, not the motherboard. The 9800X3D has a small
  integrated GPU; set the primary display to PCIe (or disable the iGPU) so the boot
  splash and login appear on the 5090's screens.
