{ pkgs, inputs, ... }: 

{
  imports = [
    ../default/home.nix
  ];

  # Phendo-specific packages
  home.packages = with pkgs; [
    # Development tools specific to phendo
    claude-code
    docker
    go
    k3d
    nodePackages_latest.vercel
    ocaml
    python312
    rustup
    uv
    watchexec
    
    # Media and utilities specific to phendo
    gemini-cli
  ];

  # Phendo-specific home configuration
  # Any phendo-specific home-manager settings go here
}