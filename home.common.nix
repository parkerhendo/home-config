{ pkgs, inputs, ... }:

{
  # Common packages across all machines
  home.packages = with pkgs; [
    # Shell and terminal utilities
    atuin
    bat
    btop
    coreutils
    darwin.trash
    fd
    fzf
    tree

    # Development tools
    gh
    git
    lazygit
    neovim
    nixfmt-rfc-style
    parallel
    ripgrep
    tmux

    # Media and utilities
    ffmpeg
    neofetch
    yt-dlp
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
