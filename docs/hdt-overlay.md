# Hearthstone Deck Tracker overlay on Hyprland (WIP)

Status: **mostly working, one unsolved artifact.** Not merged to `main`.

Goal: run [Hearthstone Deck Tracker](https://hsreplay.net/downloads/) (HDT) over Hearthstone
under Proton, with its overlay *see-through* (game visible underneath), *click-through*
(clicks on empty areas reach the game) and its own widgets still clickable.

This worked on the previous Omarchy install, so it is achievable on Hyprland.

## Current state

| Behaviour | Works? |
|---|---|
| Overlay renders over the game | yes |
| See-through (game visible through transparent areas) | yes |
| Click-through (clicks on empty areas reach the game) | yes |
| Overlay's own widgets clickable (Tier7 tabs etc.) | yes |
| Whole overlay stays drawn (not just under the cursor) | yes, **needs `damage_tracking = 0`** |
| Old content cleared when the overlay changes | **no — stale pixels persist** |

The one open bug: switching tabs inside the overlay leaves the previous content drawn
underneath the new content. It is **not** a repaint-trigger problem — the ghosting survives
a workspace switch, so the stale data is in Wine's layered-window buffer, not in Hyprland's
compositing. It also happened in `SHAPE` mode, i.e. it is independent of which Proton
overlay mode is used, which points at Wine rather than at the compositor.

## How it works

Three separate pieces have to line up.

### 1. Proton feature flags (NOT in this repo — see "Reproducibility gap")

Proton gates layered-window transparency behind opt-in flags added in
[GE PR #553](https://github.com/GloriousEggroll/proton-ge-custom/pull/553), with fixes in
[#716](https://github.com/GloriousEggroll/proton-ge-custom/pull/716) (perf) and
[#760](https://github.com/GloriousEggroll/proton-ge-custom/pull/760) (click-through).
Without them an overlay like HDT's renders its transparent regions as **opaque black** —
GE's own PR describes exactly that symptom.

Set on the Lutris game config for Hearthstone Deck Tracker:

```yaml
system:
  env:
    WINE_LAYERED_OVERLAY_ALPHA: '1'           # 32-bit ARGB visual -> real transparency
    WINE_LAYERED_OVERLAY_INPUT_SHAPE: '1'     # per-pixel input region, from the alpha channel
    WINE_LAYERED_OVERLAY_SHAPE_INTERVAL: '500'  # ms between alpha readbacks (default 32)
    PROTON_USE_XALIA: '0'                     # gamepad-UI bridge, not needed here
```

Requires **GE-Proton11-7 or newer** (PR #760 merged 2026-09-11, 11-7 released 2026-09-16).
Pinned explicitly via `custom_wine_path` rather than "GE-Proton (Latest)", because Lutris,
Steam and the installer scripts each resolve a generic "GE-Proton" differently and silently
drifted across three builds while debugging this.

The two modes are **not** interchangeable:

- `ALPHA` gives a real ARGB visual. This is the only one that produces actual transparency
  here. Its input region comes from reading back the alpha channel.
- `SHAPE` derives an X11 shape from non-black pixels. On XWayland it only ever worked for
  *input*: XWayland can map an X11 input shape onto a Wayland input region, but it cannot
  clip a Wayland surface to an X11 *bounding* shape, so the rendering half is ignored and
  the overlay stays black. Do not enable it expecting transparency.

`SHAPE_INTERVAL` only throttles the ALPHA-mode readback. Raising it from 32 ms reduces how
often the readback runs; it does not fix the stale-pixel bug.

### 2. Hyprland window rule (in this repo)

`config/hypr/hyprland.lua`, rule `hdt-overlay`:

- `no_blur` — the overlay covers the whole screen, so once it is genuinely transparent
  Hyprland blurs everything *behind* it, i.e. the game. Without this the game is unplayably
  blurry.
- `no_dim`, `no_shadow`, `opacity = 1.0` — same class of problem; the global
  `inactive_opacity = 0.92` otherwise fades the overlay.
- `move = { 0, 0 }` — it must sit exactly over the fullscreen game. Without it an accidental
  `SUPER` + drag moves the overlay and it does not snap back, even after restarting HDT.
- `no_follow_mouse` — hovering must not move focus to the overlay.

### 3. Global damage tracking (in this repo, and the reason this isn't merged)

`debug:damage_tracking = 0`.

The overlay is only repainted in damaged regions. With damage tracking on, **only the part
of the overlay under the mouse cursor is drawn** and the rest disappears. Forcing full
redraws fixes it completely.

This is a global compositor setting, not scoped to the game: every frame of every workspace
is fully redrawn, which costs power and GPU time on an always-on desktop. That trade-off is
the main blocker for merging.

## Reproducibility gap

The Proton flags and the Wine version pin live in
`~/.local/share/lutris/games/hearthstone-deck-tracker-standard-*.yml`, which is **outside
this repo** and is not restored by the bootstrap. A reinstall loses them.

Also outside the repo: the Wine prefix at `~/Games/battlenet`, and GE-Proton11-7 itself,
which was fetched manually with `protonup-qt` rather than declared in `configuration.nix`
(which declares `pkgs.proton-ge-bin`, a *different* build — currently GE-Proton11-1).

Before merging, at minimum:
- decide how the Lutris game config is managed declaratively, or document it in the README's
  "What to back up"
- reconcile the two GE-Proton builds so "GE-Proton" is unambiguous

## Things already ruled out

Do not re-test these; they had no effect on the black/transparency problem:

- HDT's own `UseHardwareAcceleration=false` in `config.xml`
- Wine registry `HKCU\Software\Microsoft\Avalon.Graphics\DisableHWAcceleration=1`
  (already set by the Lutris installer script)
- In-game fullscreen vs windowed, and Hyprland-forced fullscreen
- `PROTON_USE_XALIA=0` alone (kept anyway, it is harmless)
- A shared Wine *virtual desktop* (`explorer /desktop=...`) for game + tracker, as the
  Omarchy helper does: a second app mapping a window inside it reliably crashed the whole
  desktop with an X11 `BadWindow` error
- GE-Proton11-6 vs 11-7: the layered-overlay code is effectively identical, 11-7 only adds
  `layered_overlay_input_shape_enabled`. Stay on 11-7, it has the click-through fix.
- Hyprland's `_NET_WM_CM_S0` not being claimed: real, but Wine's X11 driver never consults
  that atom, so it is a red herring here.

## Next steps for the stale-pixel bug

1. `PROTON_USE_WAYLAND=1` — Proton's native Wayland driver bypasses XWayland and this whole
   shape/visual layer. Untried, and the entire problem class is an XWayland artifact.
2. [thaylorz/proton-ge-custom](https://github.com/thaylorz/proton-ge-custom/releases) — the
   author of the layered-overlay patches ships test builds; worth checking for newer
   layered-overlay work than what landed in 11-7.
3. Narrow `damage_tracking` — if Hyprland gains a per-window equivalent, the global setting
   (and the merge blocker) goes away.

## Related

- Upstream Omarchy helper: https://github.com/Smaddermand/hearthstone-hdt-omarchy
  (its README acknowledges overlay reliability as an unsolved limitation there too)
- Battle.net, Hearthstone and HDT all share the prefix `~/Games/battlenet` and are launched
  from Lutris. Launching them through Steam's Proton instead does not work: Steam's launcher
  waits for exclusive use of the prefix, so the second app blocks forever on `wineserver -w`.
