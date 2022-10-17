export ZSH="/Users/parkerhenderson/.oh-my-zsh"

ZSH_THEME="robbyrussell"

plugins=(git)

source $ZSH/oh-my-zsh.sh

alias ckit="~/ckit/bin/ckit"
alias vi="nvim"
alias tmux-start="~/dotfiles/script/tmux-start.sh"
alias tmux-work="~/dotfiles/script/tmux-work.sh"

# Paths
export NINJA_DIR=$HOME/ninja/ninja
export PATH=$PATH:$NINJA_DIR
export CKIT_DIR=$HOME/ckit
export PATH=$PATH:$CKIT_DIR/bin
export PATH=$HOME/.radicle/bin:$PATH
export PATH="/Applications/CMake.app/Contents/bin":"$PATH"

eval $(thefuck --alias)

# plugins
plugins=(vi-mode)

# Enable vi mode
bindkey -v
bindkey -M vicmd 'V' edit-command-line

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
