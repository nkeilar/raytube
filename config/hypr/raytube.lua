-- raytube for Hyprland (Lua config): the TV desktop monitor rule and the keys.
-- install.sh links this file to ~/.config/hypr/raytube.lua; load it with
--   require("hypr.raytube")
-- at the end of ~/.config/hypr/hyprland.lua. Optional, set before that line:
--   raytube_tv_position = "auto-center-down"   -- where the TV sits (default: above)

-- The TV desktop is a headless output named "TV". raytube-tv writes its size
-- (1080p by default) so a config reload keeps it instead of resetting it.
local tv_size_file = io.open((os.getenv("HOME") or "") .. "/.local/state/raytube/tv-size", "r")
local tv_size = tv_size_file and tv_size_file:read("*l") or "1920x1080"
if tv_size_file then tv_size_file:close() end
hl.monitor({ output = "TV", mode = tv_size .. "@30", position = raytube_tv_position or "auto-center-up", scale = 1 })

-- Keys: two arrows for the everyday thing, one combo for the rest.
--   Super+Ctrl+Up / Down   send the focused window to the TV / bring it back
--   Super+Shift+T          TV mode: a cheat sheet appears, then one letter
local function bind(keys, description, command)
  hl.bind(keys, hl.dsp.exec_cmd(command), { description = description })
end
bind("SUPER + CTRL + UP", "TV: send window to the TV", "env RAYTUBE_NOTIFY=1 raytube-tv to-tv")
bind("SUPER + CTRL + DOWN", "TV: bring window back", "env RAYTUBE_NOTIFY=1 raytube-tv home")
bind("SUPER + SHIFT + T", "TV mode (then a letter)", "raytube-tv tv-mode")

-- TV mode: each letter runs `raytube-tv key <letter>`, which leaves TV mode
-- first; any other key just leaves, so letters never land in an app.
hl.define_submap("raytube-tv", function()
  for _, k in ipairs({ "s", "b", "n", "p", "l", "m", "f", "r", "y", "o", "a", "escape" }) do
    hl.bind(k, hl.dsp.exec_cmd("raytube-tv key " .. k))
  end
  hl.bind("catchall", hl.dsp.exec_cmd("raytube-tv key other"))
end)
