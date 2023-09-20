local packer_install_path = vim.fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'

local is_bootstrapped = false

if vim.fn.empty(vim.fn.glob(packer_install_path)) > 0 then
  is_bootstrapped = true
  vim.api.nvim_command('!git clone https://github.com/wbthomason/packer.nvim' .. packer_install_path)
  vim.cmd.packadd('packer.nvim')
end

vim.api.nvim_create_autocmd("BufWritePost", {
  command = "source <afile> | PackerSync",
  group = vim.api.nvim_create_augroup("recompile_packer", { clear = true }),
  pattern = vim.fn.stdpath("config") .. "/lua/parkerhendo/packer.lua",
})

local packer = require('packer')

local conf = {
  display = {
    open_fn = function()
      return require('packer.util').float({ border = 'single' })
    end,
  }
}

packer.init(conf)

return packer.startup(function(use)
  -- Let packer manage itself
  use 'wbthomason/packer.nvim'

  -- Personal fork of nord.nvim
  use 'parkerhendo/nord.nvim'

  -- file tree
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

  -- Install treesitter for better syntax highlighting
	use {
    'nvim-treesitter/nvim-treesitter',
    run = function()
			require("nvim-treesitter.install").update({ with_sync = true })
		end,
  }

  -- Additional text objects for treesitter
	use({
		"nvim-treesitter/nvim-treesitter-textobjects",
		after = "nvim-treesitter",
	})


  -- Autocomplete
  use({
    'neovim/nvim-lspconfig',
    requires = {
      -- Plugin and UI to automatically install LSPs to stdpath
			"williamboman/mason.nvim",
			"williamboman/mason-lspconfig.nvim",

      -- Install null-ls for diagnostics, code actions, and formatting
			"jose-elias-alvarez/null-ls.nvim",

      -- Install neodev for better nvim configuration and plugin authoring via lsp configurations
			"folke/neodev.nvim",

      -- Progress/Status update for LSP
      { 'j-hui/fidget.nvim', tag='legacy'}
    }
  })

  use ({
    'j-hui/fidget.nvim',
    tag = 'legacy',
    config = function()
      require("fidget").setup {
        -- options
      }
    end,
  })
  
  -- Install nvim-cmp for autocompletion
  use({
    'hrsh7th/nvim-cmp',
    requires = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-path',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-cmdline',
      'L3MON4D3/LuaSnip',
      'saadparwaiz1/cmp_luasnip',
      'rafamadriz/friendly-snippets'
    },
  })

  -- Install telescope
  use {
    'nvim-telescope/telescope.nvim',
    requires = {'nvim-lua/plenary.nvim'}
  }

  use {
    'numToStr/Comment.nvim',
    config = function ()
      require('Comment').setup()
    end
  }

  -- Install neoscroll for smooth scrolling
  use({
    'karb94/neoscroll.nvim',
    config = function()
      require('neoscroll').setup()
    end
  }) 

  -- Install nvim-autopairs  and nvim-ts-autotag to auto close brackets & tags
	use("windwp/nvim-autopairs")
	use("windwp/nvim-ts-autotag")

	-- Install vim-surround for managing parenthese, brackets, quotes, etc
	use("tpope/vim-surround")

  use({
    'folke/trouble.nvim',
    requires = "kyazdani42/nvim-web-devicons",
    config = function()
      require("trouble").setup {}
    end
  }) 

  -- Install context-commentstring to enable jsx commenting is ts/js/tsx/jsx files
  use('JoosepAlviste/nvim-ts-context-commentstring')

  -- easily track and switch between buffers
  use 'ThePrimeagen/harpoon'

  -- Install neoscroll for smooth scrolling
  -- use 'karb94/neoscroll.nvim'

  -- Install github copilot
  use({
    "zbirenbaum/copilot.lua",
  })

  -- Git
  use 'APZelos/blamer.nvim'
  -- use to access lazygit inside neovim
  use 'akinsho/toggleterm.nvim'
  use 'lewis6991/gitsigns.nvim'
  use({
    'akinsho/git-conflict.nvim',
    tag = "*",
    config = function()
      require('git-conflict').setup {
        default_mappings = false, -- disable buffer local mapping created by this plugin
        disable_diagnostics = false, -- This will disable the diagnostics in a buffer whilst it is conflicted
        list_opener = "copen", -- command or function to open the conflicts list
        highlights = { -- They must have background color, otherwise the default color will be used
          incoming = "DiffText",
          current = "DiffAdd",
        },
      }
    end
  }) 
  
  if is_bootstrapped then
    require('packer').sync()
  end
end)
