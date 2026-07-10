# Ephemeral agent-sandbox microVM pool (microvm.nix + vfkit + vmnet-helper).
#
# Instantiated by the root flake so guests consume the same home-manager
# profile as the mac host: each VM imports profiles/<name>/home.nix (which
# pulls in home.common.nix), so packages, dotfiles, prompt, and coding
# agents match the host one-to-one instead of being mirrored by hand.
#
# Knobs live in ./config.json -- the single source shared with bin/agentvm,
# so the bash/nix boundary can't drift (user, slot count, state dir, MAC
# scheme). Evaluation is fully pure: profile selection happens via distinct
# outputs (vm-N for the default profile, vm-N-<profile> for the rest).
{
  nixpkgs,
  home-manager,
  microvm,
}:
let
  inherit (nixpkgs) lib;

  knobs = lib.importJSON ./config.json;
  inherit (knobs)
    user
    uid
    slots
    vcpu
    mem
    storeOverlaySizeMB
    homeSizeMB
    macPrefix
    defaultProfile
    ;
  stateBase = "/Users/${user}/${knobs.stateDir}";

  guestSystem = "aarch64-linux";
  hostSystem = "aarch64-darwin";
  hostPkgs = nixpkgs.legacyPackages.${hostSystem};

  # Every directory under profiles/ with a home.nix is a valid guest home.
  profiles = lib.filter (
    name:
    (builtins.readDir ../profiles).${name} == "directory"
    && builtins.pathExists (../profiles + "/${name}/home.nix")
  ) (lib.attrNames (builtins.readDir ../profiles));

  mkName = n: "vm-${toString n}";
  slotNumbers = lib.range 1 slots;

  mkSlot =
    profile: n:
    lib.nixosSystem {
      system = guestSystem;
      modules = [
        microvm.nixosModules.microvm
        home-manager.nixosModules.home-manager
        ./modules/agent-vm.nix
        {
          agentvm = {
            inherit
              user
              uid
              stateBase
              vcpu
              mem
              storeOverlaySizeMB
              homeSizeMB
              macPrefix
              hostPkgs
              ;
            slot = n;
          };

          nixpkgs.config.allowUnfree = true; # claude-code, ngrok

          # One-to-one clone of the host profile's home environment.
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "backup";
            users.${user} =
              { lib, ... }:
              {
                imports = [ (../profiles + "/${profile}/home.nix") ];
                home.username = lib.mkForce user;
                home.homeDirectory = lib.mkForce "/home/${user}";
              };
          };
        }
      ];
    };

  configs = lib.listToAttrs (
    # vm-N: the default profile; vm-N-<profile>: explicit per-profile outputs.
    (map (n: lib.nameValuePair (mkName n) (mkSlot defaultProfile n)) slotNumbers)
    ++ lib.concatMap (
      profile: map (n: lib.nameValuePair "${mkName n}-${profile}" (mkSlot profile n)) slotNumbers
    ) profiles
  );
in
{
  nixosConfigurations = configs;

  # `nix build .#vm-1` (from aarch64-darwin) -> runner script wrapping vfkit
  packages = lib.mapAttrs (_: c: c.config.microvm.declaredRunner) configs;
}
