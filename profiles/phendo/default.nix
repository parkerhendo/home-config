{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../../config.common.nix
  ];

  # Phendo-specific homebrew packages (additional to common ones)
  homebrew.casks = [
    # Development tools
    "orbstack"
    "figma"

    # Communication and productivity
    "discord"
    "slack"
    "loom"

    # Media and utilities
    "spotify"
    "cleanshot"
  ];

  homebrew.masApps = {
    things3 = 904280696;
    goodnotes = 1444383602;
  };
  # Phendo-specific system configuration
  # Any other phendo-specific darwin/system settings go here
}
