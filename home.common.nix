{ pkgs, inputs, ... }:

{
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
    parallel
    ripgrep
    tmux

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

  # Essential programs
  programs.home-manager.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
