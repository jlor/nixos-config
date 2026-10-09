{ pkgs, ... }:

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
  # Shell: bash + starship prompt + nicer CLI tools
  ############################################################
  programs.bash = {
    enable = true;
    shellAliases = {
      ls = "eza --icons --group-directories-first";
      ll = "eza -la --icons --git --group-directories-first";
      tree = "eza --tree --icons";
      cat = "bat --paging=never --style=plain";
    };
  };

  programs.starship = {
    enable = true;
    settings = builtins.fromTOML (builtins.readFile ./config/starship.toml);
  };

  home.packages = with pkgs; [
    eza
    bat
    fastfetch
  ];

  # Leave at the release you first installed.
  home.stateVersion = "26.05";
}
