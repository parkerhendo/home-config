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
    coreutils
    darwin.trash
    fd
    ffmpeg
    fzf
    gh
    git
    neovim
    neofetch
    nixfmt
    parallel
    ripgrep
    rustup
    tmux
    tree
    yabai
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
