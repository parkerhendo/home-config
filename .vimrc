call plug#begin()
Plug 'arcticicestudio/nord-vim'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'kyazdani42/nvim-web-devicons'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'lukas-reineke/lsp-format.nvim'
Plug 'christoomey/vim-tmux-navigator'
Plug 'cohama/lexima.vim'

Plug 'rust-lang/rust.vim'
Plug 'vim-language-dept/css-syntax.vim'
Plug 'pangloss/vim-javascript'
Plug 'godlygeek/tabular'
Plug 'preservim/vim-markdown'
Plug 'Chiel92/vim-autoformat'
Plug 'leafgarland/typescript-vim'
Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries'}
call plug#end()

" editor configuration
colorscheme nord

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
set cursorline
set showcmd
set incsearch
syntax on
filetype plugin indent on

" open file tree 
:nmap <space>e <Cmd>CocCommand explorer<CR>

" Find files
:nmap <space>p <Cmd>Telescope find_files<CR>

" enable Shift-tab
:inoremap <S-Tab> <C-d>
