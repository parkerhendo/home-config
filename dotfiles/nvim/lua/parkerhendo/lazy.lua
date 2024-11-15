-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out,                            "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    -- transparent bg
    { "xiyaowong/transparent.nvim", cmd = "TransparentEnable" },
    -- Dark theme (Personal fork of nord.nvim)
    -- { "parkerhendo/nord.nvim" },

    -- Gruvbox theme
    {
      'f4z3r/gruvbox-material.nvim',
      name = 'gruvbox-material',
      lazy = false,
      priority = 1000,
      opts = {},
    },
    -- file tree
    {
      "nvim-tree/nvim-tree.lua",
      requires = {
        "nvim-tree/nvim-web-devicons",
      },
    },
    {
      "nvim-lualine/lualine.nvim",
      requires = { "nvim-tree/nvim-web-devicons" },
    },
    -- Better git conflict UX
    { "akinsho/git-conflict.nvim",  version = "*",            config = true },
    -- Install treesitter for better syntax highlighting
    {
      "nvim-treesitter/nvim-treesitter",
      build = ":TSUpdate",
    },
    -- Additional text objects for treesitter
    {
      "nvim-treesitter/nvim-treesitter-textobjects",
      -- after = "nvim-treesitter",
    },
    -- Install lsp
    {
      "neovim/nvim-lspconfig",
      dependencies = {
        -- Plugin and UI to automatically install LSPs to stdpath
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
        -- Install null-ls for diagnostics, code actions, and formatting
        "jose-elias-alvarez/null-ls.nvim",
        -- Install neodev for better nvim configuration and plugin authoring via lsp configurations
        "folke/neodev.nvim",
        -- Progress/Status update for LSP
        { "j-hui/fidget.nvim", version = "v1.1.0" },
      },
    },
    -- Install nvim-cmp for autocompletion
    {
      "hrsh7th/nvim-cmp",
      dependencies = {
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/cmp-path",
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-cmdline",
        "L3MON4D3/LuaSnip",
        "saadparwaiz1/cmp_luasnip",
        "rafamadriz/friendly-snippets",
      },
    },
    -- Install telescope
    {
      "nvim-telescope/telescope.nvim",
      dependencies = { "nvim-lua/plenary.nvim" },
    },
    -- Install nvim-lsp-file-operations for file operations via lsp in the file tree
    {
      "antosha417/nvim-lsp-file-operations",
      dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-neo-tree/neo-tree.nvim",
      },
    },

    {
      "numToStr/Comment.nvim",
      config = function(plugin)
        require("Comment").setup()
      end,
    },
    -- Install neoscroll for smooth scrolling
    -- {
    --   "karb94/neoscroll.nvim",
    --   config = function()
    --     require("neoscroll").setup()
    --   end,
    -- },
    -- Install nvim-autopairs  and nvim-ts-autotag to auto close brackets & tags
    { "windwp/nvim-autopairs" },
    { "windwp/nvim-ts-autotag" },
    -- Install vim-surround for managing parenthese, brackets, quotes, etc
    { "tpope/vim-surround" },
    -- install vim-fugitive
    { "tpope/vim-fugitive" },
    {
      "folke/trouble.nvim",
      requires = "kyazdani42/nvim-web-devicons",
      config = function()
        require("trouble").setup({})
      end,
    },
    -- Install context-commentstring to enable jsx commenting is ts/js/tsx/jsx files
    { "JoosepAlviste/nvim-ts-context-commentstring" },
    -- easily track and switch between buffers
    { "ThePrimeagen/harpoon" },
    -- Git
    { "APZelos/blamer.nvim" },
    -- use to access lazygit inside neovim
    { "akinsho/toggleterm.nvim" },

    { "lewis6991/gitsigns.nvim" },
    { "almo7aya/openingh.nvim" },
    {
      'akinsho/git-conflict.nvim',
      version = "*",
      config = function()
        require("git-conflict").setup(
          {
            default_mappings = true,     -- disable buffer local mapping created by this plugin
            default_commands = true,     -- disable commands created by this plugin
            disable_diagnostics = false, -- This will disable the diagnostics in a buffer whilst it is conflicted
            list_opener = 'copen',       -- command or function to open the conflicts list
            highlights = {               -- They must have background color, otherwise the default color will be used
              incoming = 'DiffAdd',
              current = 'DiffText',
            }
          }
        )
      end
    }

  },
  -- Configure any other settings here. See the documentation for more details.
  -- colorscheme that will be used when installing plugins.
  install = { colorscheme = { "nord" } },
  -- automatically check for plugin updates
  checker = { enabled = true },
})
