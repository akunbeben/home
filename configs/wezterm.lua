local wezterm = require("wezterm")
local config = wezterm.config_builder()

local function scheme_for_appearance(appearance)
	-- if appearance:find("Dark") then
	-- 	os.execute("bash -c 'echo mocha > ~/.config/nvim/theme-flavour'")
	-- 	return "Catppuccin Mocha"
	-- else
	-- 	os.execute("bash -c 'echo latte > ~/.config/nvim/theme-flavour'")
	-- 	return "Catppuccin Latte"
	-- end
	--
	return "Tokyo Night"
end

local function set_font(appearance)
	if appearance:find("Dark") then
		return wezterm.font("DankMono Nerd Font")
	else
		return wezterm.font("DankMono Nerd Font", { weight = "Bold" })
	end
end

config.automatically_reload_config = true

config.default_cwd = "/home/ben/Projects"

config.font = set_font(wezterm.gui.get_appearance())
config.font_size = 12
config.front_end = "WebGpu"
-- config.line_height = 1.25

config.color_scheme = scheme_for_appearance(wezterm.gui.get_appearance())
-- config.window_background_opacity = 0.96

config.enable_tab_bar = false
config.window_decorations = "NONE"

return config
