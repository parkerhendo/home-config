# Generic builder for an ephemeral agent-sandbox microVM pool
# (microvm.nix + vfkit + vmnet-helper).
#
# This file is site-agnostic and could be published as `lib.mkPool`: all
# site-specific values arrive via `settings` (the parsed config.json shared
# with bin/agentvm, so the bash/nix boundary can't drift) and `profiles`
# (home-manager modules the guest homes clone one-to-one). The thin personal
# instantiation lives in ./default.nix.
#
# Evaluation is fully pure: profile selection happens via distinct outputs
# (vm-N for the default profile, vm-N-<profile> for the rest).
{
  nixpkgs,
  home-manager,
  microvm,
}:
{
  # Parsed config.json (see config.example.json for the schema). Required:
  # user, uid, slots, vcpu, mem, storeOverlaySizeMB, homeSizeMB, stateDir,
  # subnetBase, macPrefix, defaultProfile. Optional: vfkitPath,
  # repoMountName, forwardSshAgent, forwardGhToken, dockerMirrorPort,
  # dockerPushPort.
  settings,
  # Attrset of guest home profiles: name -> home-manager module. The guest
  # imports the module as the user's home, so packages, dotfiles, prompt,
  # and coding agents match the host one-to-one instead of being mirrored by
  # hand.
  profiles,
  # Extra NixOS modules merged into every guest (site-specific additions).
  extraModules ? [ ],
  allowUnfree ? false,
  guestSystem ? "aarch64-linux",
  hostSystem ? "aarch64-darwin",
}:
let
  inherit (nixpkgs) lib;

  # --- settings validation: fail at eval time with a message that names the
  # key, instead of a type error three modules deeper.
  requiredKeys = {
    user = "string";
    uid = "int";
    slots = "int";
    vcpu = "int";
    mem = "int";
    storeOverlaySizeMB = "int";
    homeSizeMB = "int";
    stateDir = "string";
    subnetBase = "int";
    macPrefix = "string";
    defaultProfile = "string";
  };
  checkKey =
    name: type:
    if !(settings ? ${name}) then
      throw "agentvm settings: missing key '${name}' (see agentvms/config.example.json)"
    else if type == "int" && !builtins.isInt settings.${name} then
      throw "agentvm settings: '${name}' must be an integer"
    else if type == "string" && !builtins.isString settings.${name} then
      throw "agentvm settings: '${name}' must be a string"
    else
      true;
  settingsValid = lib.all lib.id (lib.mapAttrsToList checkKey requiredKeys);

  inherit (settings)
    user
    uid
    slots
    vcpu
    mem
    storeOverlaySizeMB
    homeSizeMB
    subnetBase
    macPrefix
    defaultProfile
    ;

  # stateDir may be absolute; otherwise it is relative to the user's home.
  # Mirrors the same rule in bin/agentvm.
  stateBase =
    if lib.hasPrefix "/" settings.stateDir then
      settings.stateDir
    else
      "/Users/${user}/${settings.stateDir}";

  hostPkgs = nixpkgs.legacyPackages.${hostSystem};

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
              subnetBase
              macPrefix
              hostPkgs
              ;
            slot = n;
            vfkitPath = settings.vfkitPath or "/opt/homebrew/bin/vfkit";
            repoMount.dirName = settings.repoMountName or "home-config";
            # Credential forwarding is set in config.json so the guest side
            # (AcceptEnv, agent-socket gitconfig) can never disagree with
            # what bin/agentvm actually sends.
            ssh.acceptEnv = lib.optional (settings.forwardGhToken or false) "GH_TOKEN";
            ssh.hostAgentSocket = settings.forwardSshAgent or false;
            docker.mirrorPort = settings.dockerMirrorPort or null;
            docker.pushPort = settings.dockerPushPort or null;
          };

          nixpkgs.config.allowUnfree = allowUnfree;

          # One-to-one clone of the host profile's home environment.
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "backup";
            users.${user} =
              { lib, ... }:
              {
                imports = [ profiles.${profile} ];
                home.username = lib.mkForce user;
                home.homeDirectory = lib.mkForce "/home/${user}";
              };
          };
        }
      ]
      ++ extraModules;
    };

  configs = lib.listToAttrs (
    # vm-N: the default profile; vm-N-<profile>: explicit per-profile outputs.
    (map (n: lib.nameValuePair (mkName n) (mkSlot defaultProfile n)) slotNumbers)
    ++ lib.concatMap (
      profile: map (n: lib.nameValuePair "${mkName n}-${profile}" (mkSlot profile n)) slotNumbers
    ) (lib.attrNames profiles)
  );
in
assert settingsValid;
assert lib.assertMsg (slots >= 1 && slots <= 9)
  "agentvm settings: slots must be 1..9 (single MAC digit scheme), got ${toString slots}";
assert lib.assertMsg (subnetBase >= 1 && subnetBase + slots <= 254)
  "agentvm settings: subnetBase (${toString subnetBase}) + slots (${toString slots}) must stay within 192.168.1-254";
assert lib.assertMsg (profiles ? ${defaultProfile})
  "agentvm settings: defaultProfile '${defaultProfile}' has no matching profile (known: ${lib.concatStringsSep ", " (lib.attrNames profiles)})";
{
  nixosConfigurations = configs;

  # `nix build .#vm-1` (from the host) -> runner script wrapping vfkit
  packages = lib.mapAttrs (_: c: c.config.microvm.declaredRunner) configs;
}
