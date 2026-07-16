# Personal instantiation of the generic pool (./pool.nix) for this repo.
# This is the only layer that knows about this repo's layout and choices:
# knobs come from ./config.json (shared with bin/agentvm) and every
# profiles/<name>/home.nix becomes a guest home. The generic core stays
# publishable; site-specific wiring stays here.
{
  nixpkgs,
  home-manager,
  microvm,
}:
let
  inherit (nixpkgs) lib;

  settings = lib.importJSON ./config.json;

  # Every directory under profiles/ with a home.nix is a valid guest home.
  profileNames = lib.filter (
    name:
    (builtins.readDir ../profiles).${name} == "directory"
    && builtins.pathExists (../profiles + "/${name}/home.nix")
  ) (lib.attrNames (builtins.readDir ../profiles));

  profiles = lib.genAttrs profileNames (name: ../profiles + "/${name}/home.nix");

  mkPool = import ./pool.nix { inherit nixpkgs home-manager microvm; };
in
mkPool {
  inherit settings profiles;
  allowUnfree = true; # claude-code, ngrok in home.common.nix
}
