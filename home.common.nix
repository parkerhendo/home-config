{ pkgs, config, ... }:
{

  home.stateVersion = "24.11";
  # Essential programs
  programs.home-manager.enable = true;

  # nixpkgs.config = {
  #   # PROPRIETARY SOFTWARE
  #   allowUnfree = true;
  # };

  # Common packages across all machines
  home.packages = with pkgs; [
    # Custom packages
    timer-cli
    timer-bar

    # AI Stuff
    amp-cli
    opencode
    claude-code
    gemini-cli

    # Shell and terminal utilities
    atuin
    bat
    btop
    coreutils
    darwin.trash
    fd
    fzf
    tree
    jq

    # Development tools
    gh
    git
    mise
    neovim
    nodejs_24
    parallel
    ripgrep
    tmux

    # Media and utilities
    ffmpeg
    # nix
    niv
  ];

  # Git configuration (no paths)
  programs.git = {
    enable = true;
    includes = [{ path = "~/.gitconfig"; }];
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  xdg.enable = true;
  xdg.configFile."lumen".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/home-config/dotfiles/lumen";

  home.sessionPath = [
    "$HOME/.npm-global/bin"
  ];

  home.sessionVariables = {
    RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
    NPM_CONFIG_PREFIX = "$HOME/.npm-global";
  };

  programs.lazygit = {
    enable = true;
    settings = {
      customCommands = [
        {
          key = "<c-l>";
          context = "files";
          command = "lumen draft | tee >(pbcopy)";
          loadingText = "Generating message...";
        }
        {
          key = "<c-k>";
          context = "files";
          command = "lumen draft -c {{.Form.Context | quote}} | tee >(pbcopy)";
          loadingText = "Generating message...";
          prompts = [{
            type = "input";
            title = "Context";
            key = "Context";
          }];
        }
      ];
    };
  };
}
