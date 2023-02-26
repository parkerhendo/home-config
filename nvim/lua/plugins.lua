return require('packer').startup(function(use)
  use {
    'nvim-tree/nvim-tree.lua',
    requires = {
      'nvim-tree/nvim-web-devicons' 
    },
    tag = 'nightly'
  }
  use {
    'nvim-lualine/lualine.nvim',
    requires = { 'nvim-tree/nvim-web-devicons', opt = true }
  }
	use {
    'nvim-treesitter/nvim-treesitter',
    run = ':TSUpdate'
  }
  use {
    'nvim-telescope/telescope.nvim',
    requires = { {'nvim-lua/plenary.nvim'} }
  }
  use {
    'numToStr/Comment.nvim',
    config = function ()
      require('Comment').setup()
    end
  }
  use {
    "folke/trouble.nvim",
    requires = "kyazdani42/nvim-web-devicons",
    config = function()
      require("trouble").setup {
        -- your configuration comes here
        -- or leave it empty to use the default settings
        -- refer to the configuration section below
      }
    end
  }
  -- Clojure
  use 'Olical/conjure'
  use 'guns/vim-sexp'
  use 'tpope/vim-sexp-mappings-for-regular-people'
  use 'jiangmiao/auto-pairs'
  use 'gpanders/nvim-parinfer'

  use 'mfussenegger/nvim-dap'
  use 'mbbill/undotree'
  use "nvim-lua/plenary.nvim"
  use 'nvim-tree/nvim-web-devicons'
  use 'JoosepAlviste/nvim-ts-context-commentstring'
  use 'nvim-treesitter/playground'
  use 'tpope/vim-surround'
  use 'ThePrimeagen/harpoon'
  use 'wbthomason/packer.nvim'
  use 'jiangmiao/auto-pairs'
  use 'lewis6991/impatient.nvim'
  use 'karb94/neoscroll.nvim'
  use 'windwp/nvim-ts-autotag'
  use 'github/copilot.vim'
  use 'parkerhendo/nord.nvim'
  -- Git
  use 'APZelos/blamer.nvim'
  use 'akinsho/toggleterm.nvim'
  use 'lewis6991/gitsigns.nvim'
  
  -- Autocomplete
  use 'neovim/nvim-lspconfig'
  use 'hrsh7th/cmp-nvim-lsp'
  use 'hrsh7th/cmp-buffer'
  use 'hrsh7th/cmp-path'
  use 'hrsh7th/cmp-cmdline'
  use 'hrsh7th/nvim-cmp'
  use 'L3MON4D3/LuaSnip'
  use 'saadparwaiz1/cmp_luasnip'

  use 'simrat39/rust-tools.nvim'

  use 'j-hui/fidget.nvim'
end)
