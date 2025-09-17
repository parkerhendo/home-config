{ pkgs, inputs, ... }: 

{
  # User information
  home.username = "parkerhenderson";
  home.homeDirectory = "/Users/parkerhenderson";
  home.stateVersion = "22.11";

  # Common packages across all machines
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
    gh
    git
    lazygit
    neovim
    nixfmt-rfc-style
    parallel
    ripgrep
    tmux
    
    # Media and utilities
    ffmpeg
    neofetch
    yt-dlp
  ];

  # Git configuration
  programs.git = {
    enable = true;
    includes = [{ path = "~/.gitconfig"; }];
  };

  # Essential programs
  programs.home-manager.enable = true;
  
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # File management - symlink essential dotfiles
  home.file = {
    # Shell profile
    ".zprofile".source = ../../dotfiles/zprofile;
    
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

  # XDG config files
  xdg.configFile = {
    "nvim".source = ../../dotfiles/nvim;
    "atuin".source = ../../dotfiles/atuin;
    "ghostty".source = ../../dotfiles/ghostty;
    "hammerspoon".source = ../../dotfiles/hammerspoon;
  };
}