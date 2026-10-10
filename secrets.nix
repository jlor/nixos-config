{ config, lib, ... }:

# Secrets with sops + age (sops-nix).
#
# Secrets live encrypted in secrets/secrets.yaml, which is safe to commit to this
# public repo. At boot, sops-nix decrypts them with the desktop's own age key and
# puts each one in /run/secrets/<name> (in RAM, never in the Nix store).
#
# Who can decrypt is set in .sops.yaml: you (to edit) and this desktop (to use).
# `nix run github:jlor/nixos-config#bootstrap` sets all of this up; see README → Secrets.
let
  hasSecrets = builtins.pathExists ./secrets/secrets.yaml;
in
{
  sops = lib.mkMerge [
    {
      # The desktop's own key. Generated on first boot; its public half goes in .sops.yaml.
      age.keyFile = "/var/lib/sops-nix/key.txt";
      age.generateKey = true;
      # No SSH server on this machine, so don't look for SSH host keys.
      age.sshKeyPaths = [ ];
      gnupg.sshKeyPaths = [ ];
    }

    # Everything below needs secrets/secrets.yaml, which bootstrap creates.
    (lib.mkIf hasSecrets {
      defaultSopsFile = ./secrets/secrets.yaml;

      # Your git email, kept out of the public repo. git reads it via an include
      # (home.nix → programs.git.includes); git ignores the include until it exists.
      secrets.git_email = { };
      templates."git-identity" = {
        owner = "jlor";
        content = ''
          [user]
            email = ${config.sops.placeholder.git_email}
        '';
      };

      # Add more secrets here, e.g.:
      #   secrets.github_token = { owner = "jlor"; };   # → /run/secrets/github_token
    })
  ];
}
