{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, nix-index-database, ... }: let
    systems = "aarch64-darwin";
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    formatter = forAllSystems (system: nixpkgs.${system}.nixfmt);

    defaultPackage.aarch64-darwin =
      home-manager.defaultPackage.aarch64-darwin;

    homeConfigurations = {
      "parkerhenderson@phendo" =
      home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "aarch64-darwin";
          config.allowUnfree = true;
        };

        modules = [ ./phendo.nix nix-index-database.homeModules.nix-index ];
      };

      "parker@zephyr" =
      home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "aarch64-darwin";
          config.allowUnfree = true;
        };

        modules = [ ./zephyr.nix nix-index-database.homeModules.nix-index ];
      };

      "parker@railway" =
      home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "aarch64-darwin";
          config.allowUnfree = true;
        };

        modules = [ ./railway.nix nix-index-database.homeModules.nix-index ];
      };
    };
  };
}
