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
| Whole overlay stays drawn (not just under the cursor) | yes, via the per-game `damage_tracking` hook |
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

### 3. Damage tracking, toggled per game (in this repo)

The overlay is only repainted in damaged regions. With Hyprland's damage tracking on,
**only the part of the overlay under the mouse cursor is drawn** and the rest disappears.
`debug:damage_tracking = 0` forces full redraws and fixes it completely.

That is a global compositor setting though: every frame of every workspace gets fully
redrawn, which wastes power the 99% of the time no game is running. So rather than setting
it globally, `home.nix` installs `~/.local/bin/hdt-damage-tracking` and Lutris flips it
around the game:

```yaml
system:
  prelaunch_command: /home/jlor/.local/bin/hdt-damage-tracking off
  prelaunch_wait: true
  postexit_command: /home/jlor/.local/bin/hdt-damage-tracking on
```

Three gotchas that cost time:

- Lutris checks `path_exists(command_array[0])` before running a hook, so the command must
  be a **real file at an absolute path**. A bare `hyprctl ...` is silently skipped.
- Lutris runs hooks in its own sandbox, which does not inherit `HYPRLAND_INSTANCE_SIGNATURE`.
  The script falls back to the single running instance from `$XDG_RUNTIME_DIR/hypr`.
- `prelaunch_wait` defaults to **false**, i.e. Lutris fires the hook and starts the game
  immediately. The overlay then maps before damage tracking is off, misses its first full
  paint, and only redraws where the cursor goes — the exact symptom the hook is meant to
  prevent. Set it to `true`.

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

### `PROTON_USE_WAYLAND=1` — tested, and a dead end

Proton's native Wayland driver looked like the obvious fix: no XWayland, no XShape, and no
alpha readback (the suspected cause of the stale pixels). It half worked and then hit a wall
that configuration cannot move.

Tested on both the Battle.net and HDT Lutris entries. Results:

- every window became native Wayland (`xwayland: false` in `hyprctl clients`), game included
- the overlay was transparent and click-through
- **the overlay's widgets were completely dead**, and
- the overlay could not place itself: it came up as a small window in a corner. Wayland does
  not let a client set its own position, so it only lined up after being moved and resized by
  hand, which would not survive a restart.

Why the widgets are dead, and why no flag fixes it:

- `winewayland.so` contains **no reference to the `WINE_LAYERED_OVERLAY_*` flags at all** —
  they are `winex11`-only. There is nothing to tune on this path.
- HDT's overlay is deliberately click-through: *"The Battlegrounds in-game overlay uses a
  click-through WS_EX_TRANSPARENT window model"* (`Controls/Overlay/Battlegrounds/OverlayButton.cs`).
  It then polls the **global cursor position** (`GetCursorPos` in `Utility/User32.cs`,
  `Windows/OverlayWindow.MouseOverDetection.cs`) and does its own hit-testing to decide when
  something should be interactive.
- Wine's Wayland driver correctly sets an empty input region for
  `WS_EX_TRANSPARENT | WS_EX_LAYERED` (Wine MR !9204), matching Windows.
- But Wayland deliberately does not expose a global pointer position to clients, and with an
  empty input region the surface receives no pointer events at all — so HDT can never learn
  that the cursor is over a widget.

Both layers are behaving correctly; the combination simply cannot work. X11 works precisely
because `XQueryPointer` reports the pointer position regardless of input regions. Making the
Wayland path work would need HDT to redesign its overlay, or a Wayland protocol that does not
exist by design. **Do not retry this without one of those changing.**

## Test plan for the stale-pixel bug

**We do not know the cause.** The same overlay demonstrably worked on the previous Omarchy
install via `omarchy-hdt`, so it is solvable, and the useful question is *which difference
matters* — not which theory sounds right. The steps below are ordered most- to least-likely
to produce a working overlay. Stop at the first one that works, then diff it against the
current setup to find the responsible difference.

Note on that earlier success: Omarchy ran Wine on **XWayland inside a Wayland session**.
`omarchy-hdt` never sets `PROTON_USE_WAYLAND`, so it used `winex11.drv` — the same path as
the current setup. "It worked on Wayland" is not in conflict with the Wayland findings above.

Baseline to compare against: transparency, click-through and clickable widgets all work;
stale content persists when switching tabs inside the overlay.

### 1. Run `omarchy-hdt` as designed

The tool that is known to have worked, used the way it was intended rather than cherry-picked.
Self-contained: its own prefix (`~/Games/hearthstone-hdt-omarchy`), its own Proton. Does not
touch the existing Battle.net install.

```sh
python3 hdt.py install     # from a clone of Smaddermand/hearthstone-hdt-omarchy
```

Needs `GE-Proton11-6-x86_64` in `~/.local/share/Steam/compatibilitytools.d/`.

If the overlay is clean here, diff its prefix and launch environment against ours — the
answer is then one of the differences in step 2-5, identified by evidence rather than guesswork.

### 2. GE-Proton11-6 instead of 11-7

Cheapest single-variable change from the current working-ish state: point
`custom_wine_path` at 11-6 in the Lutris config. `omarchy-hdt` pins 11-6 explicitly, and
the layered-overlay code does differ slightly (11-7 adds `layered_overlay_input_shape_enabled`).
Earlier reasoning dismissed the version difference as implausible; that was an assumption,
not a measurement.

### 3. A separate, clean Wine prefix for HDT

`omarchy-hdt` clones the Battle.net prefix and runs HDT from its own copy. HDT and the game
have shared one prefix here throughout. The current prefix has also accumulated a lot of
history: three different Proton builds, a `wineboot -u` repair, and a batch of system32
files that had been copied read-only from the Nix store and needed `chmod u+w`.

### 4. Materialise the Windows DLLs, as `prepare_dotnet_files` does

`omarchy-hdt` walks `drive_c/windows`, replaces every symlink with a real file and makes
everything user-writable, on the grounds that "native .NET replaces framework and system
DLLs; never write through Proton links". We hit a related symptom (the read-only `.nls`
files) and fixed only the permissions, not the symlinks.

### 5. Virtual desktop, in a *separate* prefix

`explorer /desktop=HearthstoneHDT,2560x1440`. This was tried in the **shared** prefix, where
a second app mapping a window inside it crashed with an X11 `BadWindow` error. Untested in a
dedicated prefix, which is how `omarchy-hdt` actually uses it.

### 6. Gather evidence, if none of the above works

`WINEDEBUG=+x11drv` around a tab switch, grepping for `layered overlay` and
`update_layered_overlay_shape`, should show whether Wine redraws the full surface or only a
dirty rectangle. That distinguishes "Wine never clears the buffer" from "WPF only submits
dirty rects", and is the minimum needed before filing anything upstream with
[thaylorz/proton-ge-custom](https://github.com/thaylorz/proton-ge-custom), who wrote these
patches.

Not an option: downgrading HDT. 1.58.10 is still on disk and predates the regression window,
but older HDT builds do not work with the current Hearthstone version.

## Related

- Upstream Omarchy helper: https://github.com/Smaddermand/hearthstone-hdt-omarchy
  (its README acknowledges overlay reliability as an unsolved limitation there too)
- Battle.net, Hearthstone and HDT all share the prefix `~/Games/battlenet` and are launched
  from Lutris. Launching them through Steam's Proton instead does not work: Steam's launcher
  waits for exclusive use of the prefix, so the second app blocks forever on `wineserver -w`.
