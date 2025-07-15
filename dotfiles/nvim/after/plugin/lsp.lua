local null_ls = require("null-ls")
local map_lsp_keybinds = require("parkerhendo.keymaps").map_lsp_keybinds

-- Use neodev to configure lua_ls in nvim directories - must load before lspconfig
require("neodev").setup()

-- Setup mason so it can manage 3rd party LSP servers
require("mason").setup({
	ui = {
		border = "rounded",
	},
})

-- Configure mason to auto install servers
require("mason-lspconfig").setup({
	ensure_installed = {
		"cssls",
		"tailwindcss",
		"lua_ls",
		"ts_ls",
		"rust_analyzer",
	},
	automatic_installation = true,
})

-- Configure mason-null-ls to auto install formatters and linters
require("mason-null-ls").setup({
	ensure_installed = {
		-- Formatters
		"stylua", -- Lua formatter
		"black", -- Python formatter
		"isort", -- Python import sorter
		"prettier", -- Web formatter
		-- Linters
		"flake8", -- Python linter
		"mypy", -- Python type checker
	},
	automatic_installation = true,
})

-- Override tsserver diagnostics to filter out specific messages
local messages_to_filter = {
	"This may be converted to an async function.",
	"'_Assertion' is declared but never used.",
	"'__Assertion' is declared but never used.",
	"The signature '(data: string): string' of 'atob' is deprecated.",
	"The signature '(data: string): string' of 'btoa' is deprecated.",
}

local function tsserver_on_publish_diagnostics_override(_, result, ctx, config)
	local filtered_diagnostics = {}

	for _, diagnostic in ipairs(result.diagnostics) do
		local found = false
		for _, message in ipairs(messages_to_filter) do
			if diagnostic.message == message then
				found = true
				break
			end
		end
		if not found then
			table.insert(filtered_diagnostics, diagnostic)
		end
	end

	result.diagnostics = filtered_diagnostics

	vim.lsp.diagnostic.on_publish_diagnostics(_, result, ctx, config)
end

-- LSP servers to install
local servers = {
	bashls = {},
	cssls = {},
	graphql = {},
	html = {},
	jsonls = {},
	lua_ls = {},
	marksman = {},
	ocamllsp = {},
	prismals = {},
	pyright = {},
	solidity = {},
	sqlls = {},
	tailwindcss = {},
	ts_ls = {
		settings = {
			experimental = {
				enableProjectDiagnostics = true,
			},
		},
		handlers = {
			["textDocument/publishDiagnostics"] = vim.lsp.with(tsserver_on_publish_diagnostics_override, {}),
		},
	},
	rust_analyzer = {},
	yamlls = {},
}

-- Default handlers for LSP
local default_handlers = {
	["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" }),
	["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" }),
}

-- nvim-cmp supports additional completion capabilities
local capabilities = vim.lsp.protocol.make_client_capabilities()
local default_capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

local on_attach = function(_client, buffer_number)
	-- Pass the current buffer to map lsp keybinds
	map_lsp_keybinds(buffer_number)

	-- Create a command `:Format` local to the LSP buffer
	vim.api.nvim_buf_create_user_command(buffer_number, "Format", function(_)
		vim.lsp.buf.format({
			filter = function(format_client)
				-- Use Prettier to format TS/JS if it's available
				return format_client.name ~= "ts_ls" or not null_ls.is_registered("prettier")
			end,
		})
	end, { desc = "LSP: Format current buffer with LSP" })
end

-- Iterate over our servers and set them up
for name, config in pairs(servers) do
	require("lspconfig")[name].setup({
		on_attach = on_attach,
		capabilities = default_capabilities,
		settings = config.settings,
		handlers = vim.tbl_deep_extend("force", {}, default_handlers, config.handlers or {}),
	})
end

-- Configure LSP linting, formatting, diagnostics, and code actions
local formatting = null_ls.builtins.formatting
local diagnostics = null_ls.builtins.diagnostics
local code_actions = null_ls.builtins.code_actions

-- ESLint integration from none-ls-extras
local eslint_diagnostics = require("none-ls.diagnostics.eslint")
local eslint_code_actions = require("none-ls.code_actions.eslint")

null_ls.setup({
	sources = {
		-- Formatting
		formatting.stylua,
		formatting.prettier.with({
			condition = function(utils)
				return utils.root_has_file({ ".prettierrc", ".prettierrc.js", ".prettierrc.json" })
			end,
		}),
		formatting.black,
		formatting.isort,
		formatting.rustfmt,
		formatting.ocamlformat,

		-- Diagnostics
		eslint_diagnostics.with({
			condition = function(utils)
				return utils.root_has_file({ ".eslintrc.js", ".eslintrc.cjs", ".eslintrc.json" })
			end,
		}),
		diagnostics.flake8,
		diagnostics.mypy,

		-- Code Actions
		eslint_code_actions.with({
			condition = function(utils)
				return utils.root_has_file({ ".eslintrc.js", ".eslintrc.cjs", ".eslintrc.json" })
			end,
		}),
		code_actions.gitsigns,
	},
})

-- Configure borderd for LspInfo ui
require("lspconfig.ui.windows").default_options.border = "rounded"

-- Configure diagostics border
vim.diagnostic.config({
	float = {
		border = "rounded",
	},
})
