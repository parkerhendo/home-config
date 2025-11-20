{ pkgs, ... }:

{

  home.stateVersion = "24.11";
  # Essential programs
  programs.home-manager.enable = true;

  # nixpkgs.config = {
  #   # PROPRIETARY SOFTWARE
  #   allowUnfree = true;
  # };

  # Common packages across all machines
  home.packages = with pkgs; [
    # AI Stuff
    amp-cli
    codex
    claude-code
    gemini-cli

    # Shell and terminal utilities
    atuin
    bat
    btop
    coreutils
    darwin.trash
    fd
    fzf
    tree
    jq

    # Development tools
    gh
    git
    lazygit
    neovim
    nodejs_20
    parallel
    ripgrep
    tmux

    # rust stuff
    rustc
    cargo
    rust-analyzer
    rustfmt
    clippy

    # Media and utilities
    ffmpeg
    neofetch
    yt-dlp

    # nix
    niv
  ];

  # Git configuration (no paths)
  programs.git = {
    enable = true;
    includes = [{ path = "~/.gitconfig"; }];
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
