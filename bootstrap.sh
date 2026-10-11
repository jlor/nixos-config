# Bootstrap this machine against the repo. Run on a freshly installed NixOS, as jlor:
#
#   nix --extra-experimental-features "nix-command flakes" run --refresh --no-write-lock-file github:jlor/nixos-config#bootstrap
#
# Works for the first install and for reinstalls, and is safe to re-run:
#   1. clone the repo to ~/nixos-config (or update it)
#   2. use this machine's hardware-configuration.nix (disk IDs change on reinstall)
#   3. your personal age key: generate + store in 1Password (first time), or fetch it
#      from 1Password / paste it (reinstall)
#   4. the desktop's age key, and both public keys in .sops.yaml
#   5. create secrets/secrets.yaml (first time) or re-encrypt it for the new desktop key
#   6. YubiKey: register it for touch-to-sudo, and to unlock the encrypted disk
#   7. lock the flake and rebuild into the full config
#   8. YubiKey as an extra sops key (optional; needs the rebuilt system)
#   9. commit and push what changed, so the repo matches the machine again
# Every step checks first and skips what's already done.
# (Wrapped by writeShellApplication in flake.nix: bash, strict mode, tools on PATH,
#  checked by ShellCheck at build time.)

REPO_URL="https://github.com/jlor/nixos-config"
DIR="${NIXOS_CONFIG_DIR:-$HOME/nixos-config}"
HOST="desktop"
EXPECTED_USER="jlor"
HOST_KEY="${BOOTSTRAP_HOST_KEY:-/var/lib/sops-nix/key.txt}"
USER_KEY="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
OP_ITEM="nixos-config age key"           # where the personal age key lives in 1Password
U2F_ORIGIN="pam://desktop"               # must match security.nix
export SOPS_AGE_KEY_FILE="$USER_KEY"
export NIX_CONFIG="experimental-features = nix-command flakes"

