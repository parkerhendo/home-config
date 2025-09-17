{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../../config.common.nix
  ];

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