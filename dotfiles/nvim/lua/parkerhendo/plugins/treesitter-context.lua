-- Show context of current cursor position at top of window
return {
  "nvim-treesitter/nvim-treesitter-context",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  event = { "BufReadPost", "BufNewFile" },
  opts = {
    mode = "topline",
    max_lines = 5,
    on_attach = function(buf)
      -- Disable for floating windows (hover, signature help, etc.)
      local dominated_by_floating = vim.iter(vim.api.nvim_list_wins()):any(function(win)
        return vim.api.nvim_win_get_buf(win) == buf and vim.api.nvim_win_get_config(win).relative ~= ""
      end)
      return not dominated_by_floating
    end,
  },
}
