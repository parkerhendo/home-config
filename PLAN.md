# Migration Plan: DIY Dotfiles → nix-darwin + home-manager + nix-homebrew

## Current State Analysis

### Existing Setup
- **Home Manager**: Basic flake-based setup managing CLI packages for 4 machines (phendo, railway, zephyr, redwood)
- **Manual Symlinking**: `setup.sh` creates symlinks for dotfiles to `~/.config/` and `~/`
- **ZSH Plugins**: Manually cloned git repositories in `~/.zsh/plugins/`
- **macOS Settings**: Manual `defaults write` commands in `scripts/setup-osx`
- **GUI Applications**: Managed via Homebrew (referenced but not declaratively managed)
- **Window Management**: yabai + skhd + Hammerspoon configurations

### Current Home Manager Packages
Common across machines: atuin, bat, btop, coreutils, darwin.trash, fd, ffmpeg, fzf, gh, git, lazygit, neovim, neofetch, nixfmt, parallel, ripgrep, rustup, skhd, tmux, tree, yabai, yt-dlp

Machine-specific additions:
- **phendo**: docker, go, k3d, python312, uv, watchexec, wifi-password
- **railway**: bun, caddy, codex, nodejs_24, postgresql_16  
- **zephyr**: nodejs_24

## Target Architecture

### Three-Layer System
1. **nix-darwin**: System-level configuration, macOS defaults, Homebrew cask management
2. **home-manager**: User-specific configuration, CLI tools, dotfiles
3. **nix-homebrew**: Declarative Homebrew installation and tap management

### Repository Structure
```
/Users/parkerhenderson/home-config/
├── flake.nix                    # Main flake with all inputs
├── flake.lock                   # Locked input versions
├── darwin/
│   ├── configuration.nix       # Main nix-darwin config
│   ├── system.nix              # macOS system defaults
│   └── homebrew.nix            # GUI app management
├── home-manager/
│   ├── common.nix              # Shared home-manager config
│   ├── machines/
│   │   ├── phendo.nix          # Machine-specific config
│   │   ├── railway.nix
│   │   ├── zephyr.nix
│   │   └── redwood.nix
│   └── programs/               # Program-specific configs
│       ├── zsh.nix
│       ├── git.nix
│       ├── neovim.nix
│       └── ...
└── dotfiles/                   # Raw config files (as-needed)
```

## Migration Strategy

### Phase 1: Foundation Setup
1. **Create new flake.nix** with nix-darwin, home-manager, and nix-homebrew inputs
2. **Initialize nix-darwin configuration** with basic system settings
3. **Integrate nix-homebrew** for declarative Homebrew management
4. **Test system rebuild** on one machine (phendo recommended)

### Phase 2: System Configuration Migration
1. **Migrate macOS defaults** from `scripts/setup-osx` to nix-darwin `system.defaults`
2. **Add GUI applications** to Homebrew cask management
3. **Configure system services** (yabai, skhd as system services)
4. **Test window management setup**

### Phase 3: Home Manager Integration
1. **Restructure existing home-manager configs** to work with nix-darwin
2. **Migrate dotfile symlinking** to home-manager file management
3. **Convert ZSH plugin management** to home-manager programs.zsh
4. **Consolidate common packages** and machine-specific differences

### Phase 4: Advanced Configuration
1. **Migrate Neovim config** to home-manager programs.neovim
2. **Add tmux configuration** to home-manager
3. **Configure development environments** per machine
4. **Setup automated rebuild scripts**

### Phase 5: Testing and Rollout
1. **Full testing on phendo**
2. **Document any issues and solutions**
3. **Roll out to remaining machines**
4. **Archive old setup scripts**

## Implementation Details

### GUI Applications to Manage via nix-homebrew
**High Priority Casks:**
- ghostty
- cleanshot-x  
- spotify
- discord
- slack
- linear
- obsidian
- figma
- things3
- zoom
- loom
- amie
- mimestream
- texts
- dia

