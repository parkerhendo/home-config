{ pkgs, ... }: 

{
  # User information
  home.username = "parkerhenderson";
  home.homeDirectory = "/Users/parkerhenderson";
  home.stateVersion = "22.11";

  # Minimal packages for testing
  home.packages = with pkgs; [
    git
    neovim
  ];

  # Essential programs
  programs.home-manager.enable = true;
}