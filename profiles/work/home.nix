{ config, pkgs, lib, ... }:

{
  imports = [
    ../../home.common.nix
  ];

  # User information (profile-specific)
  home.username = "parker";
  home.homeDirectory = "/Users/parker";

  # Global npm packages via bun
  home.activation.installGlobalNpmPackages = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bun}/bin/bun install -g agent-browser 2>/dev/null || true
    ${pkgs.nodejs_22}/bin/npm install -g @tobilu/qmd 2>/dev/null || true
  '';

  # Phendo-specific packages
  home.packages = with pkgs; [
    # programming languages
    python312
    uv
    go
    rustup

    # dev utilities
    graphite-cli
    nodejs_22
    wasm-bindgen-cli_0_2_100
    duckdb
    wasm-pack
    mise
    bun
    k3d
    docker

    # utilities
    watchexec
  ];

  # File management - symlink essential dotfiles (paths are profile-specific)
  home.file = {
    # Shell profile
    ".zprofile".source = ../../dotfiles/zprofile;
    ".zsh".source = ../../dotfiles/zsh;
    ".zshrc".source = ../../dotfiles/zshrc;

    # Git configuration
    ".gitconfig".source = ../../dotfiles/git/gitconfig;
    ".gitalias.txt".source = ../../dotfiles/git/gitalias.txt;
    ".gitignore_global".source = ../../dotfiles/git/gitignore_global;

    # Terminal and shell
    ".tmux.conf".source = ../../dotfiles/tmux.conf;
    ".dircolors".source = ../../dotfiles/dircolors;
    ".ignore".source = ../../dotfiles/ignore;

    # Development tools
    ".vale.ini".source = ../../dotfiles/vale.ini;

    # Claude (mkOutOfStoreSymlink for editable files)
    ".claude/CLAUDE.md".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/home-config/dotfiles/claude/CLAUDE.md";
    ".claude/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/home-config/dotfiles/claude/settings.json";
    ".claude/statusline-command.sh".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/home-config/dotfiles/claude/statusline-command.sh";
    ".claude/commands".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/home-config/dotfiles/claude/commands";
    ".claude/skills".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/home-config/dotfiles/claude/skills";

    # Codex (mkOutOfStoreSymlink for editable files)
    ".codex/docs".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/home-config/dotfiles/codex/docs";
    ".codex/prompts".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/home-config/dotfiles/codex/prompts";
  };

  # XDG config files (paths are profile-specific)
  xdg.configFile = {
    "nvim".source = ../../dotfiles/nvim;
    "atuin".source = ../../dotfiles/atuin;
    "ghostty".source = ../../dotfiles/ghostty;
    "lumen".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/home-config/dotfiles/lumen";
    ".prompts".source = ../../prompts;
  };
}
