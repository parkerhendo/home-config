{ config, pkgs, ... }:

{
  imports = [
    ../../home.common.nix
  ];

  # User information (profile-specific)
  home.username = "parkerhenderson";
  home.homeDirectory = "/Users/parkerhenderson";

  # Phendo-specific packages
  home.packages = with pkgs; [
    # programming languages
    python312
    uv
    ocaml
    go

    # dev utilities
    bun
    k3d
    docker
    nodePackages_latest.vercel

    # rust stuff
    rustc
    cargo
    rustfmt
    clippy

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

    # Claude (mkOutOfStoreSymlink for editable files)
    ".claude/CLAUDE.md".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/home-config/dotfiles/claude/CLAUDE.md";
    ".claude/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/home-config/dotfiles/claude/settings.json";
    ".claude/statusline-command.sh".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/home-config/dotfiles/claude/statusline-command.sh";
    ".claude/commands".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/home-config/dotfiles/claude/commands";
  };

  # XDG config files (paths are profile-specific)
  xdg.configFile = {
    "nvim".source = ../../dotfiles/nvim;
    "atuin".source = ../../dotfiles/atuin;
    "ghostty".source = ../../dotfiles/ghostty;
    "aerospace".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/home-config/dotfiles/aerospace";
    ".prompts".source = ../../prompts;
  };
}
