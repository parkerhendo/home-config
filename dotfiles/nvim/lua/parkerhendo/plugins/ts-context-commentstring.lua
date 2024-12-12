-- Install context-commentstring to enable jsx commenting is ts/js/tsx/jsx files
return {
	"JoosepAlviste/nvim-ts-context-commentstring",
	opts = {
		enable_autocmd = false,
		languages = {
			typescript = "// %s",
		},
	},
}
