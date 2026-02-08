autoload -Uz add-zsh-hook

# gruvbox colors (muted variants)
GRV_AQUA=$'\e[38;2;131;165;152m'      # #83a598
GRV_GREEN=$'\e[38;2;152;151;26m'      # #98971a
GRV_ORANGE=$'\e[38;2;214;93;14m'      # #d65d0e
GRV_GRAY=$'\e[38;2;146;131;116m'      # #928374

prompt_pwd() {
  print -n "%{$GRV_AQUA%}%1~"
}

prompt_timer() {
  local timer_out=$(timer status 2>/dev/null)
  if [[ "$timer_out" != "Not tracking" && -n "$timer_out" ]]; then
    print -n "%{$GRV_GRAY%}[$timer_out] %{$reset_color%}"
  fi
}

prompt_arrow() {
  # first space here is non-breaking, so we can search for it with tmux easily
  print "%{$GRV_GRAY%} | %{$reset_color%}"
}

ZSH_MAIN_PROMPT="$(prompt_arrow)"

git_prompt_status() {
  # Simple git branch detection without external dependencies
  if git rev-parse --git-dir > /dev/null 2>&1; then
    local branch=$(git branch --show-current 2>/dev/null)
    local git_dir=$(git rev-parse --git-dir 2>/dev/null)
    rebase_info=""

    # Check if we're in a rebase state
    if [ -d "$git_dir/rebase-merge" ] || [ -d "$git_dir/rebase-apply" ]; then
      # Get the short hash of the commit being applied
      local commit_hash=$(git rev-parse --short HEAD 2>/dev/null)
      if [ -n "$commit_hash" ]; then
        rebase_info=" %{$GRV_ORANGE%}($commit_hash)"
      fi
    fi

    if [ -n "$branch" ]; then
      # Use a different variable name to avoid conflicts
      local git_changes=$(git status --porcelain 2>/dev/null)
      if [ -n "$git_changes" ]; then
        branch_color="%{$GRV_ORANGE%}"
      else
        branch_color="%{$GRV_GREEN%}"
      fi

      git_branch=" $branch"

      PROMPT='$(prompt_timer)$(prompt_pwd)$branch_color$git_branch$rebase_info$ZSH_MAIN_PROMPT'
    else
      PROMPT='$(prompt_timer)$(prompt_pwd)$rebase_info$ZSH_MAIN_PROMPT'
    fi
  else
    PROMPT='$(prompt_timer)$(prompt_pwd)$ZSH_MAIN_PROMPT'
  fi
  zle && zle reset-prompt
}

setup_git_prompt_status() {
  git_prompt_status

  # Add hooks if available
  if command -v add-zsh-hook >/dev/null 2>&1; then
    add-zsh-hook precmd  git_prompt_status
    add-zsh-hook preexec git_prompt_status
  fi
}

# single-quote comments are important here!
PROMPT='$(prompt_timer)$(prompt_pwd)$ZSH_MAIN_PROMPT'
PROMPT2='%{$GRV_ORANGE%}%_%{$reset_color%}%{$GRV_GRAY%} | %{$reset_color%}'
SPROMPT="correct "%R" to "%r' ? ([Y]es/[N]o/[E]dit/[A]bort) '

