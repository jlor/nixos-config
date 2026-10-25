# Terminal

kitty, zsh and the per-project tooling. Configured in `home.nix` and
`config/zsh/spaceship.zsh`.

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

## Project environments (direnv + Nix dev shells)

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
- Templates live in `templates/` in this repo; add your own there. Each ships its own
  `flake.lock`, so a new project starts on a known nixpkgs rather than whatever
  `nixos-unstable` happens to be that day — `nix flake update` moves it forward.

`nix-ld` stays enabled for the odd prebuilt binary (VS Code extensions, npm packages with
native parts).

### mise, for template-generated projects

`mise` is installed as the one deliberate exception to the rule above. A few projects
are generated from an upstream template that pins its own toolchain in a committed
`.mise/config.toml` and drives its task runner and environment variables from it.
Re-pinning those tools in a flake here would create a second source of truth that
drifts from what the upstream recipes expect, so Nix provides mise and mise provides
those projects' tools.

Shell integration is **off**, so mise does nothing until you ask it to:

```sh
cd <project>
mise install            # first run, or after a .mise/config.toml change
mise exec -- <tool> ...
```

Calling a tool directly is meant to fail — nothing is added to `PATH`, so mise can't
shadow a nixpkgs binary or race direnv's hook. Projects without their own mise config
should use a dev shell instead.

Two global settings are set for it in `home.nix`, both needed on NixOS specifically:
`node.compile = false`, because mise otherwise builds node from source and that needs a
`python` this system doesn't have (prebuilt node runs fine under nix-ld); and
`experimental = true`, which is what lets a project's own `[hooks]` run — without it
mise skips them with a warning and a fresh clone quietly has no pre-commit formatting.

One manual step per working copy remains: mise refuses a config it hasn't been told to
trust, and that trust is keyed on the absolute path, so it does not survive moving a
checkout. Run `mise trust` once in the project, then `mise install`.
