-- nvim-cmp
local cmp = require("cmp")
local luasnip = require("luasnip")

local has_words_before = function()
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
end

cmp.setup({
  snippet = {
    expand = function(args)
      require("luasnip").lsp_expand(args.body)
    end,
  },
  window = {
    completion = {
      border = "rounded",
      winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:PmenuSel,Search:None",
      max_width = 50,
      max_height = 15,
    },
    documentation = {
      border = "rounded",
      winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:Visual,Search:None",
      max_width = 80,
      max_height = 20,
    },
  },
  formatting = {
    fields = { "abbr", "kind", "menu" },
    format = function(entry, vim_item)
      -- Limit the width of the completion text
      local max_abbr_width = 30
      if #vim_item.abbr > max_abbr_width then
        vim_item.abbr = string.sub(vim_item.abbr, 1, max_abbr_width - 1) .. "..."
      end

      -- Set the source name
      vim_item.menu = ({
        nvim_lsp = "[LSP]",
        luasnip = "[Snip]",
        buffer = "[Buf]",
        path = "[Path]",
      })[entry.source.name]

      return vim_item
    end,
  },
  mapping = cmp.mapping.preset.insert({
    ["<C-b>"] = cmp.mapping.scroll_docs(-4),
    ["<C-f>"] = cmp.mapping.scroll_docs(4),
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<C-e>"] = cmp.mapping.abort(),
    ["<CR>"] = cmp.mapping.confirm({ select = true }),
    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      elseif has_words_before() then
        cmp.complete()
      else
        fallback()
      end
    end, { "i", "s" }),

    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { "i", "s" }),
  }),
  sources = cmp.config.sources({
    { name = "nvim_lsp" },
    { name = "luasnip" },
  }, {
    { name = "buffer" },
  }),
})
