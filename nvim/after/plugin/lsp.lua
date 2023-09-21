local null_ls = require("null-ls")
-- local map_lsp_keybinds = require("parkerhendo.keymaps").map_lsp_keybinds 
local keymap = vim.api.nvim_set_keymap

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
	automatic_installation = { exclude = { "ocamllsp" } },
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

-- servers
local servers = {
  bashls = {},
  cssls = {},
  html = {},
  clojure_lsp = {},
  eslint = {},
  lua_ls = {},
  ocamllsp = {},
  pyright = {},
  rust_analyzer = {
    settings = {
      ["rust-analyzer"] = {
        checkOnSave = {
          command = "clippy",
        },
      },
    },
  },
  tsserver = {
    settings = {
      experimental = {
        enableProjectDiagnostics = true,
      }
    },
    handlers = {
			["textDocument/publishDiagnostics"] = vim.lsp.with(tsserver_on_publish_diagnostics_override, {}),
		},
  },
  tailwindcss = {},
}

-- lspconfig

vim.diagnostic.config {
  underline = { severity = vim.diagnostic.severity.ERROR },
  signs = { severity = vim.diagnostic.severity.ERROR },
  virtual_text = { severity = vim.diagnostic.severity.ERROR }
}


-- filter out node_modules/@types/react/index.d.ts results when jumping to definitions
local function filter(arr, fn)
  if type(arr) ~= "table" then
    return arr
  end
  
  local filtered = {}
  for k, v in pairs(arr) do
    if fn(v, k, arr) then
      table.insert(filtered, v)
    end
  end

  return filtered
end

local function filterReactDTS(value)
  return string.match(value.uri, 'react/index.d.ts') == nil
end

-- default handlers
local default_handlers = {
  ["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" }),
	["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" }),
}


-- nvim-cmp supports additional completion capabilities
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

local on_attach = function(client, buffer_number)
  vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')
  map_lsp_keybinds(buffer_number)
 --  vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, { desc = "LSP: [R]e[n]ame", buffer = buffer_number, noremap = true })
 --  vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, { desc = "LSP: [C]ode [A]ction", buffer = buffer_number, noremap = true })
 --  vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { desc = "LSP: [G]o to [D]efinition", buffer = buffer_number, noremap = true })
	--
 --  -- Telescope LSP keybinds --
	-- vim.keymap.set(
	-- 	'n', "gr",
	-- 	require("telescope.builtin").lsp_references,
	-- 	{ desc = "LSP: [G]oto [R]eferences", buffer = buffer_number, noremap = true }
	-- )
	--
	-- vim.keymap.set(
	-- 	'n', "gi",
	-- 	require("telescope.builtin").lsp_implementations,
	-- 	{ desc = "LSP: [G]oto [I]mplementation", buffer = buffer_number, noremap = true }
	-- )
	--
	-- vim.keymap.set(
	-- 	'n', "<leader>bs",
	-- 	require("telescope.builtin").lsp_document_symbols,
	-- 	{ desc = "LSP: [B]uffer [S]ymbols", buffer = buffer_number, noremap = true }
	-- )
	--
	-- vim.keymap.set(
	-- 	'n', "<leader>ps",
	-- 	require("telescope.builtin").lsp_workspace_symbols,
	-- 	{ desc = "LSP: [P]roject [S]ymbols", buffer = buffer_number, noremap = true }
	-- )
	--
 --  vim.keymap.set('n', "K", vim.lsp.buf.hover, { desc = "LSP: Hover Documentation", buffer = buffer_number, noremap = true })
	-- vim.keymap.set('n', "<leader>k", vim.lsp.buf.signature_help, { desc = "LSP: Signature Documentation", buffer = buffer_number, noremap = true })
	-- vim.keymap.set('i', "<C-k>", vim.lsp.buf.signature_help, { desc = "LSP: Signature Documentation", buffer = buffer_number, noremap = true })
	-- vim.keymap.set('n', "td", vim.lsp.buf.type_definition, { desc = "LSP: [T]ype [D]efinition", buffer = buffer_number, noremap = true })

  vim.api.nvim_buf_create_user_command(buffer_number, "Format", function(_)
		vim.lsp.buf.format({
			filter = function(format_client)
				-- Use Prettier to format TS/JS if it's available
				return format_client.name ~= "tsserver" or not null_ls.is_registered("prettier")
			end,
		})
	end, { desc = "LSP: Format current buffer with LSP" })
end


for name, config in pairs(servers) do
  require('lspconfig')[name].setup {
    on_attach = on_attach,
    capabilities = capabilities,
    settings = config.settings,
    handlers = vim.tbl_deep_extend("force", {}, default_handlers, config.handlers or {}),
  }
end
