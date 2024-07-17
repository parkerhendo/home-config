-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This table will hold the configuration.
local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then
	config = wezterm.config_builder()
end

-- This is where you actually apply your config choices

-- For example, changing the color scheme:
config.color_scheme = "Nord (base16)"

config.colors = {
	background = "#232730",
	cursor_bg = "#fff",
	cursor_border = "#4C566A",
}

config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "TITLE|RESIZE"
config.window_close_confirmation = "NeverPrompt"

config.font = wezterm.font_with_fallback({
	{ family = "JetBrains Mono", italic = false },
})
config.font_size = 14.0
config.line_height = 1.0
config.font_rules = {
	{
		intensity = "Normal",
		italic = true,
		font = wezterm.font_with_fallback({
			{ family = "JetBrains Mono", style = "Normal" },
		}),
	},
	{
		intensity = "Bold",
		italic = true,
		font = wezterm.font_with_fallback({
			{ family = "JetBrains Mono", italic = false },
		}),
	},
}

config.window_padding = {
	left = "16px",
	right = "16px",
	top = "0.5cell",
	bottom = "0cell",
}

config.disable_default_key_bindings = true

config.keys = {
	{
		key = "Enter",
		mods = "CTRL",
		action = wezterm.action.DisableDefaultAssignment,
	},
}

-- and finally, return the configuration to wezterm
return config
