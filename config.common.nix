{  pkgs, inputs, ... }:

{

  nixpkgs.overlays = [
    (final: prev: {
      codex = inputs.codex-cli-nix.packages.${final.system}.default;
    })
    (final: prev: {
      timer-cli = final.rustPlatform.buildRustPackage {
        pname = "timer-cli";
        version = "0.1.0";
        src = inputs.timer-cli;
        cargoHash = "sha256-GUdfwVL0p3h68WRZZ5yLqMGMdd4Sz+/yjIgTWdqTP7Y=";
        doCheck = false;
        nativeBuildInputs = [ final.pkg-config ];
        buildInputs = final.lib.optionals final.stdenv.isDarwin [
          final.apple-sdk_15
        ];
        meta.mainProgram = "timer";
      };
    })
    (final: prev: {
      timer-bar = final.stdenv.mkDerivation {
        pname = "TimerBar";
        version = "0.1.0";
        src = final.fetchurl {
          url = "https://github.com/parkerhendo/timer-cli/releases/download/v0.1.0/TimerBar-arm64.zip";
          hash = "sha256-1ZwaSwkoKs5FKONqbPJ2GOnW2GwMYy30QzauHyDw3oY=";
        };
        sourceRoot = ".";
        nativeBuildInputs = [ final.unzip ];
        unpackPhase = ''
          unzip $src
        '';
        installPhase = ''
          mkdir -p $out/Applications
          cp -r TimerBar.app $out/Applications/
        '';
      };
    })
  ];

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

    finder = {
      CreateDesktop = false;
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
      "nikitabobko/tap/aerospace"
      "bartender"
      "raycast"
      "betterdisplay"
    ];
    masApps = {
      things3 = 904280696;
    };
  };
}
