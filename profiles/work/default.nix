{ config, ... }:

{
  imports = [
    ../../config.common.nix
  ];

  networking.computerName = "work";
  networking.hostName = "work";

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
      "/Applications/Figma Beta.app"
    ];
  };

  # Define user account
  users.users.parker = {
    name = "parker";
    home = "/Users/parker";
  };
  # Phendo-specific homebrew packages (additional to common ones)
  homebrew.casks = [
    # Development tools
    "figma@beta"
    "cursor"
    "orbstack"

    # Communication and productivity
    "discord"
    "slack"
    "loom"
    "zoom"
    "granola"
    "firefox"
    "google-chrome"

    # Utilities
    "betterdisplay"
  ];

  homebrew.masApps = {
    goodnotes = 1444383602;
  };
  # Phendo-specific system configuration
  # Any other phendo-specific darwin/system settings go here
}
