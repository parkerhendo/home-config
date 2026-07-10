{ pkgs, config, lib, ... }:
{

  home.stateVersion = "24.11";
  # Essential programs
  programs.home-manager.enable = true;

  # nixpkgs.config = {
  #   # PROPRIETARY SOFTWARE
  #   allowUnfree = true;
  # };

  # Common packages across all machines. The shared list is also installed
  # inside every agent VM guest; anything mac-only stays here.
  home.packages = (import ./agentvms/common-packages.nix pkgs) ++ (with pkgs; [
    # Custom (mac-only)
    timer-cli
    timer-bar

    # Mac-only utilities
    darwin.trash
  ]);

  # Git configuration (no paths)
  programs.git = {
    enable = true;
    includes = [{ path = "~/.gitconfig"; }];
    signing.format = "openpgp";
  };

  programs.zsh = {
    enable = true;
    dotDir = config.home.homeDirectory;
    enableCompletion = false;
    profileExtra = ''
      source ~/.orbstack/shell/init.zsh 2>/dev/null || :
    '';
    initContent = ''
      # zsh-defer is optional - configuration will work without it
      if [ -f ~/.zsh/plugins/zsh-defer/zsh-defer.plugin.zsh ]; then
        source ~/.zsh/plugins/zsh-defer/zsh-defer.plugin.zsh
        ZSH_DEFER_AVAILABLE=true
      else
        ZSH_DEFER_AVAILABLE=false
      fi

      files=(
        exports
        path
        aliases
        bindkeys
        colors
        completion
        functions
        history
        locale
        options
        prompt
        plugins
      )

      for file in $files; do
        source ~/.zsh/$file.zsh
      done

      autoload edit-command-line
      zle -N edit-command-line
      bindkey '^Xe' edit-command-line
    '';
  };

  programs.mise = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # Editable-file symlinks (mkOutOfStoreSymlink). `agentvm` is exposed via
  # `home.sessionPath` below rather than a symlink.
  home.file.".zsh".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/home-config/dotfiles/zsh";
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
    "$HOME/.local/share/mise/shims"
    "$HOME/.local/bin"
    "$HOME/.npm-global/bin"
    "$HOME/.bun/bin"
    "$HOME/home-config/scripts"
    "$HOME/home-config/agentvms/bin"
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
