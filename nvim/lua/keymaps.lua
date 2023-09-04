local keymap = vim.api.nvim_set_keymap

vim.g.mapleader = ","
vim.g.maplocalleader = ","

-- init.lua management
keymap("n", "<leader>v", ":e $MYVIMRC<cr>", {})
keymap("n", "<leader>V", ":source $MYVIMRC<cr>", {})
keymap("n", "<leader>pi", ":source $MYVIMRC<cr>:PackerSync<cr>", {})

-- clipboard management nicities
keymap("n", "<leader>p", "\"_dP", { noremap=true })

keymap("n", "<leader>y", "\"+y", { noremap=true })
keymap("v", "<leader>y", "\"+y", { noremap=true })
keymap("n", "<leader>Y", "\"+Y", {})

keymap("n", "<leader>d", "\"_d", { noremap=true })
keymap("v", "<leader>d", "\"_d", { noremap=true })

-- quick write and quit
keymap("n", "<leader>w", ":w<cr>", {})
keymap("n", "<leader>q", ":q<cr>", {})
keymap("n", "<leader>Q", ":q!<cr>", {})

-- nvim-tree
keymap("n", "<leader>e", ":NvimTreeToggle<cr>", {})

-- navigating splits
keymap("n", "<M-j>", "<C-w>j", {})
keymap("n", "<M-k>", "<C-w>k", {})
keymap("n", "<M-h>", "<C-w>h", {})
keymap("n", "<M-l>", "<C-w>l", {})

-- resize splits
vim.cmd([[
noremap <silent> <C-S-Left> :vertical resize -5<CR>
noremap <silent> <C-S-Right> :vertical resize +5<CR>
noremap <silent> <C-S-Up> :resize +2<CR>
noremap <silent> <C-S-Down> :resize -2<CR>
]])
--Remap for dealing with word wrap
keymap('n', 'k', "v:count == 0 ? 'gk' : 'k'", { noremap = true, expr = true, silent = true })
keymap('v', 'k', "v:count == 0 ? 'gk' : 'k'", { noremap = true, expr = true, silent = true })
keymap('v', 'j', "v:count == 0 ? 'gj' : 'j'", { noremap = true, expr = true, silent = true })
keymap('n', 'j', "v:count == 0 ? 'gj' : 'j'", { noremap = true, expr = true, silent = true })

-- Move lines up/down (visual mode)
keymap("v", "J", ":m '>+1<cr>gv=gv", {})
keymap("v", "K", ":m '<-2<cr>gv=gv", {})

-- Telescope
vim.cmd([[
nnoremap <leader>f <cmd>lua require('telescope.builtin').find_files()<cr>
nnoremap <leader>g <cmd>lua require('telescope.builtin').live_grep()<cr>
nnoremap <space> <cmd>lua require('telescope.builtin').buffers()<cr>
]])

-- toggleterm
keymap("n", "<leader>t", "<cmd>lua _lazygit_toggle()<CR>", {noremap = true, silent = true})

-- Harpoon
vim.cmd([[
  nnoremap <silent><leader>m :lua require("harpoon.mark").add_file()<CR>
  nnoremap <silent><left> :lua require("harpoon.ui").toggle_quick_menu()<CR>
  nnoremap <silent><up> :lua require("harpoon.ui").nav_next()<CR>
  nnoremap <silent><down> :lua require("harpoon.ui").nav_prev()<CR>
]])

-- Copilot
vim.cmd([[
  imap <silent><script><expr> <leader><tab> copilot#Accept("\<CR>")
]])

-- Trouble
keymap("n", "<leader>xx", "<cmd>Trouble<cr>", {silent = true, noremap = true})
keymap("n", "<leader>xw", "<cmd>Trouble workspace_diagnostics<cr>", {silent = true, noremap = true})
keymap("n", "<leader>xd", "<cmd>Trouble document_diagnostics<cr>", {silent = true, noremap = true})
keymap("n", "<leader>xl", "<cmd>Trouble loclist<cr>", {silent = true, noremap = true})
keymap("n", "<leader>xq", "<cmd>Trouble quickfix<cr>", {silent = true, noremap = true})
keymap("n", "gr", "<cmd>Trouble lsp_references<cr>", {silent = true, noremap = true})

-- diagnostics
keymap('n', '<leader>dd', "<cmd>Telescope diagnostics<CR>", { noremap=true, silent=true })
keymap('n', 'do', "<cmd>lua vim.diagnostic.open_float(0, { scope = \"line\" })<cr>", { noremap=true, silent=true })
keymap('n', 'dn', vim.diagnostic.goto_prev, { noremap=true, silent=true })
keymap('n', 'dp', vim.diagnostic.goto_next, { noremap=true, silent=true })

-- Random, but helpful keymaps
keymap("n", "<leader>X","<cmd>!chmod +x %<CR>", { silent = true })
