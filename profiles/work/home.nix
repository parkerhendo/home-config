{ pkgs, ... }:

{
  imports = [
    ../../home.common.nix
  ];

  # User information (profile-specific)
  home.username = "parker";
  home.homeDirectory = "/Users/parker";

  # Phendo-specific packages
  home.packages = with pkgs; [
    # programming languages
    python312
    uv
    ocaml
    rustup
    go

    # dev utilities
    nodejs_20
    wasm-bindgen-cli_0_2_100
    duckdb
    wasm-pack
    mise
    bun
    k3d
    docker
    nodePackages_latest.vercel

    # utilities
    watchexec

  ];

  # File management - symlink essential dotfiles (paths are profile-specific)
  home.file = {
    # Shell profile
    ".zprofile".source = ../../dotfiles/zprofile;
    ".zsh".source = ../../dotfiles/zsh;
    ".zshrc".source = ../../dotfiles/zshrc;

    # Git configuration
    ".gitconfig".source = ../../dotfiles/git/gitconfig;
    ".gitalias.txt".source = ../../dotfiles/git/gitalias.txt;
    ".gitignore_global".source = ../../dotfiles/git/gitignore_global;

    # Terminal and shell
    ".tmux.conf".source = ../../dotfiles/tmux.conf;
    ".dircolors".source = ../../dotfiles/dircolors;
    ".ignore".source = ../../dotfiles/ignore;

    # Development tools
    ".vale.ini".source = ../../dotfiles/vale.ini;
  };

  # XDG config files (paths are profile-specific)
  xdg.configFile = {
    "nvim".source = ../../dotfiles/nvim;
    "atuin".source = ../../dotfiles/atuin;
    "ghostty".source = ../../dotfiles/ghostty;
    ".prompts".source = ../../prompts;
  };
}
