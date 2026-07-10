# Packages shared between the mac host (home-manager) and the agent VM
# guests. Everything in here must exist on both aarch64-darwin and
# aarch64-linux nixpkgs, so mac-only tools (darwin.trash, timer-*) and
# guest-only tools (nodejs_22) live at their respective call sites, not here.
pkgs: with pkgs; [
  # AI stuff
  amp-cli
  opencode
  claude-code
  gemini-cli
  pi-coding-agent

  # Shell and terminal utilities
  atuin
  bat
  btop
  coreutils
  fd
  fzf
  jq
  ripgrep
  tmux
  tree

  # Development tools
  gh
  ghui
  git
  mise
  neovim
  parallel

  # Networking
  ngrok

  # Media and utilities
  ffmpeg
  niv
]
