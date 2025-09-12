return {
	"nvim-tree/nvim-tree.lua",
	cmd = "NvimTreeToggle",
	dependencies = {
		"nvim-tree/nvim-web-devicons",
	},
	opts = {
		git = {
			ignore = false,
		},
		filters = {
			dotfiles = false,
			custom = { "^.git$" },
		},
		update_focused_file = {
			enable = true,
		},
		renderer = {
			icons = {
				show = {
					folder_arrow = false,
				},
			},
		},
		view = {
			width = 40,
			float = {
				enable = false,
				quit_on_focus_loss = true,
			},
		},
	},
}
