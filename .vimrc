call plug#begin()
Plug 'jasonlong/nord-vim'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'kyazdani42/nvim-web-devicons'
Plug 'nvim-lualine/lualine.nvim'
Plug 'cohama/lexima.vim'
Plug 'lewis6991/impatient.nvim'
Plug 'jiangmiao/auto-pairs'
Plug 'APZelos/blamer.nvim'

" syntax helpers
Plug 'styled-components/vim-styled-components', { 'branch': 'main' }

" autocomplete things
Plug 'neovim/nvim-lspconfig'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'
Plug 'hrsh7th/cmp-path'
Plug 'hrsh7th/cmp-cmdline'
Plug 'hrsh7th/nvim-cmp'
call plug#end()

" editor configuration
set termguicolors
set completeopt=menu,menuone,noselect
set number
set relativenumber
set ignorecase
set backspace=indent,eol,start
set tabstop=2
set expandtab
set shiftwidth=2
set autoindent
set smartindent
set cindent
set history=50
set ruler
set textwidth=110
set cursorline
set showcmd
set incsearch
set invhlsearch

syntax on
filetype plugin indent on

colorscheme nord

" blamer config
let g:blamer_enabled = 1
let g:blamer_delay = 500
let g:blamer_show_in_visual_modes = 1
let g:blamer_show_in_insert_modes = 0

" prettier setup
command! -nargs=0 Prettier :call CocAction('runCommand', 'prettier.formatFile')

" open file tree 
:nmap <space>e <Cmd>CocCommand explorer<CR>

" Find files
:nmap <space>p <Cmd>Telescope find_files<CR>


"auto complete suggestion
inoremap <silent><expr> <c-space> coc#refresh()
inoremap <silent><expr> <c-@> coc#refresh()

" GoTo code navigation
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Show documentation
nnoremap <silent> K :call ShowDocumentation()<CR>

function! ShowDocumentation()
  if CocAction('hasProvider', 'hover')
    call CocActionAsync('doHover')
  else
    call feedkeys('K', 'in')
  endif
endfunction

" making split mode easier
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

" resizing
noremap <silent> <C-S-Left> :vertical resize +5<CR>
noremap <silent> <C-S-Right> :vertical resize -5<CR>
noremap <silent> <C-S-Up> :resize +2<CR>
noremap <silent> <C-S-Down> :resize -2<CR>
