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
hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto-right", scale = 1, transform = 3 })
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
hl.on("hyprland.start", function()
    -- First image applies to every screen, the -o HDMI-A-1 one overrides the portrait screen.
    hl.exec_cmd("swaybg -m fill -i " .. wallpapers .. "wallpaper-landscape.jpg"
        .. " -o HDMI-A-1 -m fill -i " .. wallpapers .. "wallpaper-portrait.jpg")
    hl.exec_cmd("waybar")
    hl.exec_cmd("mako")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("nm-applet --indicator")
    -- 1Password in the tray: keeps the SSH agent and browser/CLI integration available
    hl.exec_cmd("1password --silent")
    -- Mark the left screen primary for X11 games (Battle.net, Wine).
    hl.exec_cmd("xrandr --output DP-1 --primary")
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

-- Don't lock or blank the screen while anything is fullscreen (games, video).
hl.window_rule({
    name  = "no-idle-when-fullscreen",
    match = { class = ".*" },
    idle_inhibit = "fullscreen",
})

-- Small utility windows float, centred.
hl.window_rule({
    name  = "float-utilities",
    match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol|blueman-manager|nm-connection-editor|nvidia-settings)$" },
    float  = true,
    center = true,
    size   = { 960, 640 },
})

-- 1Password's approval popups (e.g. "Access Requested" for SSH signing) share the main
-- app's window class/title, and can render too short to show their Allow/Deny buttons.
-- A floor, not a fixed size, so resizing the main app window freely still works.
hl.window_rule({
    name     = "1password-min-size",
    match    = { class = "^(1password)$" },
    min_size = { 450, 550 },
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

-- Screenshots: region -> clipboard, full screen -> ~/Pictures
-- Super+Shift+S for the region shot too, matching Windows/WSL muscle memory.
hl.bind("Print", hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy && notify-send "Screenshot copied"'))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy && notify-send "Screenshot copied"'))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd('mkdir -p ~/Pictures && grim ~/Pictures/screenshot-$(date +%F-%H%M%S).png && notify-send "Screenshot saved"'))

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
