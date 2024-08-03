{ pkgs, ... }: {
  home.username = "parkerhenderson";
  home.homeDirectory = "/Users/parkerhenderson";
  home.stateVersion = "22.11";

  home.packages = with pkgs; [
    bat
    coreutils
    darwin.trash
    docker
    fd
    ffmpeg
    fzf
    gh
    git
    go
    btop
    lazygit
    neovim
    nixfmt
    nodejs_20
    python312
    ripgrep
    rustup
    skhd
    tmux
    tree
    yabai
    wifi-password
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
