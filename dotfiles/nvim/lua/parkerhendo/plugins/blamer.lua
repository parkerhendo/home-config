return {
	"APZelos/blamer.nvim",
	cmd = "BlamerToggle",
	config = function()
		vim.cmd([[let g:blamer_enabled = 1]])
		vim.cmd([[let g:blamer_delay = 500]])
		vim.cmd([[let g:blamer_show_in_visual_modes = 1]])
		vim.cmd([[let g:blamer_show_in_insert_modes = 0]])
	end,
}
