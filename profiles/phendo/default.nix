{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../default/darwin.nix
    ../../darwin/system.nix
    ../../darwin/homebrew.nix
  ];

  # Phendo-specific system configuration
  # Any phendo-specific darwin/system settings go here
}