{ lib, ... }:

# Secrets with sops + age (sops-nix).
#
# Secrets live encrypted in secrets/secrets.yaml, which is safe to commit to this
# public repo. At boot, sops-nix decrypts them with the desktop's own age key and
# puts each one in /run/secrets/<name> (in RAM, never in the Nix store).
#
# Who can decrypt is set in .sops.yaml: you (to edit) and this desktop (to use).
# One-time setup: README.md → "Secrets".
{
  sops = {
    # The desktop's own key. Generated on first boot; its public half goes in .sops.yaml.
    age.keyFile = "/var/lib/sops-nix/key.txt";
    age.generateKey = true;
    # No SSH server on this machine, so don't look for SSH host keys.
    age.sshKeyPaths = [ ];
    gnupg.sshKeyPaths = [ ];

    # Used once secrets/secrets.yaml exists (created with `sops secrets/secrets.yaml`).
    defaultSopsFile = lib.mkIf (builtins.pathExists ./secrets/secrets.yaml) ./secrets/secrets.yaml;

    # Declare secrets here, e.g.:
    #   secrets."github/token" = { owner = "jlor"; };   # → /run/secrets/github/token
    secrets = { };
  };
}
