{
  description = "Parker's macOS configuration with nix-darwin + home-manager + nix-homebrew";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    
    nix-darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
    };

    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lumen = {
      url = "github:parkerhendo/lumen";
      flake = false;
    };

    timer-cli = {
      url = "github:parkerhendo/timer-cli";
      flake = false;
    };
  };

  outputs = inputs@{
    self,
    nixpkgs,
    nix-darwin,
    home-manager,
    nix-homebrew,
    nix-index-database,
    lumen,
    timer-cli,
    ...
  }: {
    formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt-rfc-style;

    darwinConfigurations =
      let
        mkDarwinConfig = profileName:
          let
            profilePath = ./profiles/${profileName};
            profileConfig = import (profilePath + "/default.nix");
            homeConfig = import (profilePath + "/home.nix");
            # Extract user from profile config
            profileModule = profileConfig { inherit nixpkgs nix-darwin home-manager inputs; config = {}; pkgs = nixpkgs.legacyPackages.aarch64-darwin; lib = nixpkgs.lib; };
            userName = profileModule.system.primaryUser or profileName;
          in
          nix-darwin.lib.darwinSystem {
            system = "aarch64-darwin";
            modules = [
              (profilePath + "/default.nix")

              nix-homebrew.darwinModules.nix-homebrew
              {
                nix-homebrew = {
                  enable = true;
                  enableRosetta = true;
                  user = userName;
                  mutableTaps = true;
                };
              }

              home-manager.darwinModules.home-manager
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  users.${userName} = homeConfig;
                  extraSpecialArgs = { inherit inputs; };
                  backupFileExtension = "backup";
                  verbose = true;
                };
              }

              nix-index-database.darwinModules.nix-index
              {
                programs.nix-index-database.comma.enable = true;
              }
            ];
            specialArgs = { inherit inputs; };
          };

        profiles = builtins.attrNames (builtins.readDir ./profiles);
        validProfiles = builtins.filter (name:
          builtins.pathExists (./profiles + "/${name}/default.nix")
        ) profiles;
      in
      nixpkgs.lib.genAttrs validProfiles mkDarwinConfig;
  };
}
