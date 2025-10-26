return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  opts = {
    indent = {
      enabled = true,
      indent = {
        enabled = false,
        -- hl = "SnacksIndent",
      },
      animate = {
        enabled = false,
      },
      chunk = {
        enabled = true,
        only_current = true,
        char = {
          corner_top = "╭",
          corner_bottom = "╰",
          arrow = "─",
        },
        hl = "SnacksIndentScope",
      },
    },
  },
}
