{ config, lib, pkgs, ... }:

let
  username = "jlor";
in
{
  ############################################################
  # Boot & kernel
  ############################################################
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  # 26.05 ships Linux 6.18 LTS by default, which covers the 9800X3D,
  # X870 chipset and the MediaTek Wi-Fi 7 card on the Strix X870-I.
  # Uncomment for the newest kernel (Nvidia modules can lag behind it):
  # boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.kernelParams = [
    "amd_pstate=active"   # modern AMD CPU frequency driver
    # Silent boot: splash screen instead of scrolling text
    "quiet"
    "splash"
    "boot.shell_on_fail"
    "udev.log_priority=3"
    "rd.systemd.show_status=auto"
  ];

  ############################################################
  # Boot splash (Plymouth, Catppuccin Mocha)
  ############################################################
  boot.plymouth = {
    enable = true;
    theme = "catppuccin-mocha";
    themePackages = [ (pkgs.catppuccin-plymouth.override { variant = "mocha"; }) ];
  };
  boot.consoleLogLevel = 3;
  boot.initrd.verbose = false;
  # Load the Nvidia driver early so the splash shows in full resolution
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
  # Hide the boot menu; hold Space while booting to show it (for rollbacks)
  boot.loader.timeout = 0;

  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  ############################################################
  # NVIDIA RTX 5090 (Blackwell -> open kernel modules required)
  ############################################################
  hardware.graphics = {
    enable = true;
    enable32Bit = true;           # needed by Steam / Proton / Wine
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    open = true;                  # mandatory for RTX 50-series
    modesetting.enable = true;    # required for Wayland
    powerManagement.enable = true; # saves VRAM across suspend/resume
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    # If you hit a driver bug, try: nvidiaPackages.beta
  };

  ############################################################
  # Desktop: Hyprland (tiling Wayland compositor)
  ############################################################
  programs.hyprland = {
    enable = true;
    withUWSM = true;        # proper systemd session management
    xwayland.enable = true; # for Battle.net, Steam and other X11 apps
  };

  # Graphical login screen (ReGreet on greetd), themed to match
  # The login screen's compositor (cage) knows nothing about the monitor layout: it
  # spans both screens and centres the login box across the join. Switch the
  # portrait screen (HDMI-A-1) off while logging in, so the box sits on the main one.
  services.greetd.settings.default_session.command =
    let
      regreetOnMainScreen = pkgs.writeShellScript "regreet-main-screen" ''
        ${pkgs.wlr-randr}/bin/wlr-randr --output HDMI-A-1 --off || true
        exec ${lib.getExe config.programs.regreet.package}
      '';
    in
    "${pkgs.dbus}/bin/dbus-run-session ${lib.getExe pkgs.cage} -s -- ${regreetOnMainScreen}";

  programs.regreet = {
    enable = true;
    settings = {
      background = {
        path = ./wallpapers/wallpaper-landscape.jpg;
        fit = "Cover";
      };
      GTK.application_prefer_dark_theme = true;
    };
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme.override { color = "violet"; };
    };
    cursorTheme = {
      name = "catppuccin-mocha-dark-cursors";
      package = pkgs.catppuccin-cursors.mochaDark;
    };
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 14;
      package = pkgs.nerd-fonts.jetbrains-mono;
    };
  };

  programs.dconf.enable = true;   # lets home-manager set dark-mode preferences

  # Keyring so VS Code, gh and Discord can store logins
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;
  security.polkit.enable = true;

  # Hyprland's portal is added automatically; GTK one handles file pickers
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";                   # Electron apps native on Wayland
    LIBVA_DRIVER_NAME = "nvidia";           # hardware video decoding
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    NVD_BACKEND = "direct";
  };

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
  ];

  services.gvfs.enable = true;     # trash, USB drives in file manager
  services.udisks2.enable = true;

  ############################################################
  # Locale (Denmark)
  ############################################################
  time.timeZone = "Europe/Copenhagen";
  i18n.defaultLocale = "en_US.UTF-8";      # English UI…
  i18n.extraLocaleSettings = {
    LC_TIME = "da_DK.UTF-8";               # …Danish dates, numbers, currency
    LC_NUMERIC = "da_DK.UTF-8";
    LC_MONETARY = "da_DK.UTF-8";
    LC_MEASUREMENT = "da_DK.UTF-8";
    LC_PAPER = "da_DK.UTF-8";
  };
  services.xserver.xkb = {
    layout = "dk";
    options = "ctrl:nocaps";   # Caps Lock acts as Ctrl
  };
  console.useXkbConfig = true; # same layout + Caps->Ctrl on the login screen/TTY
  # Catppuccin Mocha colours for the text console too
  console.colors = [
    "1e1e2e" "f38ba8" "a6e3a1" "f9e2af" "89b4fa" "f5c2e7" "94e2d5" "bac2de"
    "585b70" "f38ba8" "a6e3a1" "f9e2af" "89b4fa" "f5c2e7" "94e2d5" "a6adc8"
  ];

  ############################################################
  # Networking, audio, bluetooth
  ############################################################
  networking.hostName = "desktop";
  networking.networkmanager.enable = true;

  security.rtkit.enable = true;
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  # Bluetooth manager (Waybar's Bluetooth icon opens it). Enabled as a service, not
  # just a package: its system helper is what applies pairings and settings.
  services.blueman.enable = true;

  services.printing.enable = true;
  services.fstrim.enable = true;           # SSD trim for the T700
  zramSwap.enable = true;

  ############################################################
  # Gaming
  ############################################################
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    gamescopeSession.enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };
  programs.gamemode.enable = true;         # launch option: gamemoderun %command%
  programs.gamescope.enable = true;

  ############################################################
  # Apps
  ############################################################
  nixpkgs.config.allowUnfree = true;       # Nvidia, Steam, VS Code, Discord

  programs.firefox.enable = true;
  programs.git.enable = true;              # system-wide git (your settings: home.nix)

  # zsh is the login shell (configured per user in home.nix)
  programs.zsh.enable = true;

  # vim as the system editor too (root, sudoedit)
  programs.vim = {
    enable = true;
    defaultEditor = true;
  };

  # Lets prebuilt Linux binaries run on NixOS: VS Code extensions, npm packages
  # with native parts, tools downloaded outside Nix. Project tools themselves
  # come from Nix dev shells (see home.nix / templates/).
  programs.nix-ld.enable = true;

  ############################################################
  # Local AI: Ollama on the RTX 5090 (CUDA)
  ############################################################
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    environmentVariables = {
      OLLAMA_CONTEXT_LENGTH = "65536";     # Claude Code needs a long context
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_KV_CACHE_TYPE = "q8_0";       # halves context memory, fits 64k in VRAM
    };
    # Pulled in the background after boot (~19 GB, once). Fits the 5090's 32 GB VRAM.
    loadModels = [ "qwen3-coder:30b" ];
  };

  environment.systemPackages = with pkgs; [
    # Gaming
    lutris          # install Battle.net through this
    mangohud        # FPS overlay: mangohud %command%
    protonup-qt

    # Development (git, gh, vim, direnv, fzf, Claude Code etc. are set up per user in home.nix)
    vscode
    nixd            # Nix language server for VS Code
    nixfmt

    # Communication
    discord
    # WhatsApp desktop client. Replaces karere (which replaced wasistlos):
    # karere's WebKitGTK backend aborted its whole web process on any <audio>
    # element because nixpkgs ships it without GStreamer plugins, so every
    # notification sound was a crash loop. zapzap is QtWebEngine, which bundles
    # its own audio stack and can't hit that class of bug.
    zapzap

    # Hyprland essentials
    kitty                 # terminal
    waybar                # status bar
    mako                  # notifications
    swaybg                # wallpaper (per monitor)
    hypridle              # idle -> lock
    hyprpolkitagent       # password prompts for GUI apps
    grim slurp wl-clipboard   # screenshots + clipboard (Walker keeps the history)
    libnotify             # notify-send, used by the screenshot keys
    brightnessctl playerctl
    pavucontrol           # audio settings
    networkmanagerapplet  # wifi tray icon
    nautilus              # file manager
    nvidia-vaapi-driver
    xrandr                # sets primary monitor for XWayland games

    # Utilities
    wget
    curl
    htop
    btop
    nvtopPackages.nvidia
    pciutils
    usbutils
  ];

  ############################################################
  # User
  ############################################################
  users.users.${username} = {
    isNormalUser = true;
    description = username;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "networkmanager" "gamemode" ];
  };

  ############################################################
  # Nix itself
  ############################################################
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    # Prebuilt CUDA packages (Ollama). The default cache doesn't carry CUDA,
    # so without this they compile from source for hours.
    substituters = [ "https://cache.nixos-cuda.org" ];
    trusted-public-keys = [ "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M=" ];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Leave this at the release you first installed. Don't bump it on upgrades.
  system.stateVersion = "26.05";
}
