-- lualine
local nord1 = "#232730"
local nord2 = "#2e3440"
local nord3 = "#3b4252"
local nord5 = "#e5e9f0"
local nord6 = "#eceff4"
local nord7 = "#8fbcbb"
local nord8 = "#88c0d0"
local nord14 = "#ebcb8b"

local custom_nord = require("lualine.themes.nord")

custom_nord.normal.a.fg = nord1
custom_nord.normal.a.bg = nord7
custom_nord.normal.b.fg = nord5
custom_nord.normal.b.bg = nord2
custom_nord.normal.c.fg = nord5
custom_nord.normal.c.bg = nord3

custom_nord.insert.a.fg = nord1
custom_nord.insert.a.bg = nord6

custom_nord.visual.a.fg = nord1
custom_nord.visual.a.bg = nord7

custom_nord.replace.a.fg = nord1
custom_nord.replace.a.bg = nord14

custom_nord.inactive.a.fg = nord1
custom_nord.inactive.a.bg = nord7
custom_nord.inactive.b.fg = nord5
custom_nord.inactive.b.bg = nord1
custom_nord.inactive.c.fg = nord5
custom_nord.inactive.c.bg = nord2

require("lualine").setup({
	options = {
		theme = custom_nord,
		component_separators = { left = "·" },
	},
	sections = {
		lualine_a = { "mode" },
		lualine_b = { "branch", "diff", "diagnostics" },
		lualine_c = { { "filename", path = 1 } },
		lualine_x = { "filetype" },
		lualine_y = { "progress" },
		lualine_z = { "location" },
	},
	inactive_sections = {
		lualine_a = {},
		lualine_b = {},
		lualine_c = { { "filename", path = 1 } },
		lualine_x = { "location" },
		lualine_y = {},
		lualine_z = {},
	},
})
