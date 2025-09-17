{ config, pkgs, lib, ... }:

{
  # macOS system configuration
  system.defaults = {
    # Global system settings
    NSGlobalDomain = {
      ApplePressAndHoldEnabled = false;       # Disable accents menu
      NSDocumentSaveNewDocumentsToCloud = false; # Save to disk by default
    };

    # Dock settings
    dock = {
      tilesize = 48;              # Dock icon size
    };
  };

  # System services
  services = {
    # Window management
    yabai = {
      enable = true;
      enableScriptingAddition = true;
      config = {
        layout = "bsp";
        top_padding = 0;
        bottom_padding = 0;
        left_padding = 0;
        right_padding = 0;
        window_gap = 4;
        
        # Mouse settings
        mouse_follows_focus = "off";
        mouse_modifier = "ctrl";
        mouse_action1 = "move";
        mouse_action2 = "resize";
        mouse_drop_action = "stack";
      };
      extraConfig = ''
      '';
    };

    skhd = {
      enable = true;
    };
  };
}
