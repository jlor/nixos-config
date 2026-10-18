# Security

1Password, the YubiKey and the encrypted secrets. Configured in `security.nix`
and `secrets.nix`.

## 1Password

The app, the `op` CLI and the Firefox extension are installed by the config, and the app
starts with Hyprland (in the tray). One-time steps in the app after signing in:

1. **Settings → Developer → "Use the SSH agent"**: your SSH keys stay in 1Password and
   ssh/git use them through `~/.1password/agent.sock` (already configured).
2. **Settings → Developer → "Integrate with 1Password CLI"**: `op` and Walker unlock
   through the app instead of asking for your password.
3. **Commit signing:** create an SSH key in 1Password (or use your existing one), add it to
   GitHub as both an *authentication* and a *signing* key (Settings → SSH and GPG keys),
   and put its public key in `home.nix` → `sshSigningKey`. Commits then show "Verified".

In Walker, type `*` and a name to find a login and copy its password; the clipboard is
cleared after 5 seconds. Vaults searched: `config/elephant/1password.toml`.

## YubiKey

| Use | How |
|---|---|
| sudo, admin prompts | Touch the key instead of typing your password (password still works) |
| Lock screen | Press Enter on the empty field, then touch the key when it asks |
| Disk unlock at boot | Touch the key (PIN if set), or type the passphrase |
| Secrets (optional) | Opens `secrets/secrets.yaml` like your 1Password key does |

On the lock screen the touch prompt only appears once PAM is running, and PAM only
starts when you submit the field — so Enter first, on an empty field, then touch.
Typing your password works too, but with the key plugged in you wait for `pam_u2f`
to time out before the password is even checked; pull the key to skip that.

The login screen still asks for your password, because that also unlocks the keyring.
`ykman info` shows the key's state. The bootstrap registers one YubiKey. A replacement or
second key needs a manual step (passwords keep working meanwhile):
`pamu2fcfg -n -o pam://desktop -i pam://desktop` appends to `u2f_keys` in
`sops secrets/secrets.yaml`, and `sudo systemd-cryptenroll --fido2-device=auto <disk>` adds
it to the disk.

## Secrets (sops + age)

Secrets are stored encrypted in `secrets/secrets.yaml`, so they can live in this public
repo. At boot, sops-nix decrypts them with the desktop's own key into `/run/secrets/`
(in RAM, never in the Nix store). Two keys can decrypt: yours, to edit, and the desktop's,
to use them, plus optionally your YubiKey. All set up by the bootstrap.

- Edit secrets: `sops secrets/secrets.yaml` (decrypts into vim, re-encrypts on save).
- Use a secret: add it with `sops`, then declare it in `secrets.nix`:

  ```nix
  (lib.mkIf (has "github_token") { secrets.github_token = { owner = "jlor"; }; })
  # → /run/secrets/github_token
  ```

  then point whatever needs it at that path.
- Already in use: `git_email` (rendered into a git config snippet that git includes),
  `u2f_keys` (the YubiKey registration for touch-to-sudo) and `nas_host` (the NAS
  address, see [NAS shares](nas.md)).
- A secret's feature switches on by itself once the key exists in the file: `secrets.nix`
  reads the key names, which sops leaves unencrypted.
- After a reinstall the desktop has a new key; bootstrap swaps it into `.sops.yaml` and
  re-encrypts the file (`sops updatekeys`). That needs your personal key, so keep it safe.
