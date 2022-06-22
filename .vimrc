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
Plug 'styled-components/vim-styled-components'
Plug 'jparise/vim-graphql'
Plug 'godlygeek/tabular'
Plug 'preservim/vim-markdown'
Plug 'Chiel92/vim-autoformat'
Plug 'leafgarland/typescript-vim'
Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries'}

" clojure things
Plug 'guns/vim-sexp'
Plug 'kien/rainbow_parentheses.vim'
Plug 'tpope/vim-salve.git'
Plug 'tpope/vim-projectionist.git'
Plug 'tpope/vim-dispatch.git'
Plug 'tpope/vim-fireplace.git'
Plug 'guns/vim-clojure-highlight'
Plug 'tpope/vim-sexp-mappings-for-regular-people'

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
set textwidth=110
set cursorline
set showcmd
set incsearch
set invhlsearch

syntax on
filetype plugin indent on
set splitbelow
set splitright
" open file tree 
:nmap <space>e <Cmd>CocCommand explorer<CR>

" Find files
:nmap <space>p <Cmd>Telescope find_files<CR>

" enable Shift-tab
:inoremap <S-Tab> <C-d>

" making split mode easier
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>
