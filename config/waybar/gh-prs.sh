#!/usr/bin/env zsh
# Waybar PR modules: open-PR counts in the bar, click for the list.
#
#   gh-prs.sh nixos | homeops        print a bar label (λ 0 / ⎈ 2)
#   gh-prs.sh nixos --list           wofi popup of jlor/nixos-config's open PRs
#   gh-prs.sh homeops --list         wofi popup of x00-sh/home-ops's open PRs
#
# nixos is jlor/nixos-config (λ, mauve), homeops is x00-sh/home-ops (⎈, blue).
# The labels are polled by config/waybar/config.jsonc every 5 minutes; --list
# runs on left-click of the respective module. `gh` is authenticated by
# bootstrap (gh auth login); the token lives in ~/.config/gh/hosts.yml, which
# the README lists under "What to back up".

set -u

case ${1:-} in
  nixos)   repo=jlor/nixos-config; glyph=λ; color=#cba6f7 ;;
  homeops) repo=x00-sh/home-ops;   glyph=⎈; color=#89b4fa ;;
  *)       print -u2 "usage: gh-prs.sh (nixos|homeops) [--list]"; exit 2
esac

list=${2:-}

pulls=$(gh api "repos/$repo/pulls?state=open&per_page=100" 2>/dev/null) || {
  # GitHub unreachable (offline, gh not logged in, rate-limited): a dash in
  # the bar, a toast on click. Self-heals on the next poll/click.
  if [[ $list == --list ]]; then
    notify-send "GitHub" "Couldn't reach GitHub for $repo"
  else
    printf '<span color="%s">%s –</span>\n' "$color" "$glyph"
  fi
  exit 0
}

if [[ $list != --list ]]; then
  printf '<span color="%s">%s %s</span>\n' "$color" "$glyph" "$(printf '%s' "$pulls" | jq 'length')"
  exit 0
fi

# --list: wofi, like the Wi-Fi picker (config/wifi-menu). Tabs and newlines in
# a title would break the one-PR-per-line contract, so squash them.
lines=$(printf '%s' "$pulls" | jq -r '.[] | "#\(.number) \(.title | gsub("[\t\n\r]"; " "))"')
[[ -n $lines ]] || { notify-send "GitHub" "No open PRs for $repo"; exit 0 }

chosen=$(printf '%s\n' "$lines" | wofi --dmenu --prompt "Open PRs — $repo")
[[ -n $chosen ]] || exit 0
num=${chosen%% *}; num=${num#\#}
firefox "https://github.com/$repo/pull/$num" &
