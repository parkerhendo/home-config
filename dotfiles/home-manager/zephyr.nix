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
    unstable.claude-code
    fd
    ffmpeg
    fzf
    gh
    git
    lazygit
    neovim
    neofetch
    nixfmt
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
