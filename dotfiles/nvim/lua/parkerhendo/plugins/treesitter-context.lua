-- Show context of current cursor position at top of window
return {
  "nvim-treesitter/nvim-treesitter-context",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  event = { "BufReadPost", "BufNewFile" },
  opts = {
    mode = "topline",
    max_lines = 5,
  },
}
