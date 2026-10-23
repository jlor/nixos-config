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
    "satty/config.toml".source = ./config/satty/config.toml;
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
    # Emacs line editing (Ctrl+A/E/K/U/W, Alt+B/F). Without this zsh picks the
    # keymap itself, and its rule is "vi keymap if $EDITOR or $VISUAL contains
    # 'vi'" — which vim does, so the vim-as-editor setting above silently put
    # the command line in vi insert mode, where Ctrl+A and Ctrl+E are unbound.
    defaultKeymap = "emacs";
    # A bare directory name cds into it: `..`, `Downloads`, `/etc`. Without this,
    # zsh treats `..` as a path, tries to *execute* the directory and reports the
    # resulting EACCES as "permission denied" — confusing, and unrelated to the
    # "command not found" you get for any other directory name.
    autocd = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    # compinit is the single biggest cost in zsh startup: run plainly it re-scans
    # every directory in $fpath for insecure permissions on every new shell.
    # Rebuild the dump at most once a day and load the cached one otherwise
    # (-C skips the scan). Filename generation happens in array assignment but
    # not inside [[ ]], hence the array: it's empty when the dump is missing or
    # older than 24h (N = no error if absent, . = regular file, mh-24 = younger
    # than 24 hours).
    completionInit = ''
      autoload -Uz compinit
      _zcompdump=''${ZDOTDIR:-$HOME}/.zcompdump
      _zcompdump_fresh=($_zcompdump(N.mh-24))
      if (( $#_zcompdump_fresh )); then
        compinit -C -d $_zcompdump
      else
        compinit -d $_zcompdump
        # compinit only rewrites the dump when the set of completion functions
        # actually changed, so its mtime can sit unchanged for weeks. Without
        # this touch the check above never goes true again and every shell takes
        # the slow path — the cache would silently never engage.
        touch $_zcompdump
      fi
      unset _zcompdump _zcompdump_fresh
    '';

    # Type a prefix, then Up/Down walks only the history lines starting with it.
    # Distinct from fzf's Ctrl+R: this keeps your hands on the arrow keys.
    plugins = [
      {
        name = "history-substring-search";
        src = pkgs.zsh-history-substring-search;
        file = "share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh";
      }
    ];

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

      ############################################################
      # Where a "word" ends (Ctrl+W, Alt+B/F, Ctrl+Left/Right)
      ############################################################
      # These widgets treat alphanumerics plus every character in $WORDCHARS as
      # part of a word. zsh's default $WORDCHARS contains "/", so at the end of
      #   scp dev:/opt/k8s-migration/README.md
      # Ctrl+W swallows the whole path back to the ":" — the first character
      # that happens not to be in the list. Dropping "/" makes a path separator
      # end a word, so Ctrl+W deletes one segment at a time (README.md, then
      # /k8s-migration, then /opt). Derived from the default rather than spelled
      # out, so the rest of the list stays whatever zsh ships.
      WORDCHARS=''${WORDCHARS//\/}

      ############################################################
      # Keys bare zsh leaves unbound
      ############################################################
      # `bindkey -e` covers Alt+B/F and Ctrl+W/K/U, but not these: without them
      # Home, End, Delete and Ctrl+arrows do nothing at all. oh-my-zsh binds them
      # in lib/key-bindings.zsh, which is why they work on an OMZ machine.
      # Terminals disagree about normal vs application cursor mode, so bind both
      # forms of each key rather than relying on one.
      bindkey '^[[H'    beginning-of-line     # Home
      bindkey '^[OH'    beginning-of-line
      bindkey '^[[1~'   beginning-of-line
      bindkey '^[[7~'   beginning-of-line
      bindkey '^[[F'    end-of-line           # End
      bindkey '^[OF'    end-of-line
      bindkey '^[[4~'   end-of-line
      bindkey '^[[8~'   end-of-line
      bindkey '^[[3~'   delete-char           # Delete
      bindkey '^[[1;5D' backward-word         # Ctrl+Left
      bindkey '^[[1;5C' forward-word          # Ctrl+Right
      bindkey '^[[1;3D' backward-word         # Alt+Left
      bindkey '^[[1;3C' forward-word          # Alt+Right
      bindkey '^[[3;5~' kill-word             # Ctrl+Delete

      # Substring-filtered history on Up/Down (zsh-history-substring-search,
      # loaded above by programs.zsh.plugins). Bound here so it wins over the
      # plain up-line-or-history the emacs keymap installs.
      # Trade-off: Up no longer moves between the lines of a multi-line command,
      # because this widget always searches history. Ctrl+P / Ctrl+N keep the
      # old up-line-or-history behaviour, which does move within the buffer
      # first — use those when editing a multi-line command.
      bindkey '^[[A' history-substring-search-up
      bindkey '^[[B' history-substring-search-down
      bindkey '^[OA' history-substring-search-up
      bindkey '^[OB' history-substring-search-down

      ############################################################
      # Completion behaviour (oh-my-zsh's lib/completion.zsh)
      ############################################################
      zmodload zsh/complist
      zstyle ':completion:*' menu select
      # Case-insensitive first, then partial-word: `cd dow`<Tab> finds Downloads,
      # `cd u/s/f`<Tab> finds usr/share/fonts.
      zstyle ':completion:*' matcher-list 'm:{a-zA-Z-_}={A-Za-z_-}' 'r:|=*' 'l:|=* r:|=*'
      zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
      zstyle ':completion:*' group-name ""
      zstyle ':completion:*:descriptions' format '%F{magenta}-- %d --%f'
      zstyle ':completion:*' special-dirs true   # offer ./ and ../
      zstyle ':completion:*' use-cache on
      zstyle ':completion:*' cache-path ''${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache

      ############################################################
      # Directory stack (oh-my-zsh's lib/directories.zsh)
      ############################################################
      # Every cd pushes onto the stack, so `-` bounces back to where you just
      # were — the one thing zoxide doesn't give you, since it jumps by frecency
      # rather than by history. zoxide's cd wrapper passes `-` and `-<n>` through
      # to builtin cd untouched, so these work through it.
      setopt AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT PUSHD_MINUS
      alias d='dirs -v | head -10'
      alias -- -='cd -'
      for index in {1..9}; do alias "$index"="cd -$index"; done
      unset index

      ############################################################
      # Small comforts
      ############################################################
      setopt INTERACTIVE_COMMENTS   # `#` starts a comment at the prompt too

      # Colored man pages (oh-my-zsh's colored-man-pages plugin). less renders
      # bold/underline through these termcap hooks; without them man is monochrome.
      export LESS_TERMCAP_mb=$'\e[1;31m'    # blink  -> red
      export LESS_TERMCAP_md=$'\e[1;35m'    # bold   -> mauve-ish
      export LESS_TERMCAP_me=$'\e[0m'
      export LESS_TERMCAP_so=$'\e[1;44;37m' # search highlight
      export LESS_TERMCAP_se=$'\e[0m'
      export LESS_TERMCAP_us=$'\e[1;36m'    # underline -> cyan
      export LESS_TERMCAP_ue=$'\e[0m'

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
    # npx, for the MCP servers in ~/.mcp.json that are published as npm packages
    # and launched with `npx --yes <pkg>@<version>` (each pins its own version).
    nodejs
  ];

  # Leave at the release you first installed.
  home.stateVersion = "26.05";
}
