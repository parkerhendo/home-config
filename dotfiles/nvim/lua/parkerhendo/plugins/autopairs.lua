-- Install nvim-autopairs  and nvim-ts-autotag to auto close brackets & tags
return {
  "windwp/nvim-autopairs",
  init = function()
    local cmp_autopairs = require("nvim-autopairs.completion.cmp")
    local cmp = require("cmp")
    -- Integrate nvim-autopairs with cmp
    cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
  end,
}
