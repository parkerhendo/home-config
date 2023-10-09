require("nvim-tree").setup({
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
	view = {
		width = 45,
		float = {
			enable = false,
			quit_on_focus_loss = true,
		},
	},
})
