{ config, ... }:

{
  imports = [
    ../../config.common.nix
  ];

  networking.computerName = "parker-work";
  networking.hostName = "parker-work";

  system.primaryUser = "parker";

  # Add home-manager packages to PATH (prepend to ensure they take precedence)
  environment.systemPath = [ "/etc/profiles/per-user/${config.system.primaryUser}/bin" ];

  # Environment variables to ensure proper nix integration
  environment.variables = {
    # Ensure nix-darwin profile is sourced
    NIX_PROFILES = "/nix/var/nix/profiles/default /etc/profiles/per-user/${config.system.primaryUser}";
  };

  system.defaults = {
    dock.persistent-apps = [
      "/Applications/Ghostty.app"
      "/Applications/Dia.app"
      "/Applications/Slack.app"
    ];
  };

  # Define user account
  users.users.parker = {
    name = "parker";
    home = "/Users/parker";
  };

  homebrew.brews = [
    "docker"
    "cargo-binstall"
  ];
  # Phendo-specific homebrew packages (additional to common ones)
  homebrew.casks = [
    # Development tools
    "figma@beta"
    "cursor"

    # Communication and productivity
    "linear-linear"
    "discord"
    "slack"
    "loom"
    "zoom"
    "granola"
    "firefox"
    "google-chrome"

    # Utilities
    "keycastr"
  ];

  homebrew.masApps = {
  };
  # Phendo-specific system configuration
  # Any other phendo-specific darwin/system settings go here
}
