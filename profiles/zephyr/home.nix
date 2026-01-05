{ config, pkgs, ... }:

{
  imports = [
    ../../home.common.nix
  ];

  # User information (profile-specific)
  home.username = "parker";
  home.homeDirectory = "/Users/parker";

  # Zephyr-specific packages
  home.packages = with pkgs; [
    # Add zephyr-specific packages here
    railway
    go

    # rust stuff
    rustc
    cargo
    rustfmt
    clippy
  ];

  # File management - symlink essential dotfiles (paths are profile-specific)
  home.file = {
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
    ".prompts".source = ../../prompts;
  };
}
