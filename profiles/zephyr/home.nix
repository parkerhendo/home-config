{ pkgs, ... }:

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
    # Claude
    ".claude/CLAUDE.md".source = ../../dotfiles/claude/CLAUDE.md;
    ".claude/settings.json".source = ../../dotfiles/claude/settings.json;
    ".claude/statusline-command.sh".source = ../../dotfiles/claude/statusline-command.sh;
  };

  # XDG config files (paths are profile-specific)
  xdg.configFile = {
    # Add zephyr-specific XDG config files here
  };
}
