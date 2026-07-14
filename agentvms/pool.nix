# Ephemeral agent-sandbox microVM pool (microvm.nix + vfkit + vmnet-helper).
#
# Instantiated by the root flake so guests consume the same home-manager
# profile as the mac host: each VM imports profiles/<name>/home.nix (which
# pulls in home.common.nix), so packages, dotfiles, prompt, and coding
# agents match the host one-to-one instead of being mirrored by hand.
{
  nixpkgs,
  home-manager,
  microvm,
}:
let
  inherit (nixpkgs) lib;

  # ---------------- knobs ----------------
  user = "parker";
  uid = 501; # `id -u` on the mac; must match for virtiofs ownership
  slots = 4; # size of the VM pool (vm-1 .. vm-N); slot <= 9 enforced by agentvm.slot
  vcpu = 6;
  mem = 16384; # MB
  storeOverlaySizeMB = 32768; # per-slot writable /nix/store overlay (warm build cache)
  homeSizeMB = 65536; # per-slot persistent /home (agent logins survive restarts)
  stateBase = "/Users/${user}/.local/state/agentvms";
  defaultProfile = "zephyr";
  # ----------------------------------------

  # `agentvm start` builds with --impure; AGENTVM_PROFILE selects which host
  # profile the guest home clones. Pure evals fall back to the default.
  profile =
    let
      p = builtins.getEnv "AGENTVM_PROFILE";
    in
    if p == "" then defaultProfile else p;

  guestSystem = "aarch64-linux";
  hostSystem = "aarch64-darwin";
  hostPkgs = nixpkgs.legacyPackages.${hostSystem};

  # agentvms/authorized_keys is gitignored (per-machine), so a git flake
  # never sees it; `agentvm start` exports its content for the --impure
  # build. ./authorized_keys is a fallback for path:-style flake refs.
  authorizedKeys =
    let
      env = builtins.getEnv "AGENTVM_AUTHORIZED_KEYS";
      raw =
        if env != "" then
          env
        else if builtins.pathExists ./authorized_keys then
          lib.fileContents ./authorized_keys
        else
          "";
    in
    lib.filter (k: k != "") (lib.splitString "\n" raw);

  mkName = n: "vm-${toString n}";
  slotNumbers = lib.range 1 slots;
  slotNames = map mkName slotNumbers;

  mkSlot =
    n:
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
              authorizedKeys
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

  configs = lib.listToAttrs (map (n: lib.nameValuePair (mkName n) (mkSlot n)) slotNumbers);
in
{
  nixosConfigurations = configs;

  # `nix build .#vm-1` (from aarch64-darwin) -> runner script wrapping vfkit
  packages = lib.genAttrs slotNames (name: configs.${name}.config.microvm.declaredRunner);
}