**System Tools:**
- hammerspoon
- cmake

### System Defaults Migration
Convert these `defaults write` commands to nix-darwin `system.defaults`:

```nix
system.defaults = {
  NSGlobalDomain = {
    NSRequiresAquaSystemAppearance = true;
    ApplePressAndHoldEnabled = false;
    NSUseAnimatedFocusRing = false;
    NSWindowResizeTime = 0.001;
    NSDocumentSaveNewDocumentsToCloud = false;
  };
  dock = {
    tilesize = 48;
    autohide-delay = 0.0;
    size-immutable = true;
  };
  finder = {
    DisableAllAnimations = true;
  };
  screencapture = {
    location = "~/Documents/Dropbox/Screenshots/";
    name = "Screenshot";
  };
  # ... additional settings
};
```

### Home Manager Program Configurations

**ZSH Configuration:**
- Migrate from manual plugin management to `programs.zsh.plugins`
- Convert aliases, functions, and exports to home-manager options
- Integrate base16-shell theme management

**Git Configuration:**
- Move from includes to direct configuration in home-manager
- Maintain gitconfig and gitignore_global content

**Neovim Configuration:**
- Consider using `programs.neovim` vs. direct file management
- Lazy.nvim may require file-based approach

## Migration Risks and Mitigation

### Risks
1. **System instability** during nix-darwin transition
2. **GUI application disruption** during Homebrew migration  
3. **ZSH plugin conflicts** during shell reconfiguration
4. **Development workflow interruption**

### Mitigation Strategies
1. **Backup current working setup** before starting
2. **Migrate one machine at a time** starting with least critical
3. **Test in VM or separate user account** if possible
4. **Keep old setup.sh functional** until migration complete
5. **Document rollback procedures** for each phase

## Success Criteria

### Technical Goals
- [ ] Single `darwin-rebuild switch` command rebuilds entire system
- [ ] All GUI applications managed declaratively via Homebrew casks
- [ ] All CLI tools managed via Nix/home-manager
- [ ] All dotfiles managed via home-manager
- [ ] All macOS system settings managed via nix-darwin
- [ ] Configuration works across all 4 machines

### Quality Goals  
- [ ] Faster setup time for new machines
- [ ] Reproducible development environment
- [ ] Version-controlled system configuration
- [ ] Reduced manual configuration steps
- [ ] Better documentation of system setup

## Timeline Estimate

**Phase 1 (Foundation)**: 1-2 days
**Phase 2 (System Config)**: 2-3 days  
**Phase 3 (Home Manager)**: 3-4 days
**Phase 4 (Advanced Config)**: 2-3 days
**Phase 5 (Testing/Rollout)**: 1-2 days

**Total Estimated Time**: 9-14 days

## Phendo Implementation Todo List

### High Priority
- [ ] Create backup of current working setup before starting migration
- [ ] Create new flake.nix with nix-darwin, home-manager, and nix-homebrew inputs
- [ ] Create darwin/ directory structure (configuration.nix, system.nix, homebrew.nix)
- [ ] Initialize basic nix-darwin configuration with system settings
- [ ] Integrate nix-homebrew for declarative Homebrew management
- [ ] Restructure phendo home-manager config to work with nix-darwin
- [ ] Test initial system rebuild on phendo machine
- [ ] Full testing and validation on phendo machine

### Medium Priority
- [ ] Migrate macOS defaults from scripts/setup-osx to nix-darwin system.defaults
- [ ] Add GUI applications to Homebrew cask management (ghostty, discord, slack, etc.)
- [ ] Configure system services (yabai, skhd as system services)

## Next Steps

1. **Review and approve this plan**
2. **Begin implementation with backup and foundation setup**
3. **Focus only on phendo machine for now**
4. **Document any deviations or issues encountered**
5. **Expand to other machines after phendo is stable**