local set = vim.opt

set.swapfile = false
set.updatetime = 0
set.encoding="utf-8"
set.fileencoding="utf-8"
set.smartindent=true
set.autoindent=true
set.iskeyword:append("-")
set.clipboard=""
set.smarttab=true
set.tabstop=2
set.softtabstop=2
set.shiftwidth=2
set.expandtab=true
set.incsearch=true
set.number=true
set.relativenumber=true
set.cmdheight=1
set.signcolumn="yes"
set.cindent=true
set.history=50
set.ruler=true
set.textwidth=110
set.cursorline=true
set.showcmd=true
set.incsearch=true

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
vim.cmd [[set complete+=kspell]]
vim.cmd [[set completeopt=menu,menuone,noselect]]

vim.opt.shortmess = vim.opt.shortmess + "c"

vim.cmd [[set mouse=a]]
vim.cmd [[set invhlsearch]]
vim.cmd [[lcd $PWD]]

vim.cmd [[packadd packer.nvim]]

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd
local yank_group = augroup('HighlightYank', {})

function R(name)
  require("plenary.reload").reload_module(name)
end

-- highlight yanked text
autocmd('TextYankPost', {
  group = yank_group,
  pattern = '*',
  callback = function()
    vim.highlight.on_yank({
      higroup = 'IncSearch',
      timeout = 40
    })
  end,
})

-- Set formatoptions on each file open since it'll get overwritten by other plugins
vim.cmd [[autocmd FileType * setlocal formatoptions-=c formatoptions-=r formatoptions-=o ]]

vim.opt.formatoptions = {
  ["1"] = true,
  ["2"] = true, -- Use indent from 2nd line of a paragraph
  q = true, -- continue comments with gq"
  c = false, -- Auto-wrap comments using textwidth
  r = false, -- Continue comments when pressing Enter
  n = true, -- Recognize numbered lists
  t = false, -- autowrap lines using text width value
  j = true, -- remove a comment leader when joining lines.
  l = true,
  v = true,
}

vim.cmd [[let g:blamer_enabled = 1]]
vim.cmd [[let g:blamer_delay = 500]]
vim.cmd [[let g:blamer_show_in_visual_modes = 1]]
vim.cmd [[let g:blamer_show_in_insert_modes = 0]]

require('nvim-tree').setup({
  git = {
    ignore = false,
  },
  filters = {
    dotfiles = false,
    custom = { "^.git$" },
  },
  update_focused_file = {
    enable  = true
  },
  view = {
    float = {
      enable = false,
      quit_on_focus_loss = true
    }
  }
})
require('Comment').setup({
  pre_hook = function(ctx)
    if vim.bo.filetype == 'typescriptreact' then
      local U = require('Comment.utils')

      -- determine to use line or block commentstring
      local type = ctx.ctype == U.ctype.line and '__default' or '__multiline'

      -- Determine location where to calculate commentstring from
      local loc = nil
      if ctx.ctype == U.ctype.block then
        loc = require('ts_context_commentstring.utils').get_cursor_location()
      elseif ctx.cmotion == U.cmotion.v or ctx.cmotion == U.cmotion.V then
        loc = require('ts_context_commentstring.utils').get_visual_start_location()
      end

      return require('ts_context_commentstring.internal').calculate_commentstring({
        key = type,
        location = loc
      })
    end
  end,
})


-- colors
vim.g.nord_bold = false
vim.g.nord_disable_background = false -- use iterm background color
require('nord').set();

-- lualine
nord1 = "#232730"
nord2 = "#2e3440"
nord3 = "#3b4252"
nord5 = "#e5e9f0"
nord6 = "#eceff4"
nord7 = "#8fbcbb"
nord8 = "#88c0d0"
nord14 = "#ebcb8b"

local nord = require'lualine.themes.nord'

nord.normal.a.fg = nord1
nord.normal.a.bg = nord7
nord.normal.b.fg = nord5
nord.normal.b.bg = nord2
nord.normal.c.fg = nord5
nord.normal.c.bg = nord3

nord.insert.a.fg = nord1
nord.insert.a.bg = nord6

nord.visual.a.fg = nord1
nord.visual.a.bg = nord7

nord.replace.a.fg = nord1
nord.replace.a.bg = nord13

nord.inactive.a.fg = nord1
nord.inactive.a.bg = nord7
nord.inactive.b.fg = nord5
nord.inactive.b.bg = nord1
nord.inactive.c.fg = nord5
nord.inactive.c.bg = nord2

require('lualine').setup {
  options = {
    theme = nord,
    component_separators = { left = '·'},
  },
  sections = {
    lualine_a = {'mode'},
    lualine_b = {'branch', 'diff', 'diagnostics'},
    lualine_c = { {'filename', path = 1} },
    lualine_x = {'filetype'},
    lualine_y = {'progress'},
    lualine_z = {'location'}
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = { {'filename', path = 1} },
    lualine_x = {'location'},
    lualine_y = {},
    lualine_z = {}
  }
}

-- treesitter
require'nvim-treesitter.configs'.setup {
  ensure_installed = { "c","html", "css", "markdown", "javascript", "typescript", "json", "lua", "prisma", "ruby", "rust", "tsx", "vim", "yaml", "sql" },
  highlight = {
    enable = true
  },
  indent = {
    enable = true
  },
  playground = {
    enable = true
  },
  context_commentstring = {
    enable = true
  },
  autotag = {
    enable = true,
  }
}

-- gitsigns
require('gitsigns').setup{
  signs = {
    add          = {hl = 'GitSignsAdd'   , text = '•', numhl='GitSignsAddNr'   , linehl='GitSignsAddLn'},
    change       = {hl = 'GitSignsChange', text = '•', numhl='GitSignsChangeNr', linehl='GitSignsChangeLn'},
    delete       = {hl = 'GitSignsDelete', text = '•', numhl='GitSignsDeleteNr', linehl='GitSignsDeleteLn'},
    topdelete    = {hl = 'GitSignsDelete', text = '•', numhl='GitSignsDeleteNr', linehl='GitSignsDeleteLn'},
    changedelete = {hl = 'GitSignsChange', text = '•', numhl='GitSignsChangeNr', linehl='GitSignsChangeLn'},
  },
  current_line_blame_opts = {
    delay = 200,
  },
  on_attach = function(bufnr)
    local gs = package.loaded.gitsigns

    local function map(mode, l, r, opts)
      opts = opts or {}
      opts.buffer = bufnr
      vim.keymap.set(mode, l, r, opts)
    end

    map('n', '<leader>B', function() gs.blame_line{full=true} end)
    map('n', '<leader>b', gs.toggle_current_line_blame)
  end
}


-- Telescope
local telescope = require("telescope")
local actions = require('telescope.actions')
local trouble = require("trouble.providers.telescope")
require('telescope').setup{
  defaults = {
    mappings = {
      i = {
        ["<C-j>"] = actions.move_selection_next,
        ["<C-k>"] = actions.move_selection_previous,
        ["<c-t>"] = trouble.open_with_trouble,
        ["<esc>"] = actions.close
      },
      n = {
        ["<c-t>"] = trouble.open_with_trouble,
        ["q"] = actions.close
      }
    }
  },
  pickers = {
    find_files = {
      theme = "dropdown",
    },
    buffers = {
      theme = "dropdown",
      sort_lastused = true
    },
    live_grep = {
      theme = "dropdown",
    }
  }
}

-- toggleterm
require'toggleterm'.setup {
  shade_terminals = false
}
local Terminal  = require('toggleterm.terminal').Terminal
local lazygit = Terminal:new({ cmd = "lazygit", hidden = true, direction = "float" })

function _lazygit_toggle()
  lazygit:toggle()
end

-- treesitter
require'nvim-treesitter.configs'.setup {
  ensure_installed = { "html", "css", "markdown", "javascript", "typescript", "json", "lua", "prisma", "ruby", "rust", "tsx", "vim", "yaml" },
  highlight = {
    enable = true
  },
  indent = {
    enable = true
  },
  playground = {
    enable = true
  },
  context_commentstring = {
    enable = true
  }
}
