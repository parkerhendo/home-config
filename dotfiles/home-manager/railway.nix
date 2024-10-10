{ pkgs, ... }: {
  home.username = "parker";
  home.homeDirectory = "/Users/parker";
  home.stateVersion = "22.11";

  home.packages = with pkgs; [
    bat
    btop
    coreutils
    darwin.trash
    fd
    ffmpeg
    fzf
    gh
    git
    lazygit
    nodejs_20
    python312
    neovim
    nixfmt
    parallel
    postgresql_16
    ripgrep
    rustup
    tmux
    tree
    yabai
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
