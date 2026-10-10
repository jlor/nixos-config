# Bootstrap this machine against the repo. Run on a freshly installed NixOS, as jlor:
#
#   nix --extra-experimental-features "nix-command flakes" run github:jlor/nixos-config#bootstrap
#
# Works for the first install and for reinstalls, and is safe to re-run:
#   1. clone the repo to ~/nixos-config (or update it)
#   2. use this machine's hardware-configuration.nix (disk IDs change on reinstall)
#   3. set up your personal age key (generate the first time, restore on reinstall)
#   4. set up the desktop's age key and put both public keys in .sops.yaml
#   5. create secrets/secrets.yaml (first time) or re-encrypt it for the new desktop key
#   6. lock the flake and rebuild into the full config
#   7. commit and push what changed, so the repo matches the machine again
# (This file is wrapped by writeShellApplication in flake.nix: bash, strict mode,
#  git/gh/age/sops on PATH, checked by shellcheck at build time.)

REPO_URL="https://github.com/jlor/nixos-config"
DIR="${NIXOS_CONFIG_DIR:-$HOME/nixos-config}"
HOST="desktop"
EXPECTED_USER="jlor"
HOST_KEY="/var/lib/sops-nix/key.txt"
USER_KEY="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
export SOPS_AGE_KEY_FILE="$USER_KEY"
export NIX_CONFIG="experimental-features = nix-command flakes"

say()  { printf '\n\033[1;35m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die()  { printf '\n\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }
ask()  { local reply; read -r -p "    $1 [y/N] " reply; [[ $reply == [yY]* ]]; }

# Temp files are removed on any exit, including errors (one may hold a plaintext secret).
temp_files=()
cleanup() { rm -f "${temp_files[@]}"; }
trap cleanup EXIT

# --- Preflight ---------------------------------------------------------------
[ -e /etc/NIXOS ] || die "This isn't NixOS. Install NixOS first (see the README)."
[ "$(id -u)" -ne 0 ] || die "Run this as your normal user, not root. It uses sudo where needed."
[ "$(id -un)" = "$EXPECTED_USER" ] || die "Run this as '$EXPECTED_USER' (the user the config defines). Current user: $(id -un)"
sudo -v || die "sudo is needed for the rebuild and the desktop's key."

# --- 1. Repo -----------------------------------------------------------------
say "1/7 Repo: $DIR"
if [ -d "$DIR/.git" ]; then
  git -C "$DIR" pull --ff-only || die "Couldn't fast-forward $DIR. Commit or stash your local changes first."
else
  git clone "$REPO_URL" "$DIR"
fi
cd "$DIR"

# --- 2. Hardware config ------------------------------------------------------
say "2/7 Hardware config for this machine"
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
git add hardware-configuration.nix

# --- 3. Personal age key -----------------------------------------------------
say "3/7 Your personal age key ($USER_KEY)"
first_time=false
grep -q "REPLACE_WITH" .sops.yaml && first_time=true
generated_user_key=false
if [ -f "$USER_KEY" ]; then
  info "Found"
elif $first_time; then
  mkdir -p "$(dirname "$USER_KEY")" && chmod 700 "$(dirname "$USER_KEY")"
  age-keygen -o "$USER_KEY" 2>/dev/null
  generated_user_key=true
  info "Generated a new key. You'll be shown it at the end to back up."
else
  info "Restore it from your password manager. Paste the line starting with AGE-SECRET-KEY-1"
  info "(input is hidden), then press Enter:"
  read -r -s pasted_key
  [[ $pasted_key == AGE-SECRET-KEY-1* ]] || die "That doesn't look like an age secret key."
  mkdir -p "$(dirname "$USER_KEY")" && chmod 700 "$(dirname "$USER_KEY")"
  (umask 077 && printf '%s\n' "$pasted_key" > "$USER_KEY")
  unset pasted_key
  info "Restored"
fi
user_pub="$(age-keygen -y "$USER_KEY")"

# --- 4. Desktop age key + .sops.yaml -----------------------------------------
say "4/7 The desktop's age key and .sops.yaml"
AGE_KEYGEN="$(command -v age-keygen)"   # absolute path: sudo may not keep PATH
if ! sudo test -f "$HOST_KEY"; then
  # Same thing sops-nix's generateKey does on boot; done here so secrets can be
  # encrypted for this machine before the first full rebuild.
  sudo install -d -m 0755 "$(dirname "$HOST_KEY")"
  sudo sh -c "umask 077 && '$AGE_KEYGEN' -o '$HOST_KEY' 2>/dev/null"
  info "Generated $HOST_KEY"
fi
host_pub="$(sudo "$AGE_KEYGEN" -y "$HOST_KEY")"

keys_changed=false
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

# --- 5. Secrets file ---------------------------------------------------------
say "5/7 Secrets (secrets/secrets.yaml)"
if [ ! -f secrets/secrets.yaml ]; then
  read -r -p "    Email for your git commits (tip: your GitHub noreply address): " git_email
  [ -n "$git_email" ] || die "An email is needed for git commits."
  plain="$(mktemp -p "${XDG_RUNTIME_DIR:-/tmp}" secrets.XXXXXX.yaml)"   # RAM-backed
  temp_files+=("$plain")
  printf 'git_email: %s\n' "$git_email" > "$plain"
  encrypted="$(mktemp)"
  temp_files+=("$encrypted")
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

# --- 6. Lock + rebuild -------------------------------------------------------
say "6/7 Building the system (the first time takes a while)"
nix flake lock
git add flake.lock
# Evaluates and builds as you; only the activation step runs through sudo.
nixos-rebuild switch --sudo --flake ".#$HOST"

# --- 7. Commit + push --------------------------------------------------------
say "7/7 Save the result to GitHub"
if git diff --cached --quiet; then
  info "Nothing changed; the repo already matches this machine."
else
  git status --short | sed 's/^/    /'
  if ask "Commit these and push to main?"; then
    gh auth status >/dev/null 2>&1 || gh auth login --hostname github.com --git-protocol https --web
    gh auth setup-git
    if $first_time; then msg="Bootstrap: hardware config, lock file, sops keys and secrets"
    else msg="Bootstrap: reinstall on new hardware/disks"; fi
    git commit -m "$msg"
    git push
  else
    info "Skipped. Commit and push later from $DIR."
  fi
fi

say "Done. Reboot to start the full desktop: sudo reboot"
if $generated_user_key; then
  printf '\n\033[1;33m!! Back up your personal age key now (password manager). Without it the\n   secrets in the repo can never be opened again:\033[0m\n\n'
  grep '^AGE-SECRET-KEY-1' "$USER_KEY" | sed 's/^/    /'
  echo
fi
