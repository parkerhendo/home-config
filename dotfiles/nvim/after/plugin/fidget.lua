require("fidget").setup({
	window = {
		relative = "editor", -- where to anchor, either "win" or "editor"
		blend = 0, -- &winblend for the window
		zindex = 2, -- the zindex value for the window
		border = "solid",
	},
})

vim.cmd([[
  highlight FidgetTask ctermfg=110 guifg=#FFFFFF
  highlight FidgetTitle ctermfg=110 guifg=#6cb6eb
]])
