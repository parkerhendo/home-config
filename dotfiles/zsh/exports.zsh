if hash nvim 2> /dev/null; then
  export EDITOR="nvim"
else
  export EDITOR="vim"
fi

# Load secrets (API keys, tokens, etc.) from ~/.secrets
[ -f "$HOME/.secrets" ] && source "$HOME/.secrets"
