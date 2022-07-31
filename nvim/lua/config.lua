local set = vim.opt
set.swapfile = false
set.updatetime = 0
set.encoding="utf-8"
set.fileencoding="utf-8"
set.smartindent = true
set.iskeyword:append("-")
set.clipboard = "unnamedplus"
set.smarttab = true
set.tabstop = 2
set.softtabstop = 2
set.shiftwidth = 2
set.expandtab = true
set.autoindent = true
set.incsearch = true
set.number = true
set.cmdheight = 1
set.signcolumn = "yes"

vim.cmd [[set termguicolors]]
vim.cmd [[set nocompatible]]
vim.cmd [[set breakindent]]
vim.cmd [[set nobackup]]
vim.cmd [[set nowritebackup]]
vim.cmd [[set lbr]]
vim.cmd [[set ignorecase]]
vim.cmd [[set smartcase]]
vim.cmd [[set lazyredraw]]
vim.cmd [[set magic]]
vim.cmd [[set noerrorbells]]
vim.cmd [[set formatoptions-=cro]]
vim.cmd [[set complete+=kspell]]
vim.cmd [[set completeopt=menu,menuone,noselect]]
vim.cmd [[set mouse=a]]
vim.cmd [[lcd $PWD]]

vim.cmd [[colorscheme nord]]
