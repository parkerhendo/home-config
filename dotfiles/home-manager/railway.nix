{ pkgs, ... }: let
  unstable = import <nixpkgs-unstable> {
    config.allowUnfree = true;
  };
in {
  home.username = "parker";
  home.homeDirectory = "/Users/parker";
  home.stateVersion = "22.11";

  home.packages = with pkgs; [
    atuin
    bat
    btop
    bun
    caddy
    claude-code
    coreutils
    codex
    darwin.trash
    fd
    ffmpeg
    fzf
    unstable.gemini-cli
    gh
    git
    lazygit
    nodejs_24
    python312
    neovim
    neofetch
    nixfmt
    parallel
    postgresql_16
    ripgrep
    rustup
    tmux
    tree
    yabai
    yt-dlp
    skhd
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
