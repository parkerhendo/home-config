require("fidget").setup({
	notification = {
		window = {
			winblend = 0,
		},
	},
})

vim.cmd([[
  highlight FidgetTask ctermfg=110 guifg=#FFFFFF
  highlight FidgetTitle ctermfg=110 guifg=#6cb6eb
]])
