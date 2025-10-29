return {
  "nvim-lualine/lualine.nvim",
  requires = { "nvim-tree/nvim-web-devicons" },
  opts = {
    options = {
      theme = "gruvbox_dark",
      component_separators = { left = "·" },
    },
    sections = {
      lualine_a = { "mode" },
      lualine_b = {
        {
          "branch",
          fmt = function(str)
            if #str > 25 then
              return str:sub(1, 22) .. "..."
            end
            return str
          end,
        },
        "diff",
        "diagnostics",
      },
      lualine_c = { { "filename", path = 1 } },
      lualine_x = { "filetype" },
      lualine_y = { "progress" },
      lualine_z = { "location" },
    },
    inactive_sections = {
      lualine_a = {},
      lualine_b = {},
      lualine_c = { { "filename", path = 1 } },
      lualine_x = { "location" },
      lualine_y = {},
      lualine_z = {},
    },
  },
}
