{ config, lib, pkgs, ... }:

# 1Password and YubiKey.
#
# - 1Password: desktop app + `op` CLI, system-auth unlock, SSH agent (home.nix),
#   Firefox extension.
# - YubiKey: touch instead of typing your password for sudo, the lock screen and
#   admin prompts; unlocking the encrypted disk at boot; optional sops recipient.
#   bootstrap.sh registers the key; nothing here needs it to be present.
{
  ############################################################
  # 1Password
  ############################################################
  programs._1password.enable = true; # `op` CLI
  programs._1password-gui = {
    enable = true;
    # Lets 1Password use your system password/YubiKey to unlock, and the CLI and
    # browser extension talk to the app.
    polkitPolicyOwners = [ "jlor" ];
  };

  # 1Password browser extension, installed and kept up to date by Firefox policy.
  programs.firefox.policies.ExtensionSettings."{d634138d-c276-4fc8-924b-40a0ea21d284}" = {
    installation_mode = "force_installed";
    install_url = "https://addons.mozilla.org/firefox/downloads/latest/1password-x-password-manager/latest.xpi";
  };

  ############################################################
  # YubiKey basics
  ############################################################
  services.pcscd.enable = true; # smart-card interface (age-plugin-yubikey)
  services.udev.packages = [ pkgs.yubikey-personalization ];
  environment.systemPackages = with pkgs; [
    yubikey-manager # ykman: inspect and configure the key
    age-plugin-yubikey # YubiKey as a sops/age key
    pam_u2f # pamu2fcfg: register the key for touch-to-sudo
  ];

  ############################################################
  # Touch the YubiKey instead of typing your password
  ############################################################
  # For sudo, the lock screen (hyprlock) and admin prompts (polkit). Your password
  # still works: if no key is plugged in, PAM just moves on to the password prompt.
  security.pam.u2f = {
    enable = true;
    control = "sufficient";
    settings = {
      cue = true; # "Please touch the device"
      # Fixed origin, so the registration survives hostname changes and reinstalls.
      origin = "pam://desktop";
      appid = "pam://desktop";
      # Registered key handles, from sops (bootstrap adds them). Until then, skip quietly.
      authfile = lib.mkIf (config.sops.secrets ? u2f_keys) config.sops.secrets.u2f_keys.path;
      nouserok = true;
    };
  };
  # The graphical login keeps the password: it also unlocks the keyring and 1Password.
  security.pam.services.greetd.u2f.enable = false;
  security.pam.services.login.u2f.enable = false;

  # Lock screen. Enabled as a program (not just a package) so it gets its PAM service;
  # without one, hyprlock can't check your password and you can't unlock.
  programs.hyprlock.enable = true;

  ############################################################
  # Encrypted disk, unlocked with the YubiKey
  ############################################################
  # Encryption is chosen in the installer ("Encrypt system"); the LUKS device lands in
  # hardware-configuration.nix. bootstrap.sh enrolls the YubiKey with
  # systemd-cryptenroll, and the systemd initrd (default since 26.05, FIDO2 support
  # included) finds the enrolled key by itself: touch it at boot, or type the passphrase.
}
