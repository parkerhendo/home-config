{ pkgs, ... }: let
  unstable = pkgs;
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
    parallel
    python312
    ripgrep
    rustup
    skhd
    tmux
    tree
    claude-code
    unstable.gemini-cli
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
