{
  description = "Ephemeral agent-sandbox microVMs on macOS (microvm.nix + vfkit + vmnet-helper)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    # For packages not yet in 25.11 (pi-coding-agent, ghui).
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, microvm }:
    let
      lib = nixpkgs.lib;

      # ---------------- knobs ----------------
      user = "parker";
      uid = 501;              # `id -u` on the mac; must match for virtiofs ownership
      slots = 4;              # size of the VM pool (vm-1 .. vm-N); slot must stay <= 9 (MAC scheme)
      vcpu = 6;
      mem = 16384;            # MB
      storeOverlaySizeMB = 32768;  # per-slot writable /nix/store overlay (warm build cache)
      homeSizeMB = 65536;          # per-slot persistent /home (agent logins survive restarts)
      stateBase = "/Users/${user}/.local/state/agentvms";
      # ----------------------------------------

      guestSystem = "aarch64-linux";
      hostSystem = "aarch64-darwin";
      hostPkgs = nixpkgs.legacyPackages.${hostSystem};

      # Packages missing from 25.11; applied as an overlay (inline module in
      # mkSlot) so guest package lists reference them via the normal `pkgs`.
      unstablePkgs = import nixpkgs-unstable {
        system = guestSystem;
        config.allowUnfree = true;
      };
      unstableOverlay = final: prev: {
        inherit (unstablePkgs) pi-coding-agent ghui;
      };

      authorizedKeysPath = ./authorized_keys;
      authorizedKeys =
        if builtins.pathExists authorizedKeysPath then
          builtins.filter (k: k != "")
            (lib.splitString "\n" (lib.fileContents authorizedKeysPath))
        else
          [ ];

      slotNames = map (n: "vm-${toString n}") (lib.range 1 slots);

      mkSlot = n:
        lib.nameValuePair "vm-${toString n}" (lib.nixosSystem {
          system = guestSystem;
          specialArgs.agentvm = {
            inherit user uid stateBase vcpu mem
              storeOverlaySizeMB homeSizeMB authorizedKeys hostPkgs;
            slot = n;
          };
          modules = [
            microvm.nixosModules.microvm
            { nixpkgs.overlays = [ unstableOverlay ];
              nixpkgs.config.allowUnfree = true; }  # claude-code, ngrok
            ./modules/agent-vm.nix
          ];
        });
    in
    {
      nixosConfigurations = lib.listToAttrs (map mkSlot (lib.range 1 slots));

      # `nix build .#vm-1` (from aarch64-darwin) -> runner script wrapping vfkit
      packages.${hostSystem} = lib.genAttrs slotNames
        (name: self.nixosConfigurations.${name}.config.microvm.declaredRunner);
    };
}
