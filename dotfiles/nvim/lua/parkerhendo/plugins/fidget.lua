return {
  "j-hui/fidget.nvim",
  version = "v1.1.0",
  opts = {
    notification = {
      window = {
        winblend = 0,
      },
    },
  },
  init = function()
    vim.cmd([[
      highlight FidgetTask ctermfg=110 guifg=#FFFFFF
      highlight FidgetTitle ctermfg=110 guifg=#6cb6eb
    ]])
  end,
}
