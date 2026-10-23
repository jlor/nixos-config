-- ~/.config/hypr/hyprland.lua  (deployed by home-manager from the nixos-config repo)
-- Hyprland 0.55+ Lua config. Docs: https://wiki.hypr.land
-- Palette: Catppuccin Mocha, mauve accent.

local home = os.getenv("HOME")
local wallpapers = home .. "/.local/share/wallpapers/"

local terminal    = "kitty"
local menu        = "walker"
local fileManager = "nautilus"
local mainMod     = "SUPER"

----------------
--- MONITORS ---
----------------
-- Ports from `hyprctl monitors`: DP-1 = Samsung C32JG5x (primary, left),
-- HDMI-A-1 = Lenovo T27h-2L (portrait, right). The login screen (configuration.nix)
-- and Waybar (config/waybar/config.jsonc) use the same names.
-- Left: primary, landscape, highest refresh rate.
hl.monitor({ output = "DP-1", mode = "highrr", position = "0x0", scale = 1 })
-- Right: portrait. transform 1 = 90°; use 3 if it comes out upside down.
-- Position is explicit rather than auto-right so the bottom edges line up: rotated
-- it is 1440x2560, so y = 1440 (DP-1's height) - 2560 = -1120 puts its bottom at
-- the same line as DP-1's. x = 2560 is just right of DP-1.
hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "2560x-1120", scale = 1, transform = 3 })
-- Anything else you plug in.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- Workspaces 1-5 on the main screen, 6-9 on the vertical one.
for i = 1, 5 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "DP-1", default = (i == 1) })
end
for i = 6, 9 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "HDMI-A-1", default = (i == 6) })
end

-----------------
--- AUTOSTART ---
-----------------
-- Where the autostarted apps live. Workspace 6 is the portrait screen's default
-- (see the workspace rules above); with only one screen connected it falls back
-- onto that one, so the apps still come up together on their own workspace.
local appWorkspace  = 6 -- Firefox + Discord, portrait screen
local termWorkspace = 1 -- terminal, main screen

-- Poll until a window of `class` is mapped, then call fn(). Gives up after ~30s
-- so an app that is slow, missing or crashing on launch can't stall the rest of
-- the sequence.
local function whenMapped(class, fn)
    local tries = 60
    local function poll()
        if #hl.get_windows({ class = class, mapped = true }) > 0 then
            fn()
        elseif tries > 0 then
            tries = tries - 1
            hl.timer(poll, { timeout = 500, type = "oneshot" })
        end
    end
    hl.timer(poll, { timeout = 500, type = "oneshot" })
end

-- Put Firefox above Discord.
--
-- Plain window rules can't express this: dwindle picks which *side* of a split a
-- new window takes from the cursor position (force_split is 0), and at login the
-- cursor sits on DP-1, nowhere near the portrait screen. Discord is then as
-- likely to open above Firefox as below it. Rather than change force_split for
-- every window everywhere, check the result once and swap if it came out upside
-- down.
local function stackApps(tries)
    tries = tries or 3
    local firefox = hl.get_windows({ class = "firefox", workspace = appWorkspace })[1]
    local discord = hl.get_windows({ class = "discord" })[1]
    if not (firefox and discord) then return end

    -- Discord is put here by the window rule in WINDOW RULES. If that ever fails
    -- it must not leave this function silently doing nothing, which is how the
    -- first version of this shipped a Discord stranded on the main screen: it
    -- looked for Discord only on workspace 6, found none, and returned happy.
    -- Move it and come back rather than giving up.
    if (discord.workspace and discord.workspace.id) ~= appWorkspace then
        if tries <= 0 then return end
        hl.dispatch(hl.dsp.window.move({ window = discord, workspace = appWorkspace }))
        hl.dispatch(hl.dsp.focus({ workspace = termWorkspace }))
        hl.timer(function() stackApps(tries - 1) end, { timeout = 500, type = "oneshot" })
        return
    end

    -- Firefox sitting lower than Discord means they came out the wrong way up.
    -- Swap the *Firefox* window upwards, not Discord: in this situation Discord
    -- is already the top tile, so asking it to move up finds nothing to swap
    -- with and the correction quietly does nothing.
    if firefox.at.y > discord.at.y then
        hl.dispatch(hl.dsp.focus({ window = firefox }))
        hl.dispatch(hl.dsp.window.swap({ direction = "up" }))
        -- Swapping needs the window focused, which drags focus to the portrait
        -- screen. Put it back where the "silent" launches left it.
        hl.dispatch(hl.dsp.focus({ workspace = termWorkspace }))
    end
end

