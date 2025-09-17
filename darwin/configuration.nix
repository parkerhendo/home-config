{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./system.nix
    ./homebrew.nix
  ];

  # Nix configuration
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
    };
    optimise.automatic = true;
    gc = {
      automatic = true;
      interval = { Weekday = 0; Hour = 2; Minute = 0; };
      options = "--delete-older-than 30d";
    };
  };

  # Set primary user for user-specific options
  system.primaryUser = "parkerhenderson";

  # Define user account
  users.users.parkerhenderson = {
    name = "parkerhenderson";
    home = "/Users/parkerhenderson";
  };

  # System packages (global system tools)
  environment.systemPackages = with pkgs; [
    # Essential system tools only - CLI tools managed by home-manager
    nixfmt-rfc-style
  ];

  # Window management services
  services.yabai.enable = true;
  services.skhd.enable = true;

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

  # Set nixpkgs architecture
  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  # macOS system version (this should match your current macOS version)
  system.stateVersion = 4;
}