# Home Configuration

Parker's macOS configuration using nix-darwin + home-manager + nix-homebrew for declarative system and dotfile management.

## Quick Setup

### Prerequisites

1. Install Nix with flakes enabled:
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
   ```

2. Clone this repository:
   ```bash
   git clone <repo-url> ~/home-config
   cd ~/home-config
   ```

### Setup for Existing Profile

If your hostname matches an existing profile (`phendo`, `zephyr`):

1. **Build and activate the system configuration:**
   ```bash
   nix run nix-darwin -- switch --flake .#$(hostname -s)
   ```

2. **Apply home-manager configuration:**
   ```bash
   home-manager switch --flake .#parkerhenderson@$(hostname -s)
   ```

3. **Optional: Run legacy setup script for additional dotfiles:**
   ```bash
   ./setup.sh
   ```

### Setup for New Profile

If your hostname doesn't match existing profiles:

1. **Create a new profile:**
   ```bash
   mkdir -p profiles/$(hostname -s)
   ```

2. **Copy template files from an existing profile:**
   ```bash
   cp profiles/zephyr/default.nix profiles/$(hostname -s)/
   cp profiles/zephyr/home.nix profiles/$(hostname -s)/
   ```

3. **Edit the new profile files:**
   - `profiles/$(hostname -s)/default.nix` - Add system-level packages and homebrew casks
   - `profiles/$(hostname -s)/home.nix` - Add user packages and dotfile configurations

4. **Build and activate directly:**
   ```bash
   nix run nix-darwin -- switch --flake .#$(hostname -s)
   home-manager switch --flake .#parkerhenderson@$(hostname -s)
   ```

## Configuration Structure

- `flake.nix` - Main flake configuration defining system builds
- `config.common.nix` - Shared system-level configuration (homebrew, system settings)
- `home.common.nix` - Shared home-manager configuration (shell, common packages)
- `profiles/` - Per-machine configuration profiles
  - `profiles/*/default.nix` - Machine-specific system configuration
  - `profiles/*/home.nix` - Machine-specific home-manager configuration
- `dotfiles/` - Dotfiles managed by home-manager
- `scripts/` - Utility scripts

## Available Profiles

- **phendo** - Primary development machine with full toolset
- **zephyr** - Minimal template profile for new setups

## Managing Your Configuration

### Adding Packages

**System packages (available to all users):**
Add to `homebrew.casks` in `profiles/*/default.nix`

**User packages:**
Add to `home.packages` in `profiles/*/home.nix`

### Adding Dotfiles

Add symlinks in the `home.file` or `xdg.configFile` sections of `profiles/*/home.nix`

### Updating

```bash
nix flake update
nix run nix-darwin -- switch --flake .#$(hostname -s)
home-manager switch --flake .#parkerhenderson@$(hostname -s)
```

## Troubleshooting

- **Build fails:** Check `nix flake check` for configuration errors
- **Homebrew issues:** Run `brew doctor` and ensure homebrew is properly installed
- **Home-manager conflicts:** Use `home-manager switch --flake .#profile --backup-extension backup` to backup conflicting files