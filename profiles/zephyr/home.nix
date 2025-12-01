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
    perf
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
    # Add zephyr-specific file symlinks here
  };

  # XDG config files (paths are profile-specific)
  xdg.configFile = {
    # Add zephyr-specific XDG config files here
  };
}
