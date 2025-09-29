# direnv
load_atuin() {
  if hash atuin > /dev/null; then
    eval "$(atuin init zsh --disable-up-arrow)"
    bindkey '^r' atuin-search
  fi
}

# direnv
load_direnv() {
  if hash direnv > /dev/null; then
    eval "$(direnv hook zsh)"
  fi
}

# z for better jumps
load_z() {
  if [ -f ~/.zsh/plugins/z/z.sh ]; then
    source ~/.zsh/plugins/z/z.sh
  fi
}

# better pairs
load_autopair() {
  if [ -f ~/.zsh/plugins/zsh-autopair/autopair.zsh ]; then
    source ~/.zsh/plugins/zsh-autopair/autopair.zsh
  fi
}

# live command highlighting like fish, but faster than zsh-syntax-highlight
load_syntax_highlight() {
  if [ -f ~/.zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh ]; then
    source ~/.zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh

    FAST_HIGHLIGHT_STYLES[precommand]='fg=magenta'
    FAST_HIGHLIGHT_STYLES[commandseparator]='fg=yellow'
    FAST_HIGHLIGHT_STYLES[path]='fg=default'
    FAST_HIGHLIGHT_STYLES[path-to-dir]='fg=default'
    FAST_HIGHLIGHT_STYLES[single-hyphen-option]='fg=yellow'
    FAST_HIGHLIGHT_STYLES[double-hyphen-option]='fg=yellow'
    FAST_HIGHLIGHT_STYLES[back-quoted-argument]='fg=magenta'
    FAST_HIGHLIGHT_STYLES[single-quoted-argument]='fg=red'
    FAST_HIGHLIGHT_STYLES[double-quoted-argument]='fg=red'
    FAST_HIGHLIGHT_STYLES[variable]='fg=red'
    FAST_HIGHLIGHT_STYLES[global-alias]='fg=magenta'

    FAST_HIGHLIGHT[no_check_paths]=1
    FAST_HIGHLIGHT[use_brackets]=1
    FAST_HIGHLIGHT[use_async]=1
  fi
}

# gitstatus - simplified version without gitstatus plugin
load_gitstatus() {
  # Simple git prompt without external dependencies
  if command -v setup_git_prompt_status >/dev/null 2>&1; then
    setup_git_prompt_status
  fi
}

# Load essential plugins immediately
load_atuin # atuin for better history search
load_direnv # direnv for environment management
load_z # I often want to jump somewhere immediately when opening a shell

# Load other plugins with or without defer
if [ "$ZSH_DEFER_AVAILABLE" = "true" ]; then
  # Use zsh-defer for better startup performance
  zsh-defer -t 0.5 load_autopair
  zsh-defer -t 0.5 load_syntax_highlight
  zsh-defer -t 1.0 load_gitstatus
else
  # Load immediately if zsh-defer is not available
  load_autopair
  load_syntax_highlight
  load_gitstatus
fi
