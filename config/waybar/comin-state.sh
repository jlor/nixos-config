#!/usr/bin/env zsh
# Waybar comin module: is this machine actually running what's on main?
#
#   comin-state.sh           print the bar label (waybar JSON)
#   comin-state.sh --list    wofi popup: the error, the commit, the log
#
# Why this exists: a failed comin build is silent. comin retries every 30
# seconds forever, the machine quietly stays on its old generation, and a
# merged PR with a green CI check looks exactly like a deploy that landed.
# That gap left this desktop five days behind in November 2026, twice over.
# The bar is where you would actually notice.
#
# Everything is read from `comin status --json`, never the human-readable
# output: that embeds the selected commit's message, so a commit whose body
# happens to mention "build failed" would read as a failure. (One did.)

set -u

list=0
[[ ${1:-} == --list ]] && list=1

# comin not running, socket gone, version without --json: all one "unknown".
if ! state=$(comin status --json 2>/dev/null) || [[ -z $state ]]; then
  if (( list )); then
    notify-send "comin" "Could not read comin status (is the service running?)"
  else
    print -r -- '{"text":"󰚰 –","tooltip":"comin: status unavailable","class":"unknown"}'
  fi
  exit 0
fi

# The classification lives here once; the two modes only differ in which
# fields they select off the end, so the bar and the popup can never
# disagree about what state the machine is in.
read -r -d '' classify <<'JQ'
  . as $s
  | ($s.builder.generation // {})        as $g
  | ($g.source.git // {})                as $git
  | ($s.deployer.deployment // {})       as $d
  | ($g.build_status // "")              as $bs
  | ($g.eval_status // "")               as $es
  | ($d.status // "")                    as $ds
  | ($git.selected_commit_id // "")      as $sha
  | (($git.selected_commit_msg // "") | split("\n")[0]) as $subject
  | (if   $es == "failed" then ($g.eval_err  // "")
     elif $bs == "failed" then ($g.build_err // "")
     elif $ds == "failed" then ($d.error_msg // "")
     else "" end)                        as $err
  | (if   $es == "failed" then "eval failed"
     elif $bs == "failed" then "build failed"
     elif $ds == "failed" then "deploy failed"
     else "" end)                        as $what
  # Order matters. A failure outranks "busy" on purpose: during the retry
  # loop is_building flickers true, and showing "building" there would hide
  # a fault that has been stuck for days. It stays failed until a build wins.
  | (if   $what != ""            then "failed"
     elif $s.is_suspended        then "suspended"
     elif $s.need_to_reboot      then "reboot"
     elif ($s.builder.is_building // false) or ($s.builder.is_evaluating // false)
          or ($s.deployer.is_deploying // false) then "busy"
     else "ok" end)                      as $class
  | {
      class: $class,
      sha:   $sha,
      err:   $err,
      # Waybar renders text and tooltip as pango markup, so anything taken
      # from a commit message or a nix error has to be escaped.
      text: (if   $class == "failed"    then "󰅙 " + $what
                                             + (if ($g.attempt_number // 0) > 1
                                                then " ×" + ($g.attempt_number|tostring) else "" end)
             elif $class == "suspended" then "󰏤 suspended"
             elif $class == "reboot"    then "󰜉 reboot"
             elif $class == "busy"      then "󰚰 " + (if ($s.deployer.is_deploying // false) then "deploying"
                                                    elif ($s.builder.is_evaluating // false) then "evaluating"
                                                    else "building" end)
             else "󰄬" end | @html),
      tooltip: ([ "comin — " + ($s.builder.hostname // "?"),
                  (if $sha != "" then "commit " + $sha[0:7] + "  " + $subject else "no generation yet" end),
                  "build: " + (if $bs == "" then "—" else $bs end)
                            + (if ($g.attempt_number // 0) > 1
                               then "  (attempt " + ($g.attempt_number|tostring) + ")" else "" end),
                  "deploy: " + (if $ds == "" then "—" else ($d.operation // "?") + " " + $ds end)
                             + (if ($d.ended_at // "") != "" then "  " + $d.ended_at[0:19] + "Z" else "" end)
                ]
                + (if $err != "" then [""] + ($err | split("\n")[0:4]) else [] end)
                | join("\n") | @html)
    }
JQ

if (( ! list )); then
  # Colour lives in style.css via the class, like every other module; the
  # markup here is only the glyph and its label.
  print -r -- "$state" | jq -c "$classify | {text, tooltip, class}"
  exit 0
fi

# --list: wofi, like the Wi-Fi picker (config/wifi-menu) and gh-prs.sh.
# Tabs and newlines would break the one-entry-per-line contract, so squash them.
IFS=$'\t' read -r class sha err <<<"$(print -r -- "$state" | jq -r "
  $classify | [.class, .sha, (.err | gsub(\"[\\t\\n\\r]\"; \" \"))] | @tsv")"

repo=jlor/nixos-config
entries=()
[[ -n $err ]] && entries+=("󰅙  ${err[1,160]}")
[[ -n $sha ]] && entries+=("  Open ${sha[1,7]} on GitHub")
entries+=("  Open the comin log")
entries+=("󰋗  comin status")

chosen=$(printf '%s\n' "${entries[@]}" | wofi --dmenu --prompt "comin — $class")
[[ -n $chosen ]] || exit 0

case $chosen in
  *"on GitHub")      firefox "https://github.com/$repo/commit/$sha" & ;;
  *"the comin log")  kitty --title "comin log" -e journalctl -u comin -n 300 --no-pager & ;;
  *"comin status")   kitty --title "comin status" -e sh -c 'comin status; read -r _' & ;;
esac
