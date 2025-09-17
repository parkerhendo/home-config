{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../../config.common.nix
  ];

  # Set primary user for user-specific options
  system.primaryUser = "parker";

  # Define user account
  users.users.parker = {
    name = "parker";
    home = "/Users/parker";
  };
  # Zephyr-specific homebrew packages (additional to common ones)
  homebrew.casks = [
    # Add zephyr-specific casks here
  ];

  homebrew.masApps = {
    # Add zephyr-specific Mac App Store apps here
  };

  # Zephyr-specific system configuration
  # Any other zephyr-specific darwin/system settings go here
}
