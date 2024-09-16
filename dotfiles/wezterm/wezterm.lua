-- Pull in the wezterm API
local wezterm = require("wezterm")
local padding = 16
local act = wezterm.action

return {
	front_end = "WebGpu",
	font_size = 14,
	font = wezterm.font(
		"BerkeleyMono Nerd Font Mono Plus Font Awesome Plus Font Awesome Extension Plus Octicons Plus Power Symbols Plus Codicons Plus Pomicons Plus Font Logos",
		{ weight = 400, italics = false }
	),
	scrollback_lines = 10000,
	enable_tab_bar = false,
	line_height = 1.05,
	audible_bell = "Disabled",
	window_decorations = "RESIZE",
	adjust_window_size_when_changing_font_size = false,
	window_close_confirmation = "NeverPrompt",
	color_scheme = "Nord (Gogh)",
	default_cursor_style = "BlinkingUnderline",
	window_padding = {
		left = padding,
		right = padding,
		top = padding,
		bottom = padding,
	},
	initial_rows = 34,
	initial_cols = 134,
	pane_focus_follows_mouse = true,

	keys = {
		{ key = "k", mods = "CMD", action = act.ClearScrollback("ScrollbackAndViewport") },
		{ key = "LeftArrow", mods = "CMD", action = act.SendKey({ key = "Home" }) },
		{ key = "RightArrow", mods = "CMD", action = act.SendKey({ key = "End" }) },
		{ key = "LeftArrow", mods = "OPT", action = act.SendKey({ key = "b", mods = "ALT" }) },
		{ key = "RightArrow", mods = "OPT", action = act.SendKey({ key = "f", mods = "ALT" }) },
		{ key = "d", mods = "CMD", action = wezterm.action.SplitPane({ direction = "Down" }) },
		{ key = "d", mods = "CMD|SHIFT", action = wezterm.action.SplitPane({ direction = "Right" }) },
		{ key = "w", mods = "CMD", action = wezterm.action.CloseCurrentPane({ confirm = false }) },
		{ key = "p", mods = "CMD|SHIFT", action = wezterm.action.ActivateCommandPalette },
		{ key = "d", mods = "OPT", action = wezterm.action.ShowDebugOverlay },
		{ key = "Enter", mods = "CMD", action = wezterm.action.TogglePaneZoomState },
	},
}
