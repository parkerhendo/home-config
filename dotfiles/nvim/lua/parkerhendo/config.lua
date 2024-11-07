local set = vim.opt

set.swapfile = false
set.updatetime = 0
set.encoding = "utf-8"
set.fileencoding = "utf-8"
set.smartindent = true
set.autoindent = true
set.iskeyword:append("-")
set.clipboard = ""
set.smarttab = true
set.tabstop = 2
set.softtabstop = 2
set.shiftwidth = 2
set.expandtab = true
set.incsearch = true
set.number = true
set.relativenumber = true
set.cmdheight = 1
set.signcolumn = "yes"
set.cindent = true
set.history = 50
set.ruler = true
set.textwidth = 110
set.cursorline = true
set.showcmd = true
set.incsearch = true

vim.cmd([[set list]])
vim.cmd([[set listchars=tab:\|\ ,eol:¬,trail:•,extends:❯,precedes:❮]])
vim.cmd([[set termguicolors]])
vim.cmd([[set nocompatible]])
vim.cmd([[set breakindent]])
vim.cmd([[set nobackup]])
vim.cmd([[set nowritebackup]])
vim.cmd([[set lbr]])
vim.cmd([[set ignorecase]])
vim.cmd([[set smartcase]])
vim.cmd([[set lazyredraw]])
vim.cmd([[set magic]])
vim.cmd([[set noerrorbells]])
vim.cmd([[set complete+=kspell]])
vim.cmd([[set completeopt=menu,menuone,noselect]])

vim.opt.shortmess = vim.opt.shortmess + "c"

vim.cmd([[set mouse=a]])
vim.cmd([[set invhlsearch]])
vim.cmd([[lcd $PWD]])

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

function R(name)
  require("plenary.reload").reload_module(name)
end

-- Set formatoptions on each file open since it'll get overwritten by other plugins
vim.cmd([[autocmd FileType * setlocal formatoptions-=c formatoptions-=r formatoptions-=o ]])

vim.opt.formatoptions = {
  ["1"] = true,
  ["2"] = true, -- Use indent from 2nd line of a paragraph
  q = true,     -- continue comments with gq"
  c = false,    -- Auto-wrap comments using textwidth
  r = false,    -- Continue comments when pressing Enter
  n = true,     -- Recognize numbered lists
  t = false,    -- autowrap lines using text width value
  j = true,     -- remove a comment leader when joining lines.
  l = true,
  v = true,
}

vim.cmd([[let g:blamer_enabled = 1]])
vim.cmd([[let g:blamer_delay = 500]])
vim.cmd([[let g:blamer_show_in_visual_modes = 1]])
vim.cmd([[let g:blamer_show_in_insert_modes = 0]])

-- colors
vim.o.background = "dark" -- or "light" for light mode
vim.cmd([[colorscheme gruvbox]])

function _theme_toggle()
  if vim.o.background == "dark" then
    vim.o.background = "light"
    require("lualine").setup({
      options = {
        theme = "gruvbox_light",
      }
    })
  else
    vim.o.background = "dark"
    require("lualine").setup({
      options = {
        theme = "gruvbox_dark",
      }
    })
  end
end

-- toggleterm
require("toggleterm").setup({
  shade_terminals = false,
})
local Terminal = require("toggleterm.terminal").Terminal
local lazygit = Terminal:new({ cmd = "lazygit", hidden = true, direction = "float" })

function _lazygit_toggle()
  lazygit:toggle()
end
