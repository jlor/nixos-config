{ pkgs, lib, ... }:

let
  # Your SSH signing key's PUBLIC half from 1Password (starts with "ssh-ed25519 ").
  # Public keys are safe to commit (GitHub shows them at github.com/jlor.keys).
  # While null, commits aren't signed. See README → 1Password.
  sshSigningKey =  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH31O12i5Iv3UiNJ0qvIhIUXy0iINdZL5i0C9irajlX6 jlor@desktop";
in

# User-level config for jlor, managed by home-manager.
# Dotfiles live in ./config and are linked into ~/.config on every rebuild,
# so a push to the repo (deployed by comin) also updates your desktop look.
{
  home.username = "jlor";
  home.homeDirectory = "/home/jlor";

  ############################################################
  # Dotfiles
  ############################################################
  xdg.configFile = {
    "hypr/hyprland.lua".source = ./config/hypr/hyprland.lua;
    "hypr/hyprlock.conf".source = ./config/hypr/hyprlock.conf;
    "hypr/hypridle.conf".source = ./config/hypr/hypridle.conf;
    "waybar".source = ./config/waybar;
    "kitty".source = ./config/kitty;
    "mako".source = ./config/mako;
    "spaceship.zsh".source = ./config/zsh/spaceship.zsh;
    "elephant/menus".source = ./config/elephant/menus;
    "elephant/1password.toml".source = ./config/elephant/1password.toml;
  };

  # Wallpapers at a stable path, used by hyprland.lua
  home.file.".local/share/wallpapers".source = ./wallpapers;

  ############################################################
  # Look & feel: dark GTK apps, icons, cursor
  ############################################################
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme.override { color = "violet"; };
    };
    font = {
      name = "Noto Sans";
      size = 11;
    };
  };

  # GTK4 / libadwaita apps (Nautilus) follow this
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
  };

  home.pointerCursor = {
    name = "catppuccin-mocha-dark-cursors";
    package = pkgs.catppuccin-cursors.mochaDark;
    size = 24;
    gtk.enable = true;
  };

  ############################################################
  # Launcher: Walker (+ Elephant backend), like Omarchy
  ############################################################
  services.elephant = {
    enable = true;
    # Only the providers that make sense here (the package builds all by default)
    package = pkgs.elephant.override {
      enabledProviders = [
        "desktopapplications"
        "calc"
        "clipboard"
        "files"
        "symbols"
        "unicode"
        "websearch"
        "windows"
        "bluetooth"
        "runner"
        "menus"
        "providerlist"
        "1password"
      ];
    };
  };

  services.walker = {
    enable = true;
    systemd.enable = true; # runs in the background, so it opens instantly
    settings = {
      close_when_open = true;
      # Same prefixes as Omarchy
      providers.prefixes = [
        { prefix = "."; provider = "files"; }
        { prefix = ":"; provider = "symbols"; }
        { prefix = "="; provider = "calc"; }
        { prefix = "$"; provider = "clipboard"; }
        { prefix = "@"; provider = "websearch"; }
        { prefix = "+"; provider = "windows"; }
        { prefix = ">"; provider = "runner"; }
        { prefix = ";"; provider = "providerlist"; }
        { prefix = "*"; provider = "1password"; }
      ];
    };
    theme = {
      name = "catppuccin";
      style = builtins.readFile ./config/walker/style.css;
    };
  };

  # Both services' upstream modules only set Install.WantedBy = "graphical-session.target",
  # not an ordering After=/PartOf=. That's a race: elephant/walker can start before Hyprland
  # (via uwsm) imports WAYLAND_DISPLAY/DISPLAY into the systemd --user manager, baking in a
  # broken environment for their whole lifetime and breaking every app launched through them
  # (apps inherit a launcher scope's env by fork, not the manager's live environment).
  systemd.user.services.elephant.Unit = {
    After = [ "graphical-session.target" ];
    PartOf = [ "graphical-session.target" ];
  };
  systemd.user.services.walker.Unit = {
    After = [ "graphical-session.target" ];
    PartOf = [ "graphical-session.target" ];
  };

  ############################################################
  # Shell: zsh + Spaceship prompt + zoxide as `cd`
  ############################################################
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    history = {
      size = 50000;
      save = 50000;
      ignoreDups = true;
      share = true;
    };
    shellAliases = {
      ls = "eza --icons --group-directories-first";
      ll = "eza -la --icons --git --group-directories-first";
      tree = "eza --tree --icons";
      cat = "bat --paging=never --style=plain";
      vi = "vim";
    };
    initContent = ''
      # Prompt: Spaceship (settings in ~/.config/spaceship.zsh)
      source ${pkgs.spaceship-prompt}/lib/spaceship-prompt/spaceship.zsh

      # New project dev shell from a template in this repo, e.g. `devshell node`.
      # Creates flake.nix + .envrc; direnv then loads the tools whenever you cd in.
      devshell() {
        local template="''${1:-default}"
        nix flake init -t "github:jlor/nixos-config#$template" && direnv allow
      }

      # Claude Code against the local model in Ollama instead of Anthropic's API.
      # Usage: claude-local [args]   (CLAUDE_LOCAL_MODEL=... to pick another model)
      claude-local() {
        ANTHROPIC_BASE_URL=http://localhost:11434 \
        ANTHROPIC_AUTH_TOKEN=ollama \
        ANTHROPIC_API_KEY="" \
          claude --model "''${CLAUDE_LOCAL_MODEL:-qwen3-coder:30b}" "$@"
      }
    '';
  };

  programs.zoxide = {
    enable = true;
    options = [ "--cmd" "cd" ]; # `cd foo` jumps to your most-used match; `cdi` picks interactively
  };

  ############################################################
  # Editor: vim, Catppuccin colours
  ############################################################
  programs.vim = {
    enable = true;
    defaultEditor = true; # EDITOR/VISUAL=vim (git commits, sudoedit, ...)
    plugins = with pkgs.vimPlugins; [
      catppuccin-vim
      vim-sensible
    ];
    settings = {
      number = true;
      relativenumber = true;
      expandtab = true;
      shiftwidth = 4;
      tabstop = 4;
      ignorecase = true;
      smartcase = true;
      mouse = "a";
    };
    extraConfig = ''
      set termguicolors
      colorscheme catppuccin_mocha
      set cursorline
      set scrolloff=5
      set undofile undodir=~/.vim/undo//
      call mkdir(expand('~/.vim/undo'), 'p')
    '';
  };

  ############################################################
  # Git (CLI) + GitHub CLI
  ############################################################
  programs.git = {
    enable = true;
    settings = {
      user.name = "jlor";
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      rebase.autoStash = true;
      diff.colorMoved = "default";
      core.editor = "vim";
    };
    # Your email lives encrypted in secrets/secrets.yaml (git_email); sops-nix renders
    # it to this file at boot (see secrets.nix). Change it with `sops secrets/secrets.yaml`.
    includes = [ { path = "/run/secrets/rendered/git-identity"; } ];

    # Sign commits with your SSH key in 1Password (shows "Verified" on GitHub).
    # 1Password asks for approval (system password or YubiKey) when signing.
    signing = lib.mkIf (sshSigningKey != null) {
      format = "ssh";
      key = sshSigningKey;
      signer = "${pkgs._1password-gui}/bin/op-ssh-sign";
      signByDefault = true;
    };
  };

  # SSH keys live in 1Password; its agent serves them to ssh and git.
  # Turn the agent on once in the app: Settings → Developer → Use the SSH agent.
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*".IdentityAgent = "~/.1password/agent.sock";
  };
  home.sessionVariables.SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";

  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true; # `gh auth login` also handles git push/pull auth
    settings.git_protocol = "https";
  };

  ############################################################
  # Project environments: direnv + Nix dev shells (replaces asdf)
  ############################################################
  # Each project gets a flake.nix with its tool versions (`devshell node` creates one).
  # direnv loads it on `cd` and unloads it when you leave. nix-direnv caches it.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    config.global = {
      hide_env_diff = true; # no wall of exported variables on cd
      warn_timeout = "30s";
    };
  };

  ############################################################
  # Search & data tools
  ############################################################
  programs.fzf = {
    enable = true; # Ctrl+R history, Ctrl+T files, Alt+C directories
    defaultCommand = "fd --type f --hidden --exclude .git";
    fileWidgetCommand = "fd --type f --hidden --exclude .git";
    changeDirWidgetCommand = "fd --type d --hidden --exclude .git";
    defaultOptions = [
      "--height=40%"
      "--layout=reverse"
      "--border=rounded"
      # Catppuccin Mocha
      "--color=bg+:#313244,bg:-1,spinner:#f5e0dc,hl:#f38ba8"
      "--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc"
      "--color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
      "--color=selected-bg:#45475a,border:#6c7086,label:#cdd6f4"
    ];
  };

  programs.ripgrep = {
    enable = true;
    arguments = [ "--smart-case" "--hidden" "--glob=!.git/*" ];
  };

  programs.fd.enable = true;
  programs.jq.enable = true;

  # Video player. gpu-next + Vulkan is the native Wayland path (no XWayland);
  # hwdec picks up nvidia-vaapi-driver from configuration.nix.
  # URLs work out of the box: pkgs.mpv is built with youtubeSupport, which puts
  # yt-dlp on mpv's fallback PATH.
  programs.mpv = {
    enable = true;
    config = {
      vo = "gpu-next";
      gpu-api = "vulkan";
      hwdec = "auto-safe";
      keep-open = "yes";
      save-position-on-quit = true;
      ytdl-format = "bestvideo[height<=?1440]+bestaudio/best";
    };
  };

  home.packages = with pkgs; [
    eza
    bat
    fastfetch

    # Secrets (see secrets.nix)
    sops
    age

    # AI
    claude-code
  ];

  # Leave at the release you first installed.
  home.stateVersion = "26.05";
}
