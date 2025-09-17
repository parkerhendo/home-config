{ config, pkgs, lib, ... }:

{
  # Homebrew configuration for GUI applications
  homebrew = {
    enable = true;
    
    # Automatically clean up old/unused packages
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
    };

    # GUI Applications (Casks)
    casks = [
      # Terminal and Development
      "ghostty"
      "thebrowsercompany-dia"
    ];

    # Command line tools that need Homebrew
    brews = [
      # Only include tools that absolutely need Homebrew
      # Most CLI tools should go in home-manager
    ];

    # Additional taps if needed
    taps = [
      "homebrew/cask"
    ];
  };
}
