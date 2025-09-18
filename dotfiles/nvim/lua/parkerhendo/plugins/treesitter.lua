-- Install treesitter for better syntax highlighting

return {
	"nvim-treesitter/nvim-treesitter",
	build = ":TSUpdate",
	event = { "BufReadPost", "BufNewFile" },
	opts = {
		modules = {},
		auto_install = true,
		ignore_install = {},
		ensure_installed = {
			"c",
			"lua",
			"javascript",
			"typescript",
			"json",
			"tsx",
			"html",
			"css",
			"markdown",
			"rust",
			"bash",
		},
		sync_install = false,
		highlight = {
			enable = true,
		},
		indent = {
			enable = true,
			disable = { "ocaml", "ocaml_interface" },
		},
		autopairs = {
			enable = true,
		},
		playground = {
			enable = false,
		},
		autotag = {
			enable = true,
		},
		incremental_selection = {
			enable = false,
		},
		textobjects = {
			select = {
				enable = true,
				lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
				keymaps = {
					-- You can use the capture groups defined in textobjects.scm
					["aa"] = "@parameter.outer",
					["ia"] = "@parameter.inner",
					["af"] = "@function.outer",
					["if"] = "@function.inner",
					["ac"] = "@class.outer",
					["ic"] = "@class.inner",
				},
			},
			move = {
				enable = true,
				set_jumps = true, -- whether to set jumps in the jumplist
				goto_next_start = {
					["]m"] = "@function.outer",
					["]]"] = "@class.outer",
				},
				goto_next_end = {
					["]M"] = "@function.outer",
					["]["] = "@class.outer",
				},
				goto_previous_start = {
					["[m"] = "@function.outer",
					["[["] = "@class.outer",
				},
				goto_previous_end = {
					["[M"] = "@function.outer",
					["[]"] = "@class.outer",
				},
			},
		},
	},
}
