{ config, pkgs, lib, ... }:

{
  imports = [
    ../../home.common.nix
  ];

  # User information (profile-specific)
  home.username = "parker";
  home.homeDirectory = "/Users/parker";

  # Global npm packages via bun
  home.activation.installGlobalNpmPackages = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bun}/bin/bun install -g agent-browser 2>/dev/null || true
    ${pkgs.nodejs_22}/bin/npm install -g @tobilu/qmd 2>/dev/null || true
  '';

  # Zephyr-specific packages
  home.packages = with pkgs; [
    # Add zephyr-specific packages here
    lumen
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
    "lumen".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/home-config/dotfiles/lumen";
    ".prompts".source = ../../prompts;
  };
}
