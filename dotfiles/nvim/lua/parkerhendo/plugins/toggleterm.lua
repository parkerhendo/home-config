return {
  "akinsho/toggleterm.nvim",
  cmd = "ToggleTerm",
  config = function()
    require("toggleterm").setup({
      shade_terminals = false,
    })
    local Terminal = require("toggleterm.terminal").Terminal
    local lazygit = Terminal:new({ cmd = "lazygit", hidden = true, direction = "float" })

    _G._lazygit_toggle = function()
      lazygit:toggle()
    end
  end,
}
