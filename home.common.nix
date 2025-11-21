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

  # Set RUST_SRC_PATH for rust-analyzer to find standard library source
  home.sessionVariables = {
    RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
  };
}
