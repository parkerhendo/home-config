return {
  "folke/trouble.nvim",
  cmd = "Trouble",
  requires = "kyazdani42/nvim-web-devicons",
  config = function()
    require("trouble").setup({})
  end,
}
