export ZSH="/Users/parkerhenderson/.oh-my-zsh"

ZSH_THEME="robbyrussell"

plugins=(git)

source $ZSH/oh-my-zsh.sh

alias ckit="~/ckit/bin/ckit"
alias vi="nvim"
alias tmux-start="~/dotfiles/script/tmux-start.sh"
alias tmux-work="~/dotfiles/script/tmux-work.sh"

alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"

export EDITOR="/opt/homebrew/bin/nvim"
export VISUAL="/opt/homebrew/bin/nvim"


# Paths
export NINJA_DIR=$HOME/ninja/ninja
export PATH=$PATH:$NINJA_DIR
export CKIT_DIR=$HOME/ckit
export PATH=$PATH:$CKIT_DIR/bin
export PATH=$PATH:"/User/parkerhenderson/.rustup/toolchains/stable-aarch64-apple-darwin/bin/rust-analyzer"
export PATH="/Applications/CMake.app/Contents/bin":"$PATH"
export FLYCTL_INSTALL="/Users/parkerhenderson/.fly"
export PATH="$FLYCTL_INSTALL/bin:$PATH"

eval $(thefuck --alias)

# plugins
plugins=(vi-mode)

# Enable vi mode
bindkey -v
bindkey -M vicmd 'V' edit-command-line
set -o vi

 export NVM_DIR="$HOME/.nvm"
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
  [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion
# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/parkerhenderson/Downloads/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/parkerhenderson/Downloads/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/parkerhenderson/Downloads/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/parkerhenderson/Downloads/google-cloud-sdk/completion.zsh.inc'; fi
alias lg='lazygit'

# bun completions
[ -s "/Users/parkerhenderson/.bun/_bun" ] && source "/Users/parkerhenderson/.bun/_bun"

# bun
export BUN_INSTALL="/Users/parkerhenderson/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export PATH="/opt/homebrew/opt/ruby/bin: $PATH"

export WASMTIME_HOME="$HOME/.wasmtime"

export PATH="$WASMTIME_HOME/bin:$PATH"

[ -f "/Users/parkerhenderson/.ghcup/env" ] && source "/Users/parkerhenderson/.ghcup/env" # ghcup-env

# opam configuration
[[ ! -r /Users/parkerhenderson/.opam/opam-init/init.zsh ]] || source /Users/parkerhenderson/.opam/opam-init/init.zsh  > /dev/null 2> /dev/null
export PATH="/Users/parkerhenderson/.local/bin:$PATH"
umask 022
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"
