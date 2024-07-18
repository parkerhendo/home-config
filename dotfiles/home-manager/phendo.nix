{ pkgs, ... }: {
  home.username = "parkerhenderson";
  home.homeDirectory = "/Users/parkerhenderson";
  home.stateVersion = "22.11";

  home.packages = [
    pkgs.atuin
    pkgs.bat
    pkgs.coreutils
    pkgs.darwin.trash
    pkgs.docker
    pkgs.fd
    pkgs.ffmpeg
    pkgs.fzf
    pkgs.gh
    pkgs.git
    pkgs.go
    pkgs.btop
    pkgs.lazygit
    pkgs.neovim
    pkgs.nixfmt
    pkgs.nodejs_20
    pkgs.python312
    pkgs.ripgrep
    pkgs.rustup
    pkgs.skhd
    pkgs.tmux
    pkgs.tree
    pkgs.yabai
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
