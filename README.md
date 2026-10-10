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
| `config/kitty/`, `config/mako/` | Terminal, notifications |
| `config/walker/`, `config/elephant/` | Launcher theme, power menu |
| `config/zsh/spaceship.zsh` | Shell prompt (Spaceship) |
| `templates/` | Project dev shells (`devshell node` etc.) |
| `secrets.nix`, `.sops.yaml`, `secrets/` | Encrypted secrets (sops + age) |
| `.github/workflows/ci.yml`, `ci/` | CI: checks every push and pull request |
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
- **Git:** set up for the command line, with `gh` handling GitHub logins. Your email is kept
  out of this public repo, so set it once after install:
  `git config --file ~/.config/git/local user.email "you@example.com"`
  (GitHub's noreply address from Settings → Emails keeps it private on commits too.)

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
| Super + J | Toggle split direction |
| Super + arrows / H / K | Move focus |
| Super + Shift + arrows | Move window |
| Super + 1–9 | Switch workspace (1–5 left screen, 6–9 right) |
| Super + Shift + 1–9 | Move window to workspace |
| Super + S | Scratchpad (Shift: send window there) |
| Super + C | Clipboard history |
| Super + Ctrl + E | Emoji & symbols |
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

## CI

Every push and pull request runs [`.github/workflows/ci.yml`](.github/workflows/ci.yml),
which evaluates the full system (including home-manager) and every dev shell template.
That catches broken options, removed or renamed packages and typos, which covers nearly
everything that can go wrong in a config. It doesn't do a full build: this desktop
(Nvidia, Steam, CUDA) is too big for a free GitHub runner. Comin still refuses to deploy
anything that fails to build on the machine itself.

To make sure only checked commits reach the desktop, work on a branch and merge through a
pull request, then require the check: Settings → Branches → add a rule for `main` →
"Require status checks to pass" → select **Evaluate NixOS config**.

## Secrets (sops + age)

Secrets are stored encrypted in `secrets/secrets.yaml`, so they can live in this public
repo. At boot, sops-nix decrypts them with the desktop's own key into `/run/secrets/`
(in RAM, never in the Nix store). Two keys can decrypt: yours, to edit, and the desktop's,
to use them.

One-time setup, after the first rebuild on the PC:

```sh
# 1. Your personal key (back it up, e.g. in your password manager)
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt        # prints your public key

# 2. The desktop's key, generated automatically on first boot
sudo age-keygen -y /var/lib/sops-nix/key.txt     # prints its public key

# 3. Put both public keys (age1...) into .sops.yaml, then create the secrets file
cd ~/nixos-config
sops secrets/secrets.yaml                          # opens vim; add e.g.  github_token: abc123
git add .sops.yaml secrets/secrets.yaml && git commit -m "Add secrets" && git push
```

Use a secret by declaring it in `secrets.nix`:

```nix
sops.secrets.github_token = { owner = "jlor"; };   # → /run/secrets/github_token
```

Then point whatever needs it at that path. Edit secrets any time with
`sops secrets/secrets.yaml`. If you reinstall the PC, the desktop gets a new key: put its
new public key in `.sops.yaml` and run `sops updatekeys secrets/secrets.yaml`.

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
