local telescope = require("telescope")
local actions = require("telescope.actions")
local trouble = require("trouble.sources.telescope")

require("telescope").setup({
	defaults = {
		mappings = {
			i = {
				["<C-k>"] = actions.move_selection_previous,
				["<C-j>"] = actions.move_selection_next,
				["<C-t>"] = trouble.open,
				["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
				["<C-x>"] = actions.delete_buffer,
				["<esc>"] = actions.close,
			},
			n = {
				["<c-t>"] = trouble.open,
				["q"] = actions.close,
			},
		},
		pickers = {
			find_files = {
				theme = "dropdown",
			},
			buffers = {
				theme = "dropdown",
				sort_lastused = true,
			},
			live_grep = {
				theme = "dropdown",
			},
		},
		file_ignore_patterns = {
			"node_modules",
			"yarn.lock",
			".git",
		},
		hidden = true,
	},
})