hl.on("hyprland.start", function()
    -- First image applies to every screen, the -o HDMI-A-1 one overrides the portrait screen.
    hl.exec_cmd("swaybg -m fill -i " .. wallpapers .. "wallpaper-landscape.jpg"
        .. " -o HDMI-A-1 -m fill -i " .. wallpapers .. "wallpaper-portrait.jpg")
    hl.exec_cmd("waybar")
    hl.exec_cmd("mako")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("nm-applet --indicator")
    -- 1Password in the tray: keeps the SSH agent and browser/CLI integration available.
    -- Forced onto XWayland: 1Password's native-Wayland approval popups (e.g. "Access
    -- Requested" for SSH signing) render too small to show their Allow/Deny buttons, a
    -- known upstream regression (1password.community/discussions/developers/
    -- 1password-fails-to-prompt-for-approval-when-using-hyprland/147361). XWayland
    -- windows size correctly like any X11 app. The NixOS-wrapped binary hardcodes
    -- --ozone-platform-hint=auto (ignoring $ELECTRON_OZONE_PLATFORM_HINT) whenever
    -- NIXOS_OZONE_WL is set, so override it with an explicit CLI flag, not an env var.
    hl.exec_cmd("1password --ozone-platform=x11 --silent")
    -- Mark the left screen primary for X11 games (Battle.net, Wine).
    hl.exec_cmd("xrandr --output DP-1 --primary")

    -- Apps. The second argument is a launch rule, applied to the window this
    -- command maps, so it only places *these* windows: opening Firefox by hand
    -- later still puts it wherever you are. Discord is the exception and is
    -- placed by a plain window rule instead -- see WINDOW RULES for why.
    hl.exec_cmd(terminal, { workspace = termWorkspace .. " silent" })
    -- --hideStart sends ZapZap straight to the tray instead of opening a window.
    -- Passed on the command line rather than relying on its own "Start minimized"
    -- setting, which lives in ~/.config/ZapZap/ZapZap.conf, outside this repo.
    hl.exec_cmd("zapzap --hideStart")
    hl.exec_cmd("firefox", { workspace = appWorkspace .. " silent" })

    -- Discord only once Firefox has a window, so it splits Firefox's tile
    -- instead of racing it for the empty workspace.
    whenMapped("firefox", function()
        hl.exec_cmd("discord")
        -- Stacking only makes sense on the portrait screen. On a single
        -- landscape screen dwindle splits side by side instead, and two short
        -- wide windows are worse than the order it picks itself.
        if hl.get_monitor("HDMI-A-1") then
            whenMapped("discord", function()
                -- A beat for the new tile to settle before reading its position.
                hl.timer(stackApps, { timeout = 500, type = "oneshot" })
            end)
        end
    end)
end)

-------------------
--- ENVIRONMENT ---
-------------------
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("XCURSOR_THEME", "catppuccin-mocha-dark-cursors")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

---------------------
--- LOOK AND FEEL ---
---------------------
hl.config({
    general = {
        gaps_in     = 6,
        gaps_out    = 12,
        border_size = 2,
        col = {
            active_border   = { colors = { "rgba(cba6f7ff)", "rgba(89b4faff)" }, angle = 45 },
            inactive_border = "rgba(313244aa)",
        },
        resize_on_border = true,
        allow_tearing    = true, -- lets games opt in to tearing for lower input lag
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 12,
        rounding_power = 2,
        active_opacity   = 1.0,
        inactive_opacity = 0.92,

        shadow = {
            enabled      = true,
            range        = 20,
            render_power = 3,
            color        = 0xcc11111b,
        },

        blur = {
            enabled  = true,
            size     = 8,
            passes   = 3,
            vibrancy = 0.17,
        },
    },

    animations = { enabled = true },

    dwindle = { preserve_split = true },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        vrr                     = 2, -- adaptive sync for fullscreen games
    },

    cursor = {
        default_monitor = "DP-1", -- cursor starts on the main screen
    },

    input = {
        kb_layout     = "dk",
        kb_options    = "ctrl:nocaps", -- Caps Lock acts as Ctrl
        follow_mouse  = 1,
        accel_profile = "flat",        -- raw mouse input for games
        sensitivity   = 0,
    },
})

-- Animation curves (Hyprland defaults: smooth, springy windows)
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}    } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}  } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })

--------------------
--- WINDOW RULES ---
--------------------
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- Steam games may tear in fullscreen: lowest input lag.
hl.window_rule({
    name  = "games-allow-tearing",
    match = { class = "^(steam_app_.*)$" },
    immediate = true,
})

-- SimHub raises a window of its own the moment it detects a running game, and
-- a newly mapped window takes focus. Keyboard input goes to whatever the
-- compositor has focused, so mid-session the keys quietly start going to
-- SimHub instead of the game -- and in VR there is no way to notice: the
-- headset shows the track while what you type lands on the desktop.
--
-- no_focus only stops it taking focus when it maps. Clicking it still focuses
-- it, so SimHub stays usable; it just can't take the keyboard unasked.
hl.window_rule({
    name  = "simhub-no-focus-steal",
    match = { class = "^simhubwpf\\.exe$" },
    no_focus = true,
})

