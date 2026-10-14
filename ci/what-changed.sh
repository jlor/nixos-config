#!/usr/bin/env bash
# Reports which packages actually change between two checkouts of this config.
#
# Renovate's lock file PRs are opaque: "flake.lock updated" says nothing about
# whether the kernel moved. This evaluates both sides and prints the versions
# that differ, as markdown for a pull request comment.
#
# Usage: what-changed.sh <base-dir> <head-dir>
# Writes markdown to stdout, and reboot=true|false to $GITHUB_OUTPUT when set.
set -euo pipefail

# join and sort must agree on collation, and the report should read the same
# everywhere it runs.
export LC_ALL=C

base_dir=$1
head_dir=$2
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# One line per package name. A name can appear more than once (the same package
# installed system-wide and in home, or two variants of it), so collapse
# duplicates and join genuinely different versions with a comma.
versions() {
  local dir=$1
  FLAKE_DIR="$dir" nix eval --impure --raw --file "$here/package-versions.nix" |
    sort -u |
    awk -F'\t' '
      { if (!($1 in v)) v[$1] = $2; else if (index(v[$1], $2) == 0) v[$1] = v[$1] ", " $2 }
      END { for (n in v) print n "\t" v[n] }
    ' |
    sort
}

# A single option's value, for the headline packages that aren't in
# systemPackages. "?" keeps the report working if an option is ever renamed.
option() {
  local dir=$1 attr=$2
  FLAKE_DIR="$dir" nix eval --impure --raw --expr \
    "(builtins.getFlake (builtins.getEnv \"FLAKE_DIR\")).nixosConfigurations.desktop.config.$attr" \
    2>/dev/null || echo "?"
}

versions "$base_dir" >"$work/base"
versions "$head_dir" >"$work/head"

# -a1 -a2 keeps names present on only one side; "-" marks the absent version.
join -t "$(printf '\t')" -a1 -a2 -e '-' -o '0,1.2,2.2' "$work/base" "$work/head" >"$work/joined"

changed=$(awk -F'\t' '$2 != "-" && $3 != "-" && $2 != $3' "$work/joined" || true)
added=$(awk -F'\t' '$2 == "-"' "$work/joined" || true)
removed=$(awk -F'\t' '$3 == "-"' "$work/joined" || true)

kernel_base=$(option "$base_dir" boot.kernelPackages.kernel.version)
kernel_head=$(option "$head_dir" boot.kernelPackages.kernel.version)
nvidia_base=$(option "$base_dir" hardware.nvidia.package.version)
nvidia_head=$(option "$head_dir" hardware.nvidia.package.version)

reboot=false
if [ "$kernel_base" != "$kernel_head" ] || [ "$nvidia_base" != "$nvidia_head" ]; then
  reboot=true
fi
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "reboot=$reboot" >>"$GITHUB_OUTPUT"
fi

echo "<!-- what-changed -->"
echo "## What this changes on the desktop"
echo

if [ "$reboot" = true ]; then
  echo "> [!WARNING]"
  echo "> **Needs a reboot.** The kernel or the Nvidia driver moves, so this can"
  echo "> also interrupt a running game when comin deploys it."
  echo
fi

printf '| | Before | After |\n|---|---|---|\n'
printf '| Kernel | %s | %s |\n' "$kernel_base" "$kernel_head"
printf '| Nvidia | %s | %s |\n' "$nvidia_base" "$nvidia_head"
printf '| Hyprland | %s | %s |\n' \
  "$(option "$base_dir" programs.hyprland.package.version)" \
  "$(option "$head_dir" programs.hyprland.package.version)"
echo

# body is tab-separated "name<TAB>base<TAB>head"; prog picks the fields that
# make sense for that section.
section() {
  local title=$1 body=$2 prog=$3
  if [ -z "$body" ]; then
    return 0
  fi
  printf '<details><summary>%s (%s)</summary>\n\n' "$title" "$(printf '%s\n' "$body" | wc -l)"
  printf '%s\n' "$body" | awk -F'\t' "$prog"
  printf '\n</details>\n\n'
}

# $1/$2/$3 are awk fields, so these must stay single-quoted.
# shellcheck disable=SC2016
section "Updated" "$changed" '{ printf "- `%s` %s → %s\n", $1, $2, $3 }'
# shellcheck disable=SC2016
section "Added" "$added" '{ printf "- `%s` %s\n", $1, $3 }'
# shellcheck disable=SC2016
section "Removed" "$removed" '{ printf "- `%s` %s\n", $1, $2 }'

if [ -z "$changed$added$removed" ]; then
  echo "No package versions change. The lock file moves, the closure doesn't."
fi
