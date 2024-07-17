{ pkgs, ... }: {
  home.username = "parker";
  home.homeDirectory = "/Users/parker";
  home.stateVersion = "22.11";

  home.packages = [
    pkgs.bat
    pkgs.coreutils
    pkgs.darwin.trash
    pkgs.fd
    pkgs.ffmpeg
    pkgs.fzf
    pkgs.gh
    pkgs.git
    pkgs.neovim
    pkgs.nixfmt
    pkgs.parallel
    pkgs.ripgrep
    pkgs.rustup
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
