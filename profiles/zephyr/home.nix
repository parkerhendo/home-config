{ pkgs, inputs, ... }:

{
  imports = [
    ../../home.common.nix
  ];

  # User information (profile-specific)
  home.username = "parkerhenderson";
  home.homeDirectory = "/Users/parkerhenderson";
  home.stateVersion = "22.11";

  # Zephyr-specific packages
  home.packages = with pkgs; [
    # Add zephyr-specific packages here
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