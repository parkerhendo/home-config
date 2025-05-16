{ pkgs, ... }: let
  unstable = import <nixpkgs-unstable> {
    config.allowUnfree = true;
  };
in {
  home.username = "parkerhenderson";
  home.homeDirectory = "/Users/parkerhenderson";
  home.stateVersion = "22.11";

  home.packages = with pkgs; [
    atuin
    bat
    btop
    coreutils
    darwin.trash
    docker
    fd
    ffmpeg
    fzf
    gh
    git
    go
    k3d
    lazygit
    neovim
    neofetch
    nodePackages_latest.vercel
    nixfmt
    nodejs_20
    parallel
    python312
    ripgrep
    rustup
    skhd
    tmux
    tree
    unstable.claude-code
    uv
    yabai
    yt-dlp
    wifi-password
    watchexec
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
