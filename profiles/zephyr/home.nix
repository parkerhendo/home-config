{ config, pkgs, lib, ... }:

{
  imports = [
    ../../home.common.nix
  ];

  # User information (profile-specific)
  home.username = "parker";
  home.homeDirectory = "/Users/parker";

  # Global packages via npm (native addons don't compile with bun)
  home.activation.installGlobalPackages = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export NPM_CONFIG_PREFIX="$HOME/.npm-global"
    export NPM_CONFIG_IGNORE_SCRIPTS=false
    ${pkgs.nodejs_24}/bin/npm install -g agent-browser 2>/dev/null || true
    ${pkgs.nodejs_24}/bin/npm install -g @tobilu/qmd 2>/dev/null || true
    ${pkgs.nodejs_24}/bin/npm install -g @readwise/cli 2>/dev/null || true
  '';

  # Zephyr-specific packages
  home.packages = with pkgs; [
    # Add zephyr-specific packages here
    railway
    go
    bun

    # rust - use rustup to manage toolchain
    rustup
  ];

  # File management - symlink essential dotfiles (paths are profile-specific)
  home.file = {
    # Claude (mkOutOfStoreSymlink for editable files)
    ".claude/CLAUDE.md".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/home-config/dotfiles/claude/CLAUDE.md";
    ".claude/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/home-config/dotfiles/claude/settings.json";
    ".claude/statusline-command.sh".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/home-config/dotfiles/claude/statusline-command.sh";
    ".claude/commands".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/home-config/dotfiles/claude/commands";
    ".claude/skills".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/home-config/dotfiles/claude/skills";
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
