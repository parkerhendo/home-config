{ pkgs, ... }: let
  unstable = import <nixpkgs-unstable> {
    config.allowUnfree = true;
  };
in {
  home.username = "parker";
  home.homeDirectory = "/Users/parker";
  home.stateVersion = "22.11";

  home.packages = with pkgs; [
    bat
    btop
    coreutils
    darwin.trash
    claude-code
    codex
    fd
    ffmpeg
    fzf
    unstable.gemini-cli
    gh
    git
    lazygit
    neovim
    neofetch
    nixfmt
    nodejs
    parallel
    ripgrep
    rustup
    skhd
    tmux
    tree
    yabai
    yt-dlp
  ];

  programs.git = {
    enable = true;
    includes = [{ path = "~/.gitconfig"; }];
  };

  programs.home-manager.enable = true;

  programs.nix-index-database.comma.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
