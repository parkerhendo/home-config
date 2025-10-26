return {
  "nvim-tree/nvim-tree.lua",
  enabled = false,
  cmd = "NvimTreeToggle",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },
  config = function()
    require("nvim-tree").setup({
      git = {
        ignore = false,
      },
      filters = {
        dotfiles = false,
        custom = { "^.git$" },
      },
      update_focused_file = {
        enable = true,
      },
      renderer = {
        icons = {
          show = {
            folder_arrow = false,
          },
        },
      },
      view = {
        width = 28,
        float = {
          enable = false,
          quit_on_focus_loss = true,
        },
      },
    })
  end,
}
