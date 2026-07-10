# One sandbox slot: system-level guest config only. The user's home
# environment (packages, dotfiles, prompt, agents) comes from home-manager
# importing the host profile -- see pool.nix. Parameterized via the
# `agentvm` specialArgs attrset defined there.
{ config, lib, pkgs, agentvm, ... }:
let
  inherit (agentvm) user uid slot stateBase vcpu mem
    storeOverlaySizeMB homeSizeMB authorizedKeys hostPkgs;
  name = "vm-${toString slot}";
  slotDir = "${stateBase}/${name}";

  sourceBuildInputs = with pkgs; [
    bzip2
    gdbm
    libffi
    libyaml
    ncurses
    openssl
    readline
    sqlite
    xz
    zlib
  ];

  # `agentvm start` exports AGENTVM_WORKSPACE=$PWD and builds with --impure,
  # so the current project dir becomes the /workspace virtiofs share.
  # Without the env var (plain `nix build`), falls back to a stable per-slot dir.
  workspace =
    let ws = builtins.getEnv "AGENTVM_WORKSPACE";
    in if ws == "" then "${slotDir}/workspace" else ws;

  # Locally-administered, deterministic per slot. Referenced by bin/agentvm
  # for the dhcpd_leases IP-discovery fallback -- keep in sync if changed.
  mac = "02:76:6d:00:00:0${toString slot}";
in
{
  networking.hostName = name;
  system.stateVersion = "25.11";

  microvm = {
    hypervisor = "vfkit";
    inherit vcpu mem;

    # Runner executes on the mac. VERIFY: option name against microvm.nix's
    # own vfkit-example if eval complains.
    vmHostPackages = hostPkgs;

    # No built-in NAT interface -- networking comes entirely from
    # vmnet-helper: `vmnet-run` hands vfkit a datagram socket on fd 4.
    interfaces = [ ];
    vfkit = {
      extraArgs = [ "--device=virtio-net,fd=4,mac=${mac}" ];
      # x86_64 binaries via Rosetta (Apple Silicon).
      # VERIFY exact option path (microvm.vfkit.rosetta.*) in options ref.
      rosetta.enable = true;
    };

    shares = [
      { proto = "virtiofs"; tag = "ro-store";
        source = "/nix/store"; mountPoint = "/nix/.ro-store"; }
      { proto = "virtiofs"; tag = "workspace";
        source = workspace; mountPoint = "/workspace"; }
      # Per-slot COPY of the host config repo (synced by `agentvm start`,
      # never the live checkout), mounted at the same $HOME-relative path as
      # on the mac so mkOutOfStoreSymlink dotfiles (~/.pi/agent, lumen, ...)
      # and sessionPath entries ($HOME/home-config/scripts) resolve there.
      { proto = "virtiofs"; tag = "home-config";
        source = "${slotDir}/home-config"; mountPoint = "/home/${user}/home-config"; }
    ];

    # Writable /nix/store overlay on a per-slot disk image: direnv/nix
    # builds inside the VM work, and the cache survives restarts.
    writableStoreOverlay = "/nix/.rw-store";
    volumes = [
      { image = "store-overlay.img"; mountPoint = "/nix/.rw-store";
        size = storeOverlaySizeMB; }
      { image = "home.img"; mountPoint = "/home"; size = homeSizeMB; }
    ];
  };

  # Root fs is tmpfs; keep nix builds off it or RAM fills up.
  # (~/.zshrc etc. are managed by home-manager, not tmpfiles.)
  systemd.tmpfiles.rules = [
    "d /nix/.rw-store/nix-build 0755 root root -"
    "d /home/${user} 0750 ${user} users -"
    "d /home/${user}/.local 0755 ${user} users -"
    "d /home/${user}/.local/share 0755 ${user} users -"
    "d /home/${user}/.local/share/docker 0710 root root -"
  ];
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ user ];
    sandbox = false;
    build-dir = "/nix/.rw-store/nix-build";
  };

  users.users.${user} = {
    isSystemUser = true;               # isNormalUser forbids uid < 1000; we need the mac's 501
    createHome = true;
    home = "/home/${user}";
    group = "users";
    shell = pkgs.zsh;
    inherit uid;                       # match mac uid -> sane virtiofs ownership
    extraGroups = [ "wheel" "docker" ];
    openssh.authorizedKeys.keys = authorizedKeys;
  };
  security.sudo.wheelNeedsPassword = false;
  services.getty.autologinUser = user;  # serial console in the tmux pane

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  # mDNS: `ssh vm-N.local` / http://vm-N.local:3000 from the mac over vmnet.
  services.avahi = {
    enable = true;
    publish = { enable = true; addresses = true; };
    nssmdns4 = true;
  };

  networking.useDHCP = lib.mkForce true;  # vmnet's built-in DHCP
  # The VM boundary (+ vmnet --enable-isolation between slots) is the
  # perimeter; a guest firewall just gets in the way of dev servers.
  networking.firewall.enable = false;

  programs.direnv = { enable = true; nix-direnv.enable = true; };
  programs.nix-ld.enable = true;
  environment.enableAllTerminfo = true;
  system.activationScripts.binbash = lib.stringAfter [ "binsh" ] ''
    ln -sfn /run/current-system/sw/bin/bash /bin/.bash.tmp
    mv /bin/.bash.tmp /bin/bash
  '';
  programs.bash.interactiveShellInit = ''
    if [[ -d /workspace && "$PWD" == "/home/${user}" ]]; then
      cd /workspace
    fi
  '';
  programs.zsh = {
    enable = true;
    interactiveShellInit = ''
      if [[ -d /workspace && "$PWD" == "/home/${user}" ]]; then
        cd /workspace
      fi
    '';
  };

  environment.shellAliases = {
    la = "ls -la";
    ll = "ls -alF";
  };

  environment.sessionVariables = {
    AGENTVM_NAME = name;               # shell prompt prefix (dotfiles/zsh/prompt.zsh)
    CPATH = lib.makeSearchPathOutput "dev" "include" sourceBuildInputs;
    LIBRARY_PATH = lib.makeLibraryPath sourceBuildInputs;
    PKG_CONFIG_PATH = lib.makeSearchPathOutput "dev" "lib/pkgconfig" sourceBuildInputs;
    UV_PYTHON_PREFERENCE = "only-system";
  };
  environment.shellInit = ''
    export PATH="/workspace/venv/bin:$HOME/.local/share/mise/shims:$PATH"
  '';

  virtualisation.docker = {
    enable = true;
    package = pkgs.docker_29;
    daemon.settings = {
      data-root = "/home/${user}/.local/share/docker";
    };
  };

  # Guest-only system baseline. Everything user-facing (agents, editors,
  # shell utilities) comes from the host home profile via home-manager;
  # docker binaries come from virtualisation.docker.
  environment.systemPackages = (with pkgs; [
    bashInteractive
    awscli2
    curl
    docker-compose
    gnupg
    gcc
    gnumake
    pkg-config
    python311
    unzip
    uv
    zip
    zsh
    nodejs_22   # node/npm -- guest-only; host uses mise
  ]) ++ sourceBuildInputs;

  # Heavy dep churn (node_modules) is slow over virtiofs. Optionally shadow
  # it with VM-local tmpfs -- host won't see it, which is usually a feature:
  # fileSystems."/workspace/node_modules" = {
  #   fsType = "tmpfs"; options = [ "size=6G" "mode=777" ];
  # };
}
