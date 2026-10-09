{ config, pkgs, ... }:

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
  ];

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

  # Minimal login screen that starts Hyprland
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd 'uwsm start hyprland-uwsm.desktop'";
      user = "greeter";
    };
  };

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
  programs.git.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;              # per-project dev shells
  };

  environment.systemPackages = with pkgs; [
    # Gaming
    lutris          # install Battle.net through this
    mangohud        # FPS overlay: mangohud %command%
    protonup-qt

    # Development
    gh
    vscode
    nixd            # Nix language server for VS Code
    nixfmt-rfc-style

    # Communication
    discord
    wasistlos       # WhatsApp desktop client (formerly whatsapp-for-linux)

    # Hyprland essentials
    kitty                 # terminal
    waybar                # status bar
    fuzzel                # app launcher
    mako                  # notifications
    hyprpaper             # wallpaper
    hyprlock              # lock screen
    hypridle              # idle -> lock
    hyprpolkitagent       # password prompts for GUI apps
    grim slurp wl-clipboard   # screenshots + clipboard
    cliphist
    brightnessctl playerctl
    pavucontrol           # audio settings
    networkmanagerapplet  # wifi tray icon
    blueman               # bluetooth GUI
    nautilus              # file manager
    nvidia-vaapi-driver
    xorg.xrandr           # sets primary monitor for XWayland games

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
    extraGroups = [ "wheel" "networkmanager" "gamemode" ];
  };

  ############################################################
  # Nix itself
  ############################################################
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Leave this at the release you first installed. Don't bump it on upgrades.
  system.stateVersion = "26.05";
}
