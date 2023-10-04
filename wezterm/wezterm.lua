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
config.color_scheme = "nord"

config.colors = {
	background = "#232730",
	cursor_bg = "#434c5e",
	cursor_border = "#4C566A",
}

config.font = wezterm.font_with_fallback({
	{ family = "JetBrains Mono NL", italic = false },
})
config.font_size = 14.0
config.line_height = 1.0
config.font_rules = {
	{
		intensity = "Normal",
		italic = true,
		font = wezterm.font_with_fallback({
			{ family = "JetBrains Mono NL", style = "Normal" },
		}),
	},
	{
		intensity = "Bold",
		italic = true,
		font = wezterm.font_with_fallback({
			{ family = "JetBrains Mono NL", italic = false },
		}),
	},
}

config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "TITLE|RESIZE"
config.window_close_confirmation = "NeverPrompt"

config.window_padding = {
	left = "24px",
	right = "24px",
	top = "1.5cell",
	bottom = "0.5cell",
}

-- and finally, return the configuration to wezterm
return config