-- Don't lock or blank the screen while anything is fullscreen (games, video).
hl.window_rule({
    name  = "no-idle-when-fullscreen",
    match = { class = ".*" },
    idle_inhibit = "fullscreen",
})

-- Discord always lives on the portrait screen, next to Firefox (see AUTOSTART).
--
-- This is a plain window rule rather than a launch rule on the exec, because a
-- launch rule is tied to the exact pid Hyprland spawned and is spent on the
-- first window that pid maps. Discord's first window isn't the one you end up
-- looking at, so by the time the real window appeared the rule was gone and it
-- opened on whatever workspace was active. Measured: a launch rule survives a
-- 25s delay fine, so it isn't a timeout -- it's the window it attaches to.
--
-- Safe to apply globally here in a way it wouldn't be for Firefox: Discord is
-- single-instance, so there is only ever one window this can catch.
hl.window_rule({
    name  = "discord-on-portrait-screen",
    -- initial_class, not class: it's fixed at map time, so an Electron app that
    -- renames its class after the window appears can't slip past the rule.
    match = { initial_class = "^discord$" },
    workspace = appWorkspace .. " silent",
})

-- Small utility windows float, centred.
hl.window_rule({
    name  = "float-utilities",
    match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol|blueman-manager|nm-connection-editor|nvidia-settings)$" },
    float  = true,
    center = true,
    size   = { 960, 640 },
})

-- Frosted glass behind the bar, launcher (Walker) and notifications.
hl.layer_rule({ match = { namespace = "waybar" },        blur = true, ignore_alpha = 0.1 })
hl.layer_rule({ match = { namespace = "walker" },        blur = true, ignore_alpha = 0.1 })
hl.layer_rule({ match = { namespace = "notifications" }, blur = true, ignore_alpha = 0.1 })

-------------------
--- KEYBINDINGS ---
-------------------
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Space",  hl.dsp.exec_cmd(menu))                       -- launcher (Omarchy style)
hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + Q",      hl.dsp.window.close())
hl.bind(mainMod .. " + F",      hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mainMod .. " + V",      hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + L",      hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("walker -m menus:power"))   -- power menu
hl.bind(mainMod .. " + K",      hl.dsp.exec_cmd("walker -m menus:keybinds")) -- keybinds cheat sheet
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exit())

-- Walker modes: clipboard history and emoji/symbols
hl.bind(mainMod .. " + C",         hl.dsp.exec_cmd("walker -m clipboard"))
hl.bind(mainMod .. " + CTRL + E",  hl.dsp.exec_cmd("walker -m symbols"))

-- Screenshots (hyprshot): drag a region, point at a window, or pick a monitor.
-- Super+Shift+S for the region shot too, matching Windows/WSL muscle memory.
--
-- Region goes to the clipboard only. It's the one used constantly for pasting
-- into a chat, and saving every one of those just fills ~/Pictures with files
-- you can't tell apart. Window and monitor shots are the deliberate ones, so
-- they're kept.
--
-- -o is passed explicitly: left to itself hyprshot falls back to $HOME, not
-- ~/Pictures, when XDG_PICTURES_DIR is unset (it is here). It mkdir -p's the
-- directory itself, so there's nothing to create first.
-- -z freezes the screen while selecting, so menus and tooltips stay put.
local shotDir = '-o "$HOME/Pictures"'

hl.bind("Print",                     hl.dsp.exec_cmd('hyprshot -z -m region --clipboard-only'))
hl.bind(mainMod .. " + SHIFT + S",   hl.dsp.exec_cmd('hyprshot -z -m region --clipboard-only'))
hl.bind(mainMod .. " + Print",       hl.dsp.exec_cmd('hyprshot -z -m window ' .. shotDir))
hl.bind(mainMod .. " + SHIFT + Print", hl.dsp.exec_cmd('hyprshot -m output ' .. shotDir))

-- Annotate before sharing: grab a region, open it in satty (arrows, boxes, blur).
-- --raw pipes the image straight through, so nothing hits the disk until you save.
hl.bind(mainMod .. " + CTRL + S", hl.dsp.exec_cmd(
  'hyprshot -z -m region --raw | satty --filename - ' ..
  '--output-filename "$HOME/Pictures/annotated-$(date +%F-%H%M%S).png"'))

-- Focus: arrows
for key, dir in pairs({ left = "left", right = "right", up = "up", down = "down" }) do
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = dir }))
end

-- Move windows
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(mainMod .. " + SHIFT + " .. dir, hl.dsp.window.move({ direction = dir }))
end

-- Workspaces 1-9
for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- Mouse: SUPER + drag to move / right-drag to resize
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Media keys
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause",       hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",        hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
