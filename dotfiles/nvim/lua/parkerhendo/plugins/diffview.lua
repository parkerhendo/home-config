-- diffview.nvim — rich diff/merge review UI.
-- Wired up so ghui's "open in editor" (press `e` on a PR) lands in a proper
-- diff view: ghui runs `nvim -c "DiffviewOpen <base>...<head>"`.
return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFocusFiles", "DiffviewFileHistory" },
  keys = {
    { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diffview Open" },
    { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview File History" },
  },
  opts = {},
}
