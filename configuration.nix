{ config, lib, pkgs, unstableNixpkgs, ... }:

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

  # 26.05's default kernel is 6.18, which predates the onboard MediaTek MT7927
  # Wi-Fi 7 + BT 5.4 card: BT support merged in 7.1, Wi-Fi in 7.2. With no
  # driver for the PCIe side, the chip never configures the MT6639 BT
  # controller, so without this there is no Wi-Fi interface and no Bluetooth
  # adapter at all. Pin the 7.2 series from the pinned nixpkgs-unstable flake
  # input: only the kernel and its module tree (incl. the Nvidia modules
  # below, which come from the same kernel set) move; everything else stays on
  # 26.05. Drop this pin (and the flake input) when moving to 26.11, whose
  # default kernel is >= 7.2.
  boot.kernelPackages = unstableNixpkgs.linuxKernel.packages.linux_7_2;

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
  # Firefox is autostarted at login (config/hypr/hyprland.lua), so it needs to come
  # back with the previous session's windows and tabs rather than a blank start page.
  # This sets browser.startup.page as a default, not a locked value, so the setting
  # in Settings -> General -> Startup still works if you want to change it.
  programs.firefox.policies.Homepage.StartPage = "previous-session";
  # Extensions, installed and kept up to date by Firefox itself from the policy
  # below rather than clicked in from addons.mozilla.org, so a reinstall gets them
  # back. The attribute name is the add-on's ID; 1Password adds its own in
  # security.nix. force_installed means they can't be removed from about:addons —
  # the point is that they're part of the config — but they can still be disabled
  # per-site from their toolbar button.
  programs.firefox.policies.ExtensionSettings = {
    "uBlock0@raymondhill.net" = {                 # uBlock Origin: ad and tracker blocking
      installation_mode = "force_installed";
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
    };
    "sponsorBlocker@ajay.app" = {                 # SponsorBlock: skip YouTube sponsor segments
      installation_mode = "force_installed";
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/sponsorblock/latest.xpi";
    };
  };
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

  # Local AI (NInfer on the RTX 5090) lives in ai.nix.

  environment.systemPackages = with pkgs; [
    # Gaming
    lutris          # install Battle.net through this
    mangohud        # FPS overlay: mangohud %command%
    protonup-qt
    # The two things the SimHub installer wants from the system (see
    # docs/gaming.md). It checks for winetricks up front and stops without it,
    # then reaches for unzip part way through, to unpack SimHub itself.
    #
    # Deliberately not paired with pkgs.wine: that installer builds and manages
    # its own Wine under ~/linux-simracing-utils/bin, newer than the one in
    # nixpkgs, and a second wine on PATH is only a chance to use the wrong one.
    # nixpkgs' winetricks doesn't bundle Wine either, so it picks up whichever
    # is on PATH. Everything else it needs it fetches itself: patchelf and the
    # loader come from its own pinned nixpkgs, and the desktop-menu tools it
    # touches at the end are all behind `command -v` guards.
    winetricks
    unzip

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
    wl-clipboard          # wl-copy/wl-paste (Walker keeps the history)
    hyprshot               # screenshot by region / window / monitor; brings its own grim+slurp
    satty                  # annotate a screenshot before sharing it
    libnotify             # notify-send, for ad-hoc use
    brightnessctl playerctl
    pavucontrol           # audio settings
    networkmanagerapplet  # wifi tray icon
    nautilus              # file manager
    nvidia-vaapi-driver
    xrandr                # sets primary monitor for XWayland games

    # Utilities
    curl
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
    # uinput: lets Boxflat publish the Moza base's stalk switches as a virtual
    # joystick (see simracing.nix). Boxflat's own udev rule does tag /dev/uinput
    # with uaccess and logind does honour that, so this group is a backstop for
    # the case where there is no seat to get an ACL from.
    extraGroups = [ "wheel" "networkmanager" "gamemode" "uinput" ];
  };

  ############################################################
  # Nix itself
  ############################################################
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    # Prebuilt CUDA packages (the toolkit NInfer builds against). The default
    # cache doesn't carry CUDA, so without this it compiles from source for
    # hours. NInfer itself has no cache and is always built locally; see
    # docs/ai.md.
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
