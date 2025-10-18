# Neovim Keymappings Reference

**Leader Key:** `,` (comma)
**Local Leader:** `,` (comma)

## Table of Contents
- [General Mappings](#general-mappings)
- [File Operations](#file-operations)
- [Window Management](#window-management)
- [Movement & Editing](#movement--editing)
- [Telescope (Fuzzy Finder)](#telescope-fuzzy-finder)
- [LSP (Language Server)](#lsp-language-server)
- [Git](#git)
- [Harpoon (File Navigation)](#harpoon-file-navigation)
- [Trouble (Diagnostics)](#trouble-diagnostics)
- [Code Completion (nvim-cmp)](#code-completion-nvim-cmp)
- [Comments](#comments)
- [Surround](#surround)
- [Terminal](#terminal)
- [Utilities](#utilities)

---

## General Mappings

| Mode | Keymap | Action | Description |
|------|--------|--------|-------------|
| n | `<leader>v` | `:update<cr> :source $MYVIMRC<cr>` | Reload Neovim configuration |
| n | `<leader>w` | `:w<cr>` | Save file |
| n | `<leader>q` | `:q<cr>` | Quit |
| n | `<leader>Q` | `:q!<cr>` | Force quit |

## File Operations

| Mode | Keymap | Action | Description |
|------|--------|--------|-------------|
| n | `<leader>e` | `:NvimTreeToggle<cr>` | Toggle file explorer |
| n | `<leader>f` | `telescope.builtin.find_files()` | Find files |
| n | `<leader>g` | `telescope.builtin.live_grep()` | Search in files (live grep) |
| n | `<space>` | `telescope.builtin.buffers()` | List open buffers |

## Window Management

### Navigation
| Mode | Keymap | Action | Description |
|------|--------|--------|-------------|
| n | `<M-j>` | `<C-w>j` | Navigate to window below |
| n | `<M-k>` | `<C-w>k` | Navigate to window above |
| n | `<M-h>` | `<C-w>h` | Navigate to window left |
| n | `<M-l>` | `<C-w>l` | Navigate to window right |

### Resizing
| Mode | Keymap | Action | Description |
|------|--------|--------|-------------|
| n | `<C-S-Left>` | `:vertical resize -5<cr>` | Decrease window width |
| n | `<C-S-Right>` | `:vertical resize +5<cr>` | Increase window width |
| n | `<C-S-Up>` | `:resize +2<cr>` | Increase window height |
| n | `<C-S-Down>` | `:resize -2<cr>` | Decrease window height |

## Movement & Editing

### Navigation
| Mode | Keymap | Action | Description |
|------|--------|--------|-------------|
| n, v | `j` | `gj` (when no count) | Move down by display line |
| n, v | `k` | `gk` (when no count) | Move up by display line |

### Moving Lines
| Mode | Keymap | Action | Description |
|------|--------|--------|-------------|
| v | `J` | `:m '>+1<cr>gv=gv` | Move selected lines down |
| v | `K` | `:m '<-2<cr>gv=gv` | Move selected lines up |

### Clipboard
| Mode | Keymap | Action | Description |
|------|--------|--------|-------------|
| n | `<leader>p` | `"_dP` | Paste without overwriting register |
| n, v | `<leader>y` | `"+y` | Yank to system clipboard |
| n | `<leader>Y` | `"+Y` | Yank line to system clipboard |
| n, v | `<leader>d` | `"_d` | Delete without yanking (black hole register) |

## Telescope (Fuzzy Finder)

### Main Commands
| Mode | Keymap | Action | Description |
|------|--------|--------|-------------|
| n | `<leader>f` | Find files | Find files (including hidden) |
| n | `<leader>g` | Live grep | Search text across files |
| n | `<space>` | Buffers | List and switch between buffers |
| n | `<leader>dd` | Diagnostics | Show all diagnostics |

### Insert Mode (Telescope Picker)
| Keymap | Action | Description |
|--------|--------|-------------|
| `<C-k>` | `actions.move_selection_previous` | Move to previous item |
| `<C-j>` | `actions.move_selection_next` | Move to next item |
| `<C-t>` | Send to Trouble | Send results to Trouble window |
| `<C-q>` | Send to quickfix | Send selected to quickfix list |
| `<C-x>` | Delete buffer | Delete buffer from list |
| `<esc>` | Close | Close Telescope |

### Normal Mode (Telescope Picker)
| Keymap | Action | Description |
|--------|--------|-------------|
| `<c-t>` | Send to Trouble | Send results to Trouble window |
| `q` | Close | Close Telescope |

## LSP (Language Server)

LSP keymaps are only available when an LSP server is attached to the buffer.

| Mode | Keymap | Action | Description |
|------|--------|--------|-------------|
| n | `<leader>rn` | Rename | Rename symbol under cursor |
| n | `<leader>ca` | Code action | Show available code actions |
| n | `gd` | Go to definition | Jump to symbol definition |
| n | `gr` | Go to references | Show references (via Telescope) |
| n | `gi` | Go to implementation | Jump to implementation (via Telescope) |
| n | `<leader>bs` | Buffer symbols | Show document symbols (via Telescope) |
| n | `<leader>ps` | Project symbols | Show workspace symbols (via Telescope) |
| n | `K` | Hover/Diagnostics | Show diagnostics if available, else hover docs |
| n | `<leader>k` | Signature help | Show function signature |
| i | `<C-k>` | Signature help | Show function signature (insert mode) |
| n | `td` | Type definition | Jump to type definition |

### Diagnostics
| Mode | Keymap | Action | Description |
|------|--------|--------|-------------|
| n | `<leader>dd` | All diagnostics | Show all diagnostics (Telescope) |
| n | `do` | Open float | Show diagnostic at cursor |
| n | `dn` | Previous diagnostic | Go to previous diagnostic |
| n | `dp` | Next diagnostic | Go to next diagnostic |

## Git

### Gitsigns
| Mode | Keymap | Action | Description |
|------|--------|--------|-------------|
| n | `<leader>B` | Show full blame | Show full git blame for line |
| n | `<leader>b` | Toggle line blame | Toggle current line blame |

### Git Conflict
Default mappings are enabled:
- `co` - Choose ours
- `ct` - Choose theirs
- `cb` - Choose both
- `c0` - Choose none
- `cn` - Next conflict
- `cp` - Previous conflict

## Harpoon (File Navigation)

| Mode | Keymap | Action | Description |
|------|--------|--------|-------------|
| n | `<leader>m` | Mark file | Add current file to Harpoon |
| n | `<left>` | Toggle menu | Toggle Harpoon quick menu |
| n | `<up>` | Next file | Navigate to next Harpoon file |
| n | `<down>` | Previous file | Navigate to previous Harpoon file |

## Trouble (Diagnostics)

| Mode | Keymap | Action | Description |
|------|--------|--------|-------------|
| n | `<leader>xx` | Toggle Trouble | Open/close Trouble window |
| n | `<leader>xw` | Workspace diagnostics | Show workspace diagnostics |
| n | `<leader>xd` | Document diagnostics | Show document diagnostics |
| n | `<leader>xl` | Location list | Show location list |
| n | `<leader>xq` | Quickfix | Show quickfix list |
| n | `gr` | LSP references | Show LSP references (via Trouble) |

## Code Completion (nvim-cmp)

### Insert Mode
| Keymap | Action | Description |
|--------|--------|-------------|
| `<C-b>` | Scroll docs up | Scroll documentation up |
| `<C-f>` | Scroll docs down | Scroll documentation down |
| `<C-Space>` | Trigger completion | Manually trigger completion |
| `<C-e>` | Abort | Close completion menu |
| `<CR>` | Confirm | Confirm selected item |
| `<Tab>` | Next/Expand | Select next item or expand snippet |
| `<S-Tab>` | Previous/Jump back | Select previous item or jump back in snippet |

## Comments

Comment.nvim provides these operators:

| Mode | Keymap | Action | Description |
|------|--------|--------|-------------|
| n, v | `gc` | Comment line | Toggle line comment |
| n, v | `gb` | Comment block | Toggle block comment |

Examples:
- `gcc` - Toggle comment on current line
- `gc3j` - Comment next 3 lines
- `gcap` - Comment paragraph
- `gbc` - Toggle block comment

## Surround

vim-surround provides these operators:

| Mode | Keymap | Action | Description |
|------|--------|--------|-------------|
| n | `ys{motion}{char}` | Add surrounding | Add surrounding to motion |
| n | `ds{char}` | Delete surrounding | Delete surrounding character |
| n | `cs{old}{new}` | Change surrounding | Change surrounding from old to new |

Examples:
- `ysiw"` - Surround inner word with quotes
- `ds"` - Delete surrounding quotes
- `cs"'` - Change double quotes to single quotes
- `yss)` - Surround entire line with parentheses

## Terminal

| Mode | Keymap | Action | Description |
|------|--------|--------|-------------|
| n | `<leader>t` | Toggle lazygit | Open/close lazygit terminal |
| n | `<leader>T` | Toggle theme | Toggle color theme |

## Utilities

| Mode | Keymap | Action | Description |
|------|--------|--------|-------------|
| n | `<leader>X` | Make executable | Make current file executable (chmod +x) |
| n | `<leader>o` | Open in GitHub | Open current file in GitHub |
| n | `<leader>O` | Open lines in GitHub | Open current file at line in GitHub |

---

## Custom Commands

- `:Format` - Format current buffer using LSP
- `:ToggleESLint` - Toggle ESLint diagnostics

## Notes

- Most keymaps use `silent = true` to avoid showing command output
- LSP keymaps are buffer-local and only available when LSP is attached
- Many plugin keymaps use lazy loading (only loaded when the key is pressed)
- Expression mappings (like `j` and `k`) adapt behavior based on count
