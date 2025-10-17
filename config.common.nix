{  pkgs, inputs, ... }:

{

# Keyboard configuration
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToEscape = true;
  };

  # macOS system configuration
  system.defaults = {
    # Global system settings
    CustomSystemPreferences = {
      NSGlobalDomain = {
        NSRequiresAquaSystemAppearance = true;
      };
    };

    NSGlobalDomain = {
      ApplePressAndHoldEnabled = false;       # Disable accents menu
      NSDocumentSaveNewDocumentsToCloud = false; # Save to disk by default
      NSUseAnimatedFocusRing = false; # disable focus ring animation
      NSWindowResizeTime = 0.001; # increase window resize speed
      InitialKeyRepeat = null; # disable key repeat
      AppleFontSmoothing = 0; # force sub-pixel anti-aliasing
    };

    # Dock settings
    dock = {
      orientation = "right";
      tilesize = 48;              # Dock icon size
      autohide = true;            # autohide dock
      autohide-delay = 0.0;         # show/hide without delay
      launchanim = false; # disable launch animation
      show-recents = false; # don't show recently used apps
      mru-spaces = false; # disable automatic rearranging of spaces (literally the most insane behavior to enable by default)
    };

    # Screenshot settings
    screencapture = {
      "include-date" = true; # include datetime in screenshot title
      location = "~/Documents/Dropbox/Screenshots"; # save screenshots to dropbox
    };

    # Menubar clock settings
    menuExtraClock = {
      Show24Hour = true;
      ShowDayOfMonth = true;
      ShowDayOfWeek = false;
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
      window_placement = "second_child";
      window_shadow = "float";
      split_ratio = "0.70";
      top_padding = 0;
      bottom_padding = 0;
      left_padding = 0;
      right_padding = 0;
      window_gap = 4;

      # Mouse settings
      mouse_follows_focus = "off";
      focus_follows_mouse = "off";
      mouse_modifier = "ctrl";
      mouse_action1 = "move";
      mouse_action2 = "resize";
      mouse_drop_action = "stack";
    };
    extraConfig = ''
      sudo yabai --load-sa
      yabai -m signal --add event=dock_did_restart action="sudo yabai --load-sa"
      yabai -m signal --add event=dock_did_restart action="yabai -m config window_shadow float"

      ensure_space() {
        index="$1"
        if ! yabai -m query --spaces | /usr/bin/grep -q "\"index\": $index"; then
          yabai -m space --create >/dev/null 2>&1
          until yabai -m query --spaces | /usr/bin/grep -q "\"index\": $index"; do
            /bin/sleep 0.1
          done
        fi
      }

      ensure_space 2
      ensure_space 3
      ensure_space 4

      yabai -m space 2 --layout bsp
      yabai -m space 3 --layout bsp

      yabai -m rule --add app="System Preferences"                    manage=off
      yabai -m rule --add app="About This Mac"                        manage=off
      yabai -m rule --add app="App Store"                             manage=off
      yabai -m rule --add app="Activity Monitor"                      manage=off
      yabai -m rule --add app="Preview"                               manage=off
      yabai -m rule --add app="zoom.us"                               manage=off
      yabai -m rule --add app="Spotify"                               manage=off
      yabai -m rule --add app="CleanShot X"                           manage=off
      yabai -m rule --add app="Loom"                                  manage=off
      yabai -m rule --add app="Things 3"                              manage=off

      yabai -m rule --add app="Ghostty"                               space=^1
      yabai -m rule --add app="Dia"                                   space=^2
      yabai -m rule --add app="Linear"                                space=^2
      yabai -m rule --add app="Discord"                               space=^3
      yabai -m rule --add app="Amie"                                  space=^3
      yabai -m rule --add app="Slack"                                 space=^3
      yabai -m rule --add app="Mimestream"                            space=^3
      yabai -m rule --add app="Texts"                                 space=^3
      yabai -m rule --add app="Obsidian"                              space=^3
      yabai -m rule --add app="Figma Beta"                            space=^4

      echo "yabai configuration loaded..."
    '';
  };
  services.skhd = {
    enable = true;
    skhdConfig = ''
      # YABAI config
      alt + ctrl + cmd - r            : yabai --restart-service
      alt + ctrl - j                  : yabai -m window --focus stack.next || yabai -m window --focus next || yabai -m window --focus first
      alt + ctrl - k                  : yabai -m window --focus stack.prev || yabai -m window --focus prev || yabai -m window --focus last
      alt + ctrl + cmd - j            : yabai -m window --swap next
      alt + ctrl + cmd - k            : yabai -m window --swap prev

      # Focus Spaces
      alt + ctrl - p                  : yabai -m space --focus prev || yabai -m space --focus last
      alt + ctrl - n                  : yabai -m space --focus next || yabai -m space --focus first
      alt + ctrl - tab                : yabai -m space --focus recent
      alt + ctrl - 1                  : yabai -m space --focus 1
      alt + ctrl - 2                  : yabai -m space --focus 2
      alt + ctrl - 3                  : yabai -m space --focus 3
      alt + ctrl - 4                  : yabai -m space --focus 4
      alt + ctrl - 5                  : yabai -m space --focus 5
      alt + ctrl - 6                  : yabai -m space --focus 6
      alt + ctrl - 7                  : yabai -m space --focus 7
      alt + ctrl - 8                  : yabai -m space --focus 8
      alt + ctrl - 9                  : yabai -m space --focus 9
      # 0x18 = -
      alt + ctrl - 0x18               : yabai -m space --create ; yabai -m space --focus last
      # 0x1B = =
      alt + ctrl - 0x1B               : yabai -m space --destroy ; yabai -m space --focus last

      # Move window to space
      ctrl + shift - 1                : yabai -m window --space 1 ; yabai -m space --focus 1
      ctrl + shift - 2                : yabai -m window --space 2 ; yabai -m space --focus 2
      ctrl + shift - 3                : yabai -m window --space 3 ; yabai -m space --focus 3
      ctrl + shift - 4                : yabai -m window --space 4 ; yabai -m space --focus 4
      ctrl + shift - 5                : yabai -m window --space 5 ; yabai -m space --focus 5
      ctrl + shift - 6                : yabai -m window --space 6 ; yabai -m space --focus 6
      ctrl + shift - 7                : yabai -m window --space 7 ; yabai -m space --focus 7
      ctrl + shift - 8                : yabai -m window --space 8 ; yabai -m space --focus 8
      ctrl + shift - 9                : yabai -m window --space 9 ; yabai -m space --focus 9

      # General
      alt + ctrl + shift - backspace  : yabai -m space --balance
      alt + ctrl - h                  : yabai -m window --resize left:-60:0
      alt + ctrl - l                  : yabai -m window --resize right:60:0
      alt + ctrl - f                  : yabai -m window --toggle zoom-fullscreen
      alt + ctrl - r                  : yabai -m window --toggle split
      alt + ctrl - v                  : yabai -m space --mirror y-axis
      alt + ctrl - space              : yabai -m window --toggle float; yabai -m window --grid 8:8:1:1:6:6

      # layouts
      alt + ctrl + cmd + shift - b    : yabai -m space --layout bsp
      alt + ctrl + cmd + shift - f    : yabai -m space --layout float
      alt + ctrl + cmd + shift - s    : yabai -m space --layout stack

      # manipulate windows
      alt + ctrl - t                  : yabai -m window --toggle sticky ; yabai -m window --toggle float

      # Navigating stacks
      alt + ctrl + cmd - a            : yabai -m window --stack recent;
    '';
  };

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

      # Communcation & productivity
      "beeper"
      "claude"
      "notion-calendar"
      "thebrowsercompany-dia"
      "obsidian"
      "mimestream"
      "rescuetime"
      "1password"

      # Media
      "dropbox"
      "spotify"
      "cleanshot"
      "ogdesign-eagle"
      "zotero"

      # Utilities
      "bartender"
      "spaceman"
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
