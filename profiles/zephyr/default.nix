{ config, inputs, ... }:

{
  imports = [
    ../../config.common.nix
  ];

  nixpkgs.overlays = [
    (final: prev: {
      lumen = final.rustPlatform.buildRustPackage {
        pname = "lumen";
        version = "2.8.1";
        src = inputs.lumen;
        cargoHash = "sha256-40PPq06tyYs6m/8OHCZ8PSaeiTR/22Q5Vdq7YD1YUbY=";
        doCheck = false;
        nativeBuildInputs = [ final.pkg-config ];
        buildInputs = final.lib.optionals final.stdenv.isDarwin [
          final.apple-sdk_15
        ];
        meta.mainProgram = "lumen";
      };
    })
  ];

  networking.computerName = "zephyr";
  networking.hostName = "zephyr";

  # Set primary user for user-specific options
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
      "/Applications/Reader.app"
      "/Applications/Obsidian.app"
    ];
  };

  # Define user account
  users.users.parker = {
    name = "parker";
    home = "/Users/parker";
  };
  # Zephyr-specific homebrew packages (additional to common ones)
  homebrew.casks = [
    # Add zephyr-specific casks here
    "selfcontrol"
    "google-chrome"
    "orbstack"
    "figma@beta"
    "conductor"
  ];

  homebrew.brews = [
    "steveyegge/beads/bd"
  ];

  homebrew.masApps = {
    # Add zephyr-specific Mac App Store apps here
  };

  # Zephyr-specific system configuration
  # Any other zephyr-specific darwin/system settings go here
}