say()  { printf '\n\033[1;35m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '    \033[1;33m%s\033[0m\n' "$*"; }
die()  { printf '\n\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }
ask()  { local reply; read -r -p "    $1 [y/N] " reply; [[ $reply == [yY]* ]]; }

# Temp files are removed on any exit, including errors (one may hold a plaintext secret).
temp_files=()
cleanup() { rm -f "${temp_files[@]}"; }
trap cleanup EXIT

# sudo may not keep our PATH, so resolve tools to absolute paths first.
abs() { command -v "$1" || die "Missing tool: $1"; }

first_time=false
generated_user_key=false
keys_changed=false
yubikey=false

# --- 1Password helpers ------------------------------------------------------
op_ready() {
  op whoami >/dev/null 2>&1 && return 0
  info "Sign in to 1Password (email, Secret Key, password; once per machine):"
  if [ -z "$(op account list 2>/dev/null)" ]; then
    eval "$(op account add --signin)" || return 1
  else
    eval "$(op signin)" || return 1
  fi
  op whoami >/dev/null 2>&1
}

op_fetch_key() { op item get "$OP_ITEM" --fields label=password --reveal; }

op_store_key() {
  # Item JSON goes in on stdin, so the key never appears on a command line.
  jq -n --arg title "$OP_ITEM" --arg key "$1" '{
      title: $title, category: "PASSWORD",
      fields: [
        {id: "password", type: "CONCEALED", purpose: "PASSWORD", label: "password", value: $key},
        {id: "notesPlain", type: "STRING", purpose: "NOTES", label: "notesPlain",
         value: "age key for github.com/jlor/nixos-config secrets (sops). Used by bootstrap on reinstall."}
      ]}' | op item create - >/dev/null
}

# --- Steps -------------------------------------------------------------------
preflight() {
  [ -e /etc/NIXOS ] || die "This isn't NixOS. Install NixOS first (see the README)."
  [ "$(id -u)" -ne 0 ] || die "Run this as your normal user, not root. It uses sudo where needed."
  [ "$(id -un)" = "$EXPECTED_USER" ] || die "Run this as '$EXPECTED_USER' (the user the config defines). Current user: $(id -un)"
  sudo -v || die "sudo is needed for the rebuild and the desktop's key."
  if sudo "$(abs ykman)" list 2>/dev/null | grep -q .; then
    yubikey=true
    info "YubiKey found: $(sudo "$(abs ykman)" list | head -1)"
  else
    info "No YubiKey plugged in; the YubiKey steps will be skipped (re-run later to add them)."
  fi
}

step_repo() {
  say "1/9 Repo: $DIR"
  if [ -d "$DIR/.git" ]; then
    git -C "$DIR" pull --ff-only || die "Couldn't fast-forward $DIR. Commit or stash your local changes first."
  else
    git clone "$REPO_URL" "$DIR"
  fi
  cd "$DIR"
  grep -q "REPLACE_WITH" .sops.yaml && first_time=true
  return 0
}

step_hardware() {
  say "2/9 Hardware config for this machine"
  local new_hw
  new_hw="$(mktemp)"
  temp_files+=("$new_hw")
  if [ -f /etc/nixos/hardware-configuration.nix ]; then
    cp /etc/nixos/hardware-configuration.nix "$new_hw"
  else
    # shellcheck disable=SC2024  # the redirect should write as us, not root
    sudo nixos-generate-config --show-hardware-config > "$new_hw"
  fi
  if [ ! -f hardware-configuration.nix ]; then
    info "Adding hardware-configuration.nix"
    cp "$new_hw" hardware-configuration.nix
  elif ! cmp -s "$new_hw" hardware-configuration.nix; then
    info "This machine differs from the committed one (normal after a reinstall):"
    diff -u hardware-configuration.nix "$new_hw" | sed 's/^/    /' || true
    cp "$new_hw" hardware-configuration.nix
  else
    info "Up to date"
  fi
  if grep -q "luks" hardware-configuration.nix; then
    info "Encrypted disk detected"
  else
    warn "The disk isn't encrypted. Reinstall with \"Encrypt system\" ticked to fix that."
  fi
  git add hardware-configuration.nix
}

step_user_key() {
  say "3/9 Your personal age key ($USER_KEY)"
  local key=""
  if [ -f "$USER_KEY" ] && grep -q '^AGE-SECRET-KEY-1' "$USER_KEY"; then
    info "Found"
    return 0
  fi
  if $first_time; then
    key="$(age-keygen 2>/dev/null | grep '^AGE-SECRET-KEY-1')"
    generated_user_key=true
    info "Generated a new key"
    if op_ready && op_store_key "$key"; then
      info "Stored in 1Password as \"$OP_ITEM\""
      generated_user_key=false   # safely backed up; no need to show it at the end
    else
      warn "Couldn't store it in 1Password; it'll be shown at the end to back up by hand."
    fi
  else
    if op_ready && key="$(op_fetch_key 2>/dev/null)" && [[ $key == AGE-SECRET-KEY-1* ]]; then
      info "Fetched from 1Password (\"$OP_ITEM\")"
    else
      info "Couldn't get it from 1Password. Paste the line starting with AGE-SECRET-KEY-1"
      info "(input is hidden), then press Enter:"
      read -r -s key
      [[ $key == AGE-SECRET-KEY-1* ]] || die "That doesn't look like an age secret key."
    fi
  fi
  mkdir -p "$(dirname "$USER_KEY")" && chmod 700 "$(dirname "$USER_KEY")"
  (umask 077 && printf '%s\n' "$key" > "$USER_KEY")
  unset key
}

step_host_key() {
  say "4/9 The desktop's age key and .sops.yaml"
  local keygen user_pub host_pub
  keygen="$(abs age-keygen)"
  if ! sudo test -f "$HOST_KEY"; then
    # Same as sops-nix's generateKey on boot; done here so secrets can be encrypted
    # for this machine before the first full rebuild.
    sudo install -d -m 0755 "$(dirname "$HOST_KEY")"
    sudo sh -c "umask 077 && '$keygen' -o '$HOST_KEY' 2>/dev/null"
    info "Generated $HOST_KEY"
  fi
  user_pub="$(grep '^AGE-SECRET-KEY-1' "$USER_KEY" | age-keygen -y)"
  host_pub="$(sudo "$keygen" -y "$HOST_KEY")"

  if $first_time; then
    sed -i "s|^\(  - &jlor \).*|\1$user_pub|; s|^\(  - &desktop \).*|\1$host_pub|" .sops.yaml
    keys_changed=true
    info "Wrote both public keys into .sops.yaml"
  else
    grep -qF "$user_pub" .sops.yaml || die "Your key isn't the one in .sops.yaml. Restore your original personal key (it's the only one that can open the existing secrets)."
    if ! grep -qF "$host_pub" .sops.yaml; then
      sed -i "s|^\(  - &desktop \).*|\1$host_pub|" .sops.yaml
      keys_changed=true
      info "Updated the desktop key in .sops.yaml (new install)"
    else
      info "Up to date"
    fi
  fi
  git add .sops.yaml
}

step_secrets() {
  say "5/9 Secrets (secrets/secrets.yaml)"
  local git_email plain encrypted
  if [ ! -f secrets/secrets.yaml ]; then
    read -r -p "    Email for your git commits (tip: your GitHub noreply address): " git_email
    [ -n "$git_email" ] || die "An email is needed for git commits."
    plain="$(mktemp -p "${XDG_RUNTIME_DIR:-/tmp}" secrets.XXXXXX.yaml)"   # RAM-backed
    temp_files+=("$plain")
    encrypted="$(mktemp)"
    temp_files+=("$encrypted")
    printf 'git_email: %s\n' "$git_email" > "$plain"
    # --filename-override picks the .sops.yaml rule for that path; write to a temp file
    # first so a failure never leaves an empty secrets.yaml behind.
    sops encrypt --filename-override secrets/secrets.yaml --input-type yaml --output-type yaml "$plain" > "$encrypted"
    rm -f "$plain"
    mv "$encrypted" secrets/secrets.yaml
    info "Created and encrypted. Edit later with: sops secrets/secrets.yaml"
  elif $keys_changed; then
    sops updatekeys --yes secrets/secrets.yaml
    info "Re-encrypted for the new desktop key"
  else
    info "Up to date"
  fi
  git add secrets/secrets.yaml
}

step_yubikey() {
  say "6/9 YubiKey: touch-to-sudo and disk unlock"
  if ! $yubikey; then info "Skipped (no YubiKey plugged in)"; return 0; fi

  # Touch-to-sudo/unlock: the key's registration goes into sops as u2f_keys.
  if grep -q '^u2f_keys:' secrets/secrets.yaml; then
    info "Touch-to-sudo: already registered"
  elif ask "Register this YubiKey for touch-to-sudo and unlocking the lock screen?"; then
    local reg
    info "Touch the YubiKey when it blinks (enter its PIN if asked)."
    reg="$(sudo "$(abs pamu2fcfg)" -u "$EXPECTED_USER" -o "$U2F_ORIGIN" -i "$U2F_ORIGIN")"
    [[ $reg == "$EXPECTED_USER:"* ]] || die "pamu2fcfg didn't return a registration."
    sops set secrets/secrets.yaml '["u2f_keys"]' "$(jq -Rn --arg v "$reg" '$v')"
    git add secrets/secrets.yaml
    info "Registered (stored encrypted as u2f_keys)"
  fi

  # Disk unlock: enroll the YubiKey (FIDO2) in each LUKS volume; the passphrase stays.
  local dev enroll
  enroll="$(abs systemd-cryptenroll)"
  mapfile -t luks_devs < <(lsblk -rno PATH,FSTYPE | awk '$2 == "crypto_LUKS" { print $1 }')
  if [ "${#luks_devs[@]}" -eq 0 ]; then
    info "Disk unlock: no encrypted disk, skipped"
  fi
  for dev in "${luks_devs[@]}"; do
    if sudo "$enroll" "$dev" 2>/dev/null | grep -qw fido2; then
      info "Disk unlock: $dev already has the YubiKey"
    elif ask "Unlock $dev at boot by touching the YubiKey? (the passphrase keeps working)"; then
      info "Enter the disk passphrase, then the YubiKey PIN, then touch it."
      sudo "$enroll" --fido2-device=auto "$dev"
      info "Enrolled. At boot: touch the key, or type the passphrase."
    fi
  done
}

step_rebuild() {
  say "7/9 Building the system (the first time takes a while)"
  nix flake lock
  git add flake.lock
  # The prebuilt-CUDA cache (configuration.nix → nix.settings) only takes effect once
  # this build is active, and Nix accepts extra caches only from root. So the build
  # runs as root with the cache passed in; otherwise Ollama's CUDA code compiles from
  # source for hours. "path:" because root can't read your git checkout as a git repo.
  # Keep the cache URL and key in sync with configuration.nix.
  local rc=0
  sudo "$(abs nixos-rebuild)" switch --flake "path:$PWD#$HOST" \
    --option experimental-features "nix-command flakes" \
    --option extra-substituters "https://cache.nixos-cuda.org" \
    --option extra-trusted-public-keys "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M=" \
    || rc=$?
  [ "$rc" -eq 0 ] && return 0

  # On the first switch from a console login, home-manager fails at its dconf step:
  # your login session's D-Bus started before dconf existed. Harmless; it applies at
  # the next boot. Anything else failing is a real error.
  local other_failures
  other_failures="$(systemctl --failed --no-legend --plain | awk '{print $1}' | grep -v "^home-manager-$EXPECTED_USER\.service$" || true)"
  if systemctl is-failed --quiet "home-manager-$EXPECTED_USER.service" && [ -z "$other_failures" ]; then
    warn "Your user settings (home-manager) couldn't apply in this console session."
    warn "That's expected on a fresh install: they apply when you reboot."
  else
    die "The rebuild failed (exit $rc); see the errors above. Failed units: ${other_failures:-none}"
  fi
}

step_yubikey_age() {
  say "8/9 YubiKey as an extra sops key"
  if ! $yubikey; then info "Skipped (no YubiKey plugged in)"; return 0; fi
  if grep -q '&yubikey' .sops.yaml; then
    # Reinstall: the YubiKey is already a recipient; just restore the identity stub
    # (it only points at the key's slot, so it can be regenerated any time).
    if ! grep -q '^AGE-PLUGIN-YUBIKEY-' "$USER_KEY"; then
      age-plugin-yubikey --identity >> "$USER_KEY"
      info "Restored the YubiKey identity in $USER_KEY"
    else
      info "Up to date"
    fi
    return 0
  fi
  ask "Also let the YubiKey open the secrets (a hardware backup to your 1Password key)?" || return 0
  # Optional step: any failure here is a warning, and leaves the repo as it was,
  # so the bootstrap still reaches the commit step.
  local recipient
  recipient="$(age-plugin-yubikey --list 2>/dev/null | grep -m1 '^age1yubikey' || true)"
  if [ -z "$recipient" ]; then
    info "Creating an age key on the YubiKey (it'll ask for a PIN and touch policy):"
    if ! age-plugin-yubikey --generate >/dev/null; then
      warn "Skipped: the YubiKey couldn't create the key (see the message above)."
      warn "Your 1Password key still opens the secrets. Re-run the bootstrap after fixing it."
      return 0
    fi
    recipient="$(age-plugin-yubikey --list 2>/dev/null | grep -m1 '^age1yubikey' || true)"
    if [ -z "$recipient" ]; then
      warn "Skipped: age-plugin-yubikey didn't report a key."
      return 0
    fi
  fi
  local sops_backup secrets_backup
  sops_backup="$(mktemp)"; secrets_backup="$(mktemp)"
  temp_files+=("$sops_backup" "$secrets_backup")
  cp .sops.yaml "$sops_backup"; cp secrets/secrets.yaml "$secrets_backup"
  sed -i "s|^\(  - &desktop .*\)$|\1\n  - \&yubikey $recipient|; s|^\(          - \*desktop\)$|\1\n          - *yubikey|" .sops.yaml
  if ! grep -q '\*yubikey' .sops.yaml || ! sops updatekeys --yes secrets/secrets.yaml; then
    cp "$sops_backup" .sops.yaml; cp "$secrets_backup" secrets/secrets.yaml
    warn "Skipped: couldn't add the YubiKey to the secrets; .sops.yaml and the secrets are unchanged."
    return 0
  fi
  grep -q '^AGE-PLUGIN-YUBIKEY-' "$USER_KEY" || age-plugin-yubikey --identity >> "$USER_KEY"
  git add .sops.yaml secrets/secrets.yaml
  info "Added: the secrets now open with your 1Password key or the YubiKey"
}

step_commit() {
  say "9/9 Save the result to GitHub"
  if git diff --cached --quiet; then
    info "Nothing changed; the repo already matches this machine."
    return 0
  fi
  git status --short | sed 's/^/    /'
  if ask "Commit these and push to main?"; then
    gh auth status >/dev/null 2>&1 || gh auth login --hostname github.com --git-protocol https --web
    gh auth setup-git
    local msg="Bootstrap: reinstall on new hardware/disks"
    $first_time && msg="Bootstrap: hardware config, lock file, sops keys and secrets"
    # Name and email passed explicitly: on a fresh install your git config from
    # home-manager may not be active until the reboot. The email comes from sops.
    git -c user.name="$EXPECTED_USER" -c include.path=/run/secrets/rendered/git-identity \
      commit -m "$msg"
    git push
  else
    info "Skipped. Commit and push later from $DIR."
  fi
}

finish() {
  say "Done. Reboot to start the full desktop: sudo reboot"
  cat <<'EOF'

    After the reboot, in the 1Password app (sign in first):
      • Settings → Developer → "Use the SSH agent" and "Integrate with 1Password CLI"
      • Create an SSH key (or use your existing one), add it to GitHub as an
        authentication AND signing key, and put its public key in home.nix
        (sshSigningKey) to sign your commits.
EOF
  if $generated_user_key; then
    printf '\n\033[1;33m!! Back up your personal age key now (1Password). Without it the\n   secrets in the repo can never be opened again:\033[0m\n\n'
    grep '^AGE-SECRET-KEY-1' "$USER_KEY" | sed 's/^/    /'
    echo
  fi
}

main() {
  preflight
  step_repo
  step_hardware
  step_user_key
  step_host_key
  step_secrets
  step_yubikey
  step_rebuild
  step_yubikey_age
  step_commit
  finish
}

# BOOTSTRAP_LIB=1 loads the functions without running them (used by tests).
[ -n "${BOOTSTRAP_LIB:-}" ] || main "$@"
