# Home Configuration Repo Guidelines

## Commands
- Format code: `:Format` in Neovim (configured in LSP setup)
- Toggle ESLint: `:ToggleESLint` in Neovim
- Lint prose: Vale is configured for markdown files

## Code Style
- Lua: Formatting via stylua
- TypeScript/JavaScript: 
  - Use Prettier (auto-detected when .prettierrc exists)
  - ESLint for linting (auto-detected from .eslintrc.*)
- OCaml: Formatted with ocamlformat
- Format on save is enabled for all files
- Respect project-specific formatting configs

## Conventions
- Configuration files follow Nix, Lua, and shell scripting best practices
- Neovim plugins are managed via lazy.nvim
- Keep dotfiles modular and well-commented
- Use consistent naming patterns across configuration files