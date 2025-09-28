autoload -Uz add-zsh-hook

if [ "$(uname)" = "Darwin" ]; then
  PROMPTCOLOR=blue
else
  PROMPTCOLOR=magenta
fi

if [ "$(whoami)" = "root" ]; then
  PROMPTCOLOR=red
fi

prompt_pwd() {
  print -n "%{$fg[$PROMPTCOLOR]%}"
  print -n "%50<...<%3~"
}

prompt_arrow() {
  # first space here is non-breaking, so we can search for it with tmux easily
  print "%{$reset_color%} > "
}

ZSH_MAIN_PROMPT="$(prompt_arrow)"

git_prompt_status() {
  # Simple git branch detection without external dependencies
  if git rev-parse --git-dir > /dev/null 2>&1; then
    local branch=$(git branch --show-current 2>/dev/null)
    if [ -n "$branch" ]; then
      local git_status=$(git status --porcelain 2>/dev/null)
      if [ -n "$git_status" ]; then
        branch_color="%{$fg[red]%}"  # Has changes
      else
        branch_color="%{$fg[green]%}"  # Clean
      fi
      
      truncate_length=20
      if [ ${#branch} -gt $truncate_length ]; then
        git_branch=" ...${branch: -$truncate_length}"
      else
        git_branch=" $branch"
      fi
      
      PROMPT='$(prompt_pwd)$branch_color$git_branch$ZSH_MAIN_PROMPT'
    else
      PROMPT='$(prompt_pwd)$ZSH_MAIN_PROMPT'
    fi
  else
    PROMPT='$(prompt_pwd)$ZSH_MAIN_PROMPT'
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
PROMPT='$(prompt_pwd)$ZSH_MAIN_PROMPT'
PROMPT2='%{$fg[yellow]%}%_%{$reset_color%} > '
SPROMPT="correct "%R" to "%r' ? ([Y]es/[N]o/[E]dit/[A]bort) '

