{ pkgs, lib, ... }:

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
    "fuzzel".source = ./config/fuzzel;
    "mako".source = ./config/mako;
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
  # Shell: zsh + Powerlevel10k (lean) + zoxide as `cd`
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
    initContent = lib.mkMerge [
      # Powerlevel10k instant prompt: must stay at the very top of .zshrc
      (lib.mkBefore ''
        if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
        fi
      '')
      ''
        # Prompt
        source ${pkgs.zsh-powerlevel10k}/share/zsh/themes/powerlevel10k/powerlevel10k.zsh-theme
        [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

        # asdf: version shims for java, nodejs, ... (per project via .tool-versions)
        export ASDF_DATA_DIR="$HOME/.asdf"
        path=("$ASDF_DATA_DIR/shims" $path)

        # Claude Code against the local model in Ollama instead of Anthropic's API.
        # Usage: claude-local [args]   (CLAUDE_LOCAL_MODEL=... to pick another model)
        claude-local() {
          ANTHROPIC_BASE_URL=http://localhost:11434 \
          ANTHROPIC_AUTH_TOKEN=ollama \
          ANTHROPIC_API_KEY="" \
            claude --model "''${CLAUDE_LOCAL_MODEL:-qwen3-coder:30b}" "$@"
        }
      ''
    ];
  };

  home.file.".p10k.zsh".source = ./config/p10k.zsh;

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
    # Your email is kept out of this public repo. Set it once with:
    #   git config --file ~/.config/git/local user.email "you@example.com"
    includes = [ { path = "~/.config/git/local"; } ];
  };

  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true; # `gh auth login` also handles git push/pull auth
    settings.git_protocol = "https";
  };

  home.packages = with pkgs; [
    eza
    bat
    fastfetch

    # asdf + what its plugins (nodejs, java, ...) need to download and unpack
    asdf-vm
    unzip
    jq

    # AI
    claude-code
  ];

  # Leave at the release you first installed.
  home.stateVersion = "26.05";
}
