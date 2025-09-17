{ pkgs, inputs, ... }: 

{
  # User information
  home.username = "parkerhenderson";
  home.homeDirectory = "/Users/parkerhenderson";
  home.stateVersion = "22.11";

  # User packages (CLI tools and development packages)
  home.packages = with pkgs; [
    # Shell and terminal utilities
    atuin
    bat
    btop
    coreutils
    darwin.trash
    fd
    fzf
    tree
    
    # Development tools
    claude-code
    docker
    gh
    git
    go
    k3d
    lazygit
    neovim
    nixfmt-rfc-style
    nodePackages_latest.vercel
    ocaml
    parallel
    python312
    ripgrep
    rustup
    tmux
    uv
    watchexec
    
    # Media and utilities
    ffmpeg
    gemini-cli
    neofetch
    yt-dlp
    
    # Window management moved to system level
  ];

  # Git configuration
  programs.git = {
    enable = true;
    includes = [{ path = "~/.gitconfig"; }];
  };

  # Essential programs
  programs.home-manager.enable = true;
  
  # Note: nix-index-database configuration is handled at the system level

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Import program configurations
  # imports = [
  #   ./programs/zsh.nix
  # ];

  # File management - symlink essential dotfiles
  home.file = {
    # Shell profile
    ".zprofile".source = ../dotfiles/zprofile;
    
    # Git configuration  
    ".gitconfig".source = ../dotfiles/git/gitconfig;
    ".gitalias.txt".source = ../dotfiles/git/gitalias.txt;
    ".gitignore_global".source = ../dotfiles/git/gitignore_global;
    
    # Terminal and shell
    ".tmux.conf".source = ../dotfiles/tmux.conf;
    ".dircolors".source = ../dotfiles/dircolors;
    ".ignore".source = ../dotfiles/ignore;
    
    # Development tools
    ".vale.ini".source = ../dotfiles/vale.ini;
  };

  # XDG config files
  xdg.configFile = {
    "nvim".source = ../dotfiles/nvim;
    "atuin".source = ../dotfiles/atuin;
    "ghostty".source = ../dotfiles/ghostty;
    "hammerspoon".source = ../dotfiles/hammerspoon;
  };
}
