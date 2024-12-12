-- Install lsp
return {
	"neovim/nvim-lspconfig",
	dependencies = {
		-- Plugin and UI to automatically install LSPs to stdpath
		"williamboman/mason.nvim",
		"williamboman/mason-lspconfig.nvim",
		-- Install null-ls for diagnostics, code actions, and formatting
		"jose-elias-alvarez/null-ls.nvim",
		-- Install neodev for better nvim configuration and plugin authoring via lsp configurations
		"folke/neodev.nvim",
		-- Progress/Status update for LSP
		{ "j-hui/fidget.nvim", version = "v1.1.0" },
	},
}
