local wezterm = require("wezterm")
local padding = 16
local act = wezterm.action

---Return the suitable argument depending on the appearance
---@param arg { light: any, dark: any } light and dark alternatives
---@return any
local function depending_on_appearance(arg)
	local appearance = wezterm.gui.get_appearance()
	if appearance:find("Dark") then
		return arg.dark
	else
		return arg.light
	end
end

return {
	window_background_opacity = 0.6, -- hack to get the background color to match my custom nord theme...should probably fix properly with a custom theme at some point.
	macos_window_background_blur = 100,
	color_scheme = "nordfox",
	front_end = "WebGpu",
	font_size = 14,
	font = wezterm.font(
		"BerkeleyMono Nerd Font Mono Plus Font Awesome Plus Font Awesome Extension Plus Octicons Plus Power Symbols Plus Codicons Plus Pomicons Plus Font Logos",
		{ weight = 400, italic = false }
	),
	scrollback_lines = 10000,
	enable_tab_bar = false,
	line_height = 1.05,
	audible_bell = "Disabled",
	window_decorations = "RESIZE|TITLE",
	pane_focus_follows_mouse = true,
	adjust_window_size_when_changing_font_size = false,
	window_close_confirmation = "NeverPrompt",
	default_cursor_style = "BlinkingBlock",
	cursor_blink_rate = 800,
	cursor_thickness = 0.5,
	window_padding = {
		left = padding,
		right = padding,
		top = padding,
		bottom = padding,
	},
	use_fancy_tab_bar = true,
	tab_max_width = 32,
	colors = {
		tab_bar = {
			active_tab = depending_on_appearance({
				light = { fg_color = "#f8f8f2", bg_color = "#209fb5" },
				dark = { fg_color = "#6c7086", bg_color = "#74c7ec" },
			}),
		},
	},
}
