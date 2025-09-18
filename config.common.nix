{ config, pkgs, lib, inputs, ... }:

{

  # macOS system configuration
  system.defaults = {
    # Global system settings
    NSGlobalDomain = {
      ApplePressAndHoldEnabled = false;       # Disable accents menu
      NSDocumentSaveNewDocumentsToCloud = false; # Save to disk by default
    };

    # Dock settings
    dock = {
      tilesize = 48;              # Dock icon size
    };
  };

  # Disable nix-darwin's Nix management (using Determinate Nix)
  nix.enable = false;

  # System packages (global system tools)
  environment.systemPackages = with pkgs; [
    # Essential system tools only - CLI tools managed by home-manager
    nixfmt-rfc-style
    inputs.nix-darwin.packages.${pkgs.system}.default
    nix-prefetch
  ];

  # Window management services
  services.yabai = {
    enable = true;
    enableScriptingAddition = true;
    config = {
      layout = "bsp";
      top_padding = 0;
      bottom_padding = 0;
      left_padding = 0;
      right_padding = 0;
      window_gap = 4;

      # Mouse settings
      mouse_follows_focus = "off";
      mouse_modifier = "ctrl";
      mouse_action1 = "move";
      mouse_action2 = "resize";
      mouse_drop_action = "stack";
    };
    extraConfig = ''
    '';
  };
  services.skhd.enable = true;

  # Enable Touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # Set shell for all users and configure environment
  programs.zsh = {
    enable = true;
    # Add home-manager profile to PATH in zsh
    interactiveShellInit = ''
      # Ensure home-manager profile is in PATH
      export PATH="/etc/profiles/per-user/$USER/bin:$PATH"
    '';
  };
  environment.shells = [ pkgs.zsh ];

  # Enable home-manager environment integration
  environment.pathsToLink = [ "/etc/profile.d" ];

  # Add home-manager packages to PATH (prepend to ensure they take precedence)
  environment.systemPath = [ "/etc/profiles/per-user/parkerhenderson/bin" ];

  # Environment variables to ensure proper nix integration
  environment.variables = {
    # Ensure nix-darwin profile is sourced
    NIX_PROFILES = "/nix/var/nix/profiles/default /etc/profiles/per-user/parkerhenderson";
  };

  # System activation script to refresh PATH in running terminals
  system.activationScripts.afterUserActivation.text = ''
    # Send SIGUSR1 to all zsh processes to reload environment
    /usr/bin/pkill -USR1 zsh 2>/dev/null || true

    # Also trigger a PATH refresh for open terminals by writing to a marker file
    echo "$(date): PATH refreshed after darwin-rebuild" > /tmp/.darwin-rebuild-complete
  '';

  # Set nixpkgs architecture
  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  # macOS system version (this should match your current macOS version)
  system.stateVersion = 4;

  # Homebrew configuration for GUI applications
  homebrew = {
    enable = true;
    # Automatically clean up old/unused packages
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
    };
    # Common GUI Applications (Casks) across all machines
    casks = [
      # Terminal and Development
      "ghostty"
      "cursor"
      "orbstack"

      # Communcation & productivity
      "beeper"
      "notion-calendar"
      "thebrowsercompany-dia"
      "obsidian"
      "mimestream"
      "rescuetime"

      # Media
      "spotify"
      "cleanshot"

      # Utilities
      "betterdisplay"
      "spaceman"
      "dropbox"
      "raycast"
    ];
    masApps = {
      things3 = 904280696;
    };
    # Common taps
    taps = [
      "homebrew/cask"
    ];
  };
}
