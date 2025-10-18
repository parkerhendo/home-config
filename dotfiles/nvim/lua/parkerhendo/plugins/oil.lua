return {
  "stevearc/oil.nvim",
  enable = true,
  lazy = false,
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    ---------------------------------------------------------------------
    -- Helper Methods
    ---------------------------------------------------------------------

    -- Helper function to parse process output
    local function parse_output(proc)
      local result = proc:wait()
      local ret = {}
      if result.code == 0 then
        for line in vim.gsplit(result.stdout, "\n", { plain = true, trimempty = true }) do
          -- Remove trailing slash
          line = line:gsub("/$", "")
          ret[line] = true
        end
      end
      return ret
    end

    -- Build git status cache
    local function new_git_status()
      return setmetatable({}, {
        __index = function(self, key)
          local ignore_proc = vim.system(
            { "git", "ls-files", "--ignored", "--exclude-standard", "--others", "--directory" },
            {
              cwd = key,
              text = true,
            }
          )
          local tracked_proc = vim.system({ "git", "ls-tree", "HEAD", "--name-only" }, {
            cwd = key,
            text = true,
          })
          local ret = {
            ignored = parse_output(ignore_proc),
            tracked = parse_output(tracked_proc),
          }

          rawset(self, key, ret)
          return ret
        end,
      })
    end
    local git_status = new_git_status()

    -- Clear git status cache on refresh
    local refresh = require("oil.actions").refresh
    local orig_refresh = refresh.callback
    refresh.callback = function(...)
      git_status = new_git_status()
      orig_refresh(...)
    end

    -- Oil setup
    require("oil").setup({
      use_default_keymaps = false,

      preview = {
        border = "rounded",
      },

      float = {
        padding = 2,
        max_width = 0,
        max_height = 0,
        border = "rounded",
        win_options = {
          winblend = 0,
          cursorline = true,
          number = false,
          relativenumber = false,
          signcolumn = "no",
        },
        override = function(conf)
          -- Use custom highlight groups
          conf.style = "minimal"
          return conf
        end,
      },

      -- Disable column display for a cleaner look
      columns = {},

      keymaps = {
        ["g?"] = "actions.show_help",
        ["<CR>"] = "actions.select",
        ["<C-s>"] = "actions.select_split",
        ["<C-v>"] = "actions.select_vsplit",
        ["<C-t>"] = "actions.select_tab",
        ["<C-p>"] = "actions.preview",
        ["<C-c>"] = "actions.close",
        ["<C-r>"] = "actions.refresh",
        ["-"] = "actions.parent",
        ["_"] = "actions.open_cwd",
        ["`"] = "actions.cd",
        ["~"] = "actions.tcd",
        ["gs"] = "actions.change_sort",
        ["gx"] = "actions.open_external",
        ["g."] = "actions.toggle_hidden",
        ["q"] = "actions.close",
      },

      view_options = {
        is_hidden_file = function(name, bufnr)
          local dir = require("oil").get_current_dir(bufnr)
          local is_dotfile = vim.startswith(name, ".") and name ~= ".."
          -- if no local directory (e.g. for ssh connections), just hide dotfiles
          if not dir then
            return is_dotfile
          end
          -- dotfiles are considered hidden unless tracked
          if is_dotfile then
            return not git_status[dir].tracked[name]
          else
            -- Check if file is gitignored
            return git_status[dir].ignored[name]
          end
        end,
      },
    })

    -- Gruvbox-themed highlights for oil.nvim
    -- Set highlights after colorscheme loads
    vim.api.nvim_create_autocmd("ColorScheme", {
      pattern = "*",
      callback = function()
        -- File type highlights
        vim.api.nvim_set_hl(0, "OilDir", { link = "GruvboxAqua" })
        vim.api.nvim_set_hl(0, "OilDirIcon", { link = "GruvboxAqua" })
        vim.api.nvim_set_hl(0, "OilLink", { link = "GruvboxPurple" })
        vim.api.nvim_set_hl(0, "OilLinkTarget", { link = "Comment" })
        vim.api.nvim_set_hl(0, "OilFile", { link = "Normal" })
        vim.api.nvim_set_hl(0, "OilCreate", { link = "GruvboxGreen" })
        vim.api.nvim_set_hl(0, "OilDelete", { link = "GruvboxRed" })
        vim.api.nvim_set_hl(0, "OilMove", { link = "GruvboxYellow" })
        vim.api.nvim_set_hl(0, "OilCopy", { link = "GruvboxBlue" })
        vim.api.nvim_set_hl(0, "OilChange", { link = "GruvboxOrange" })

        -- Window highlights to match Telescope
        local normal_bg = vim.api.nvim_get_hl(0, { name = "Normal" }).bg
        local visual_bg = vim.api.nvim_get_hl(0, { name = "Visual" }).bg
        local border_fg = vim.api.nvim_get_hl(0, { name = "GruvboxFg4" }).fg

        vim.api.nvim_set_hl(0, "OilFloat", { bg = normal_bg })
        vim.api.nvim_set_hl(0, "OilFloatBorder", { fg = border_fg, bg = normal_bg })
        vim.api.nvim_set_hl(0, "OilCursorLine", { bg = visual_bg })
      end,
    })

    -- Trigger immediately for current colorscheme
    vim.cmd("doautocmd ColorScheme")

    -- Apply custom highlights to Oil float windows
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "oil",
      callback = function()
        -- Set window-local highlights for Oil buffers
        vim.opt_local.winhighlight = "Normal:OilFloat,FloatBorder:OilFloatBorder,CursorLine:OilCursorLine"
      end,
    })
  end,
}
