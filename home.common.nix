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
    pi-coding-agent

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
    ghui
    git
    mise
    neovim

    parallel
    ripgrep
    tmux

    # Networking
    ngrok

    # Media and utilities
    ffmpeg
    # nix
    niv
  ];

  # Git configuration (no paths)
  programs.git = {
    enable = true;
    includes = [{ path = "~/.gitconfig"; }];
    signing.format = "openpgp";
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Pi coding agent (mkOutOfStoreSymlink for editable files)
  home.file.".pi/agent".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/home-config/dotfiles/pi/agent";

  xdg.enable = true;
  xdg.configFile."lumen".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/home-config/dotfiles/lumen";
  xdg.configFile."tuicr".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/home-config/dotfiles/tuicr";

  # Give Nix a GitHub token so `nix flake update` and github: inputs don't
  # hit the 60 req/hr unauthenticated rate limit. The token itself lives at
  # ~/.config/nix/access-tokens.conf (mode 600, outside the Nix store and
  # outside this repo) and is refreshed from `gh auth token` on every
  # home-manager activation.
  xdg.configFile."nix/nix.conf".text = ''
    !include ${config.home.homeDirectory}/.config/nix/access-tokens.conf
  '';

  home.activation.nixGithubAccessToken = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -eu
    target="$HOME/.config/nix/access-tokens.conf"
    if token="$(${pkgs.gh}/bin/gh auth token 2>/dev/null)" && [ -n "$token" ]; then
      mkdir -p "$HOME/.config/nix"
      umask 077
      printf 'access-tokens = github.com=%s\n' "$token" > "$target.tmp"
      mv "$target.tmp" "$target"
    fi
  '';

  home.sessionPath = [
    "$HOME/.npm-global/bin"
    "$HOME/home-config/scripts"
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
          key = "L";
          context = "files";
          command = "lumen draft | tee >(pbcopy)";
          loadingText = "Generating message...";
        }
        {
          key = "K";
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
