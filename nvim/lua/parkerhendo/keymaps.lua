local keymap = vim.api.nvim_set_keymap

local nnoremap = require("parkerhendo.keymap_utils").nnoremap
local vnoremap = require("parkerhendo.keymap_utils").vnoremap
local inoremap = require("parkerhendo.keymap_utils").inoremap
local tnoremap = require("parkerhendo.keymap_utils").tnoremap
local xnoremap = require("parkerhendo.keymap_utils").xnoremap

local M = {}

vim.g.mapleader = ","
vim.g.maplocalleader = ","

-- init.lua management
nnoremap("<leader>v", ":e $MYVIMRC<cr>")
nnoremap("<leader>V", ":source $MYVIMRC<cr>")
nnoremap("<leader>pi", ":source $MYVIMRC<cr>:PackerSync<cr>")

-- clipboard management nicities
nnoremap("<leader>p", "\"_dP")

nnoremap("<leader>y", "\"+y")
vnoremap("<leader>y", "\"+y")
nnoremap("<leader>Y", "\"+Y")

nnoremap("<leader>d", "\"_d")
vnoremap("<leader>d", "\"_d")

-- quick write and quit
nnoremap("<leader>w", ":w<cr>")
nnoremap("<leader>q", ":q<cr>")
nnoremap("<leader>Q", ":q!<cr>")

-- nvim-tree
nnoremap("<leader>e", ":NvimTreeToggle<cr>")

-- navigating splits
nnoremap("<M-j>", "<C-w>j")
nnoremap("<M-k>", "<C-w>k")
nnoremap("<M-h>", "<C-w>h")
nnoremap("<M-l>", "<C-w>l")

-- resize splits
nnoremap("<C-S-Left>", ":vertical resize -5<cr>")
nnoremap("<C-S-Right>", ":vertical resize +5<cr>")
nnoremap("<C-S-Up>", ":resize +2<cr>")
nnoremap("<C-S-Down>", ":resize -2<cr>")

--Remap for dealing with word wrap
nnoremap('k', "v:count == 0 ? 'gk' : 'k'", {expr = true, silent = true })
vnoremap('k', "v:count == 0 ? 'gk' : 'k'", {expr = true, silent = true })
vnoremap('j', "v:count == 0 ? 'gj' : 'j'", {expr = true, silent = true })
nnoremap('j', "v:count == 0 ? 'gj' : 'j'", {expr = true, silent = true })

-- Move lines up/down (visual mode)
vnoremap("J", ":m '>+1<cr>gv=gv")
vnoremap("K", ":m '<-2<cr>gv=gv")

-- Telescope
vim.cmd([[
nnoremap <leader>f <cmd>lua require('telescope.builtin').find_files({ hidden=true })<cr>
nnoremap <leader>g <cmd>lua require('telescope.builtin').live_grep()<cr>
nnoremap <space> <cmd>lua require('telescope.builtin').buffers()<cr>
]])

-- toggleterm
nnoremap("<leader>t", "<cmd>lua _lazygit_toggle()<CR>", {silent = true})

-- Harpoon
vim.cmd([[
  nnoremap <silent><leader>m :lua require("harpoon.mark").add_file()<CR>
  nnoremap <silent><left> :lua require("harpoon.ui").toggle_quick_menu()<CR>
  nnoremap <silent><up> :lua require("harpoon.ui").nav_next()<CR>
  nnoremap <silent><down> :lua require("harpoon.ui").nav_prev()<CR>
]])

-- Trouble
nnoremap("<leader>xx", "<cmd>Trouble<cr>", {silent = true})
nnoremap("<leader>xw", "<cmd>Trouble workspace_diagnostics<cr>", {silent = true})
nnoremap("<leader>xd", "<cmd>Trouble document_diagnostics<cr>", {silent = true})
nnoremap("<leader>xl", "<cmd>Trouble loclist<cr>", {silent = true})
nnoremap("<leader>xq", "<cmd>Trouble quickfix<cr>", {silent = true})
nnoremap("gr", "<cmd>Trouble lsp_references<cr>", {silent = true})

-- diagnostics
nnoremap('<leader>dd', "<cmd>Telescope diagnostics<CR>", {silent=true})
nnoremap('do', "<cmd>lua vim.diagnostic.open_float(0, { scope = \"line\" })<cr>", {silent=true})
nnoremap('dn', "<cmd>lua vim.diagnostic.goto_prev<cr>", {silent=true})
nnoremap('dp', "<cmd>lua vim.diagnostic.goto_next<cr>", {silent=true})

-- Random, but helpful keymaps
keymap("n", "<leader>X","<cmd>!chmod +x %<CR>", { silent = true })

-- LSP

M.map_lsp_keybinds = function (buffer_number)
  keymap('n', '<leader>rn', vim.lsp.buf.rename, { desc = "LSP: [R]e[n]ame", buffer = buffer_number, noremap = true })
  keymap('n', '<leader>ca', vim.lsp.buf.code_action, { desc = "LSP: [C]ode [A]ction", buffer = buffer_number, noremap = true })
  keymap('n', 'gd', vim.lsp.buf.definition, { desc = "LSP: [G]o to [D]efinition", buffer = buffer_number, noremap = true })

  -- Telescope LSP keybinds --
	keymap(
		'n', "gr",
		require("telescope.builtin").lsp_references,
		{ desc = "LSP: [G]oto [R]eferences", buffer = buffer_number, noremap = true }
	)

	keymap(
		'n', "gi",
		require("telescope.builtin").lsp_implementations,
		{ desc = "LSP: [G]oto [I]mplementation", buffer = buffer_number, noremap = true }
	)

	keymap(
		'n', "<leader>bs",
		require("telescope.builtin").lsp_document_symbols,
		{ desc = "LSP: [B]uffer [S]ymbols", buffer = buffer_number, noremap = true }
	)

	keymap(
		'n', "<leader>ps",
		require("telescope.builtin").lsp_workspace_symbols,
		{ desc = "LSP: [P]roject [S]ymbols", buffer = buffer_number, noremap = true }
	)

  keymap('n', "K", vim.lsp.buf.hover, { desc = "LSP: Hover Documentation", buffer = buffer_number, noremap = true })
	keymap('n', "<leader>k", vim.lsp.buf.signature_help, { desc = "LSP: Signature Documentation", buffer = buffer_number, noremap = true })
	keymap('i', "<C-k>", vim.lsp.buf.signature_help, { desc = "LSP: Signature Documentation", buffer = buffer_number, noremap = true })
	keymap('n', "td", vim.lsp.buf.type_definition, { desc = "LSP: [T]ype [D]efinition", buffer = buffer_number, noremap = true })
end

return M
