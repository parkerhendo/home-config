local keymap = vim.api.nvim_set_keymap

vim.g.mapleader = ","

-- init.lua management
keymap("n", "<leader>v", ":e $MYVIMRC<cr>", {})
keymap("n", "<leader>V", ":source $MYVIMRC<cr>", {})
keymap("n", "<leader>pi", ":source $MYVIMRC<cr>:PackerSync<cr>", {})

-- quick write and quit
keymap("n", "<leader>w", ":w<cr>", {})
keymap("n", "<leader>q", ":q<cr>", {})

-- nvim-tree
keymap("n", "<leader>e", ":NvimTreeToggle<cr>", {})

-- navigating splits
keymap("n", "<M-j>", "<C-w>j", {})
keymap("n", "<M-k>", "<C-w>k", {})
keymap("n", "<M-h>", "<C-w>h", {})
keymap("n", "<M-l>", "<C-w>l", {})

-- Move lines up/down (visual mode)
keymap("v", "J", ":m '>+1<cr>gv=gv", {})
keymap("v", "K", ":m '<-2<cr>gv=gv", {})

-- Telescope
vim.cmd([[
nnoremap <leader>f <cmd>lua require('telescope.builtin').find_files()<cr>
nnoremap <leader>g <cmd>lua require('telescope.builtin').live_grep()<cr>
nnoremap <space> <cmd>lua require('telescope.builtin').buffers()<cr>
]])

-- Trouble
vim.api.nvim_set_keymap("n", "<leader>xx", "<cmd>Trouble<cr>",
  {silent = true, noremap = true}
)
vim.api.nvim_set_keymap("n", "<leader>xw", "<cmd>Trouble workspace_diagnostics<cr>",
  {silent = true, noremap = true}
)
vim.api.nvim_set_keymap("n", "<leader>xd", "<cmd>Trouble document_diagnostics<cr>",
  {silent = true, noremap = true}
)
vim.api.nvim_set_keymap("n", "<leader>xl", "<cmd>Trouble loclist<cr>",
  {silent = true, noremap = true}
)
vim.api.nvim_set_keymap("n", "<leader>xq", "<cmd>Trouble quickfix<cr>",
  {silent = true, noremap = true}
)
vim.api.nvim_set_keymap("n", "gr", "<cmd>Trouble lsp_references<cr>",
  {silent = true, noremap = true}
)
