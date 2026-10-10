{ config, lib, ... }:

# Secrets with sops + age (sops-nix).
#
# Secrets live encrypted in secrets/secrets.yaml, which is safe to commit to this
# public repo. At boot, sops-nix decrypts them with the desktop's own age key and
# puts each one in /run/secrets/<name> (in RAM, never in the Nix store).
#
# Who can decrypt is set in .sops.yaml: you (to edit), this desktop (to use), and
# optionally your YubiKey. `nix run github:jlor/nixos-config#bootstrap` sets it all up.
let
  file = ./secrets/secrets.yaml;
  hasFile = builtins.pathExists file;
  # sops encrypts values but leaves key names readable, so the config can tell which
  # secrets exist and only switch features on once their secret has been added.
  # Other modules check `config.sops.secrets ? <name>`.
  has = name: hasFile && lib.hasInfix "\n${name}:" ("\n" + builtins.readFile file);
in
{
  sops = lib.mkMerge [
    {
      # The desktop's own key. Generated on first boot (or by bootstrap); its public
      # half goes in .sops.yaml.
      age.keyFile = "/var/lib/sops-nix/key.txt";
      age.generateKey = true;
      # No SSH server on this machine, so don't look for SSH host keys.
      age.sshKeyPaths = [ ];
      gnupg.sshKeyPaths = [ ];
    }

    (lib.mkIf hasFile { defaultSopsFile = file; })

    # Your git email, kept out of the public repo. git reads it via an include
    # (home.nix → programs.git.includes); git ignores the include until it exists.
    (lib.mkIf (has "git_email") {
      secrets.git_email = { };
      templates."git-identity" = {
        owner = "jlor";
        content = ''
          [user]
            email = ${config.sops.placeholder.git_email}
        '';
      };
    })

    # YubiKey registration for touch-to-sudo/unlock (see security.nix). Owned by jlor
    # because hyprlock checks it as your user.
    (lib.mkIf (has "u2f_keys") {
      secrets.u2f_keys = { owner = "jlor"; };
    })

    # Add more secrets the same way, e.g.:
    #   (lib.mkIf (has "github_token") { secrets.github_token = { owner = "jlor"; }; })
  ];
}
