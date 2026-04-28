-- Neovim 0.12 compatibility shim for nvim-treesitter query predicates.
--
-- In Neovim 0.12, query:iter_matches() always returns a *list* of nodes per
-- capture, but nvim-treesitter's custom directives/predicates still index
-- into match[id] expecting a single TSNode.  This causes:
--   "attempt to call method 'range' (a nil value)"
-- when treesitter processes markdown injections (e.g. fenced code blocks
-- inside LSP hover windows).
--
-- This module re-registers the affected handlers with proper table-unwrapping.
-- It must be loaded AFTER lazy.setup() (which triggers nvim-treesitter's
-- query_predicates module), so the overrides stick.
--
-- TODO: Remove once nvim-treesitter ships a fix for 0.12 compatibility.

if vim.fn.has("nvim-0.12") ~= 1 then
  return
end

if not package.loaded["nvim-treesitter.query_predicates"] then
  return
end

local query = require("vim.treesitter.query")

--- In 0.12+ each match capture is a list of nodes; unwrap to a single node.
local function u(match, id)
  local v = match[id]
  if type(v) == "table" then
    return v[1]
  end
  return v
end

-- Directives --------------------------------------------------------------

local lang_aliases = { sh = "bash", ex = "elixir", pl = "perl", uxn = "uxntal", ts = "typescript" }

query.add_directive("set-lang-from-info-string!", function(match, _, bufnr, pred, metadata)
  local node = u(match, pred[2])
  if not node then
    return
  end
  local text = vim.treesitter.get_node_text(node, bufnr):lower()
  metadata["injection.language"] = vim.filetype.match({ filename = "a." .. text })
    or lang_aliases[text]
    or text
end, { force = true })

query.add_directive("set-lang-from-mimetype!", function(match, _, bufnr, pred, metadata)
  local node = u(match, pred[2])
  if not node then
    return
  end
  local mime = vim.treesitter.get_node_text(node, bufnr)
  local map = {
    importmap = "json",
    module = "javascript",
    ["application/ecmascript"] = "javascript",
    ["text/ecmascript"] = "javascript",
  }
  if map[mime] then
    metadata["injection.language"] = map[mime]
  else
    local parts = vim.split(mime, "/", {})
    metadata["injection.language"] = parts[#parts]
  end
end, { force = true })

query.add_directive("downcase!", function(match, _, bufnr, pred, metadata)
  local id = pred[2]
  local node = u(match, id)
  if not node then
    return
  end
  local text = vim.treesitter.get_node_text(node, bufnr, { metadata = metadata[id] }) or ""
  if not metadata[id] then
    metadata[id] = {}
  end
  metadata[id].text = string.lower(text)
end, { force = true })

-- Predicates --------------------------------------------------------------

query.add_predicate("nth?", function(match, _, _, pred)
  local node = u(match, pred[2])
  local n = tonumber(pred[3])
  if node and node:parent() and node:parent():named_child_count() > n then
    return node:parent():named_child(n) == node
  end
  return false
end, { force = true })

query.add_predicate("is?", function(match, _, bufnr, pred)
  local locals = require("nvim-treesitter.locals")
  local node = u(match, pred[2])
  local types = { unpack(pred, 3) }
  if not node then
    return true
  end
  local _, _, kind = locals.find_definition(node, bufnr)
  return vim.tbl_contains(types, kind)
end, { force = true })

query.add_predicate("kind-eq?", function(match, _, _, pred)
  local node = u(match, pred[2])
  local types = { unpack(pred, 3) }
  if not node then
    return true
  end
  return vim.tbl_contains(types, node:type())
end, { force = true })
