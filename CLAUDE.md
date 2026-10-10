# CLAUDE.md

NixOS flake for jlor's desktop (hostname `desktop`): Ryzen 7 9800X3D, RTX 5090,
two monitors (DP-1 landscape primary left, DP-2 portrait right). README.md is the
user-facing guide; this file is for working on the repo.

## Guiding principle: reproducibility
A reinstall must get back to the known state with: install NixOS, run
`nix run github:jlor/nixos-config#bootstrap`, restore the backed-up keys. Nothing else. So:
- Every setting lives in this repo, declaratively. If something can only be done by
  hand, it goes in bootstrap.sh or the README's install steps, and is a sign to look
  for a declarative option first.
- No imperative installs or tweaks: no `nix profile install`, `nix-env`, `npm -g`,
  `curl | sh`, or settings clicked in a GUI and never written down. If an app needs
  config, set it from home.nix or configuration.nix.
- Everything is pinned: flake.lock is committed; project dev shells lock their own.
- State that can't live in git (keys, app data) must be listed under "What to back
  up" in the README.
- When proposing a change, say whether it creates state outside the repo.

## How changes reach the machine
- Merging to `main` deploys automatically: comin on the desktop pulls `main` and
  switches within a minute. Treat every merge as a production deploy.
- `main` is protected: the "Evaluate NixOS config" CI check must pass. Work on a
  branch and open a PR; never push to `main` directly.
- Kernel and Nvidia driver changes need a reboot and can break a running game.
  Call that out in the PR description.

## Verify before proposing
- Check options and package names against nixpkgs `nixos-26.05` and home-manager
  `release-26.05` source, not memory. Packages get removed and renamed between
  releases (e.g. `wasistlos` → `karere`, `xorg.xrandr` → `xrandr`).
- Evaluate locally before pushing:
  `nix eval .#nixosConfigurations.desktop.config.system.build.toplevel.drvPath`
  (needs a hardware-configuration.nix; CI copies `ci/hardware-configuration.nix`).
- New files must be `git add`ed or the flake won't see them.
- CI only evaluates, it doesn't build. Mention anything that could fail at build
  or runtime only.
- bootstrap.sh is wrapped by `writeShellApplication`: it must pass shellcheck, and
  it must stay idempotent (safe to re-run on a configured machine).

## Gotchas
- Hyprland 0.55 uses a Lua config (`config/hypr/hyprland.lua`, `hl.*` API), not
  hyprland.conf syntax. hyprlock and hypridle still use the .conf format.
- Public repo: no secrets, tokens, emails or other personal data in plain text.
  Secrets go through sops (`secrets.nix`, `secrets/secrets.yaml`). Declare each secret
  behind `has "<name>"` in secrets.nix, and have other modules check
  `config.sops.secrets ? <name>`, so the config evaluates before the secret exists.
- pam_u2f uses a fixed origin `pam://desktop` (security.nix and bootstrap.sh must match);
  changing it invalidates the registered YubiKey.
- Hardware/secret-dependent features must degrade gracefully: no YubiKey or no secret
  yet means falling back to passwords, never a lockout.
- Never edit `hardware-configuration.nix` or `flake.lock` by hand; they're
  generated (bootstrap writes the first, Renovate updates the second weekly).
- `system.stateVersion` and `home.stateVersion` stay at "26.05" forever.

## Layout
- `configuration.nix`: system (drivers, boot, login, services, system packages)
- `home.nix`: user jlor via home-manager; links dotfiles from `config/`
- `secrets.nix`: sops-nix; `security.nix`: 1Password, YubiKey, PAM, hyprlock
- `bootstrap.sh`: the `#bootstrap` app
- `templates/`: project dev shells; `ci/`: CI-only files

## Preferences
- Terminal first: zsh + Spaceship prompt, vim (not neovim), git CLI, zoxide as cd.
- Dark mode everywhere; Catppuccin Mocha with a mauve accent. New UI must match.
- Project tools come from Nix dev shells + direnv, not global installs or asdf.
- Prefer declarative Nix options over imperative setup steps or scripts.
- Suggest additions before adding them; don't add unrequested tools.
- Commits: imperative subject line, body explaining why.
