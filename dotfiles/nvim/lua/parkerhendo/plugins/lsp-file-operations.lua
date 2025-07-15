-- Install nvim-lsp-file-operations for file operations via lsp in the file tree
return {
	"antosha417/nvim-lsp-file-operations",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-tree/nvim-tree.lua",
	},
}
