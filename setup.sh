#!/usr/bin/env bash

function askBeforeRunning() {
  SCRIPT=$1

  read -r -p "$(tput setaf 3)Do you want to execute $SCRIPT?$(tput sgr0) (y/n) " RESP
  if [ "$RESP" == "y" ]; then
    ./"$SCRIPT"
  fi
}

DOTFILE_DIR="$(pwd)/dotfiles"
HOSTNAME="$(hostname -s)"

if [ ! -d ~/.config ]; then
  mkdir ~/.config
fi

touch ~/.hushlogin

ln -si "$DOTFILE_DIR"/atuin ~/.config/atuin
ln -si "$DOTFILE_DIR"/dircolors ~/.dircolors
ln -si "$DOTFILE_DIR"/git/gitconfig ~/.gitconfig
ln -si "$DOTFILE_DIR"/git/gitalias.txt ~/.gitalias.txt
ln -si "$DOTFILE_DIR"/gitconfig/gitignore_global ~/.gitignore_global
ln -si "$DOTFILE_DIR"/ghostty ~/.config/ghostty
ln -si "$DOTFILE_DIR"/ignore ~/.ignore
ln -si "$DOTFILE_DIR"/tmux.conf ~/.tmux.conf
ln -si "$DOTFILE_DIR"/vale.ini ~/.vale.ini
ln -si "$DOTFILE_DIR"/nvim ~/.config/nvim
ln -si "$DOTFILE_DIR"/zprofile ~/.zprofile
ln -si "$DOTFILE_DIR"/zsh ~/.zsh
ln -si "$DOTFILE_DIR"/zshrc ~/.zshrc
ln -si "$DOTFILE_DIR"/yabai/yabairc ~/.yabairc
ln -si "$DOTFILE_DIR"/skhd/skhdrc ~/.skhdrc
ln -si "$(pwd)"/scripts ~/.bin

if [[ $HOSTNAME == "phendo" ]] || [[ $HOSTNAME == "redwood" ]] || [[ $HOSTNAME == "railway" ]]; then
  ln -sni "$DOTFILE_DIR"/hammerspoon ~/.hammerspoon

  askBeforeRunning ./scripts/setup-osx
fi

if [ -d ~/.local/share/nvim/site/pack/packer/start/packer.nvim ]; then
  echo
  git clone --depth 1 https://github.com/wbthomason/packer.nvim\
 ~/.local/share/nvim/site/pack/packer/start/packer.nvim
  echo "On first (n)vim open execute :PackerInstall"
fi

if [ -d ~/.zsh/ ]; then
  mkdir -p ~/.zsh/plugins/
  pushd ~/.zsh/plugins/ > /dev/null || exit;

  git clone https://github.com/mafredri/z -b zsh-flock
  git clone https://github.com/chriskempson/base16-shell
  git clone https://github.com/hlissner/zsh-autopair
  git clone https://github.com/romkatv/gitstatus
  git clone https://github.com/zdharma-continuum/fast-syntax-highlighting
  git clone https://github.com/softmoth/zsh-vim-mode
  git clone https://github.com/romkatv/zsh-defer

  popd > /dev/null || exit;
fi

if command -v nix &> /dev/null; then
  read -p "$(tput setaf 3)Do you want to set up home-manager?$(tput sgr0) (y/n) " RESP

  if [ "$RESP" == "y" ]; then
    ln -si "$DOTFILE_DIR"/home-manager ~/.config/home-manager
    pushd ~/.config/home-manager || return;

    if [[ $HOSTNAME == "phendo" ]]; then
      nix run home-manager -- switch --flake .#parkerhenderson@phendo
    elif [[ $HOSTNAME == "redwood" ]]; then
      nix run home-manager -- switch --flake .#parker@redwood
    elif [[ $HOSTNAME == "railway" ]]; then
      nix run home-manager -- switch --flake .#parker@railway
    else
      echo
      echo "No home-manager configuration found for this machine!"
    fi

    popd
  fi
fi

