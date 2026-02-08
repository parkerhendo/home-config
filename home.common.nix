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

    # AI Stuff
    amp-cli
    codex
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
    nodejs_20
    parallel
    ripgrep
    tmux

    # Media and utilities
    ffmpeg
    neofetch
    yt-dlp

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

  home.sessionVariables = {
    RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
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
