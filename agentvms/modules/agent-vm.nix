# One sandbox slot: system-level guest config only. The user's home
# environment (packages, dotfiles, prompt, agents) comes from home-manager
# importing the host profile -- see pool.nix, which also sets the
# `agentvm.*` options declared here.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.agentvm;

  name = "vm-${toString cfg.slot}";
  slotDir = "${cfg.stateBase}/${name}";

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

  # Constant mount source: `agentvm start` populates it (rsync copy, or a
  # symlink to $PWD in live mode), so the build is pure and identical no
  # matter where it's invoked from.
  workspace = "${slotDir}/workspace";

  # Locally-administered, deterministic per slot. bin/agentvm derives the
  # dhcpd_leases lookup form from the same config.json macPrefix.
  mac = "${cfg.macPrefix}${toString cfg.slot}";

  # The mac host as seen from this slot: vmnet gives the host the subnet's
  # start address. Same subnetBase as bin/agentvm via config.json.
  hostAddr = "192.168.${toString (cfg.subnetBase + cfg.slot)}.1";
in
{
  options.agentvm = {
    user = mkOption {
      type = types.str;
      description = "Guest login user; matches the mac user for virtiofs ownership.";
    };
    uid = mkOption {
      type = types.int;
      description = "The mac user's uid (`id -u`); must match for sane virtiofs ownership.";
    };
    slot = mkOption {
      type = types.ints.between 1 9; # single MAC digit (02:76:6d:00:00:0N)
      description = "Pool slot number; determines hostname, MAC, and state dir.";
    };
    stateBase = mkOption {
      type = types.str;
      description = "Host directory holding per-slot state (disk images, copies).";
    };
    vcpu = mkOption { type = types.ints.positive; };
    mem = mkOption {
      type = types.ints.positive;
      description = "Guest memory in MB.";
    };
    storeOverlaySizeMB = mkOption { type = types.ints.positive; };
    homeSizeMB = mkOption { type = types.ints.positive; };
    subnetBase = mkOption {
      type = types.ints.positive;
      description = "Slot N's vmnet subnet is 192.168.(subnetBase+N).0/24; shared with bin/agentvm.";
    };
    macPrefix = mkOption {
      type = types.strMatching "([0-9a-f]{2}:){5}0";
      description = "First 5.5 octets of the guest MAC; the slot digit completes it.";
    };
    hostPkgs = mkOption {
      type = types.pkgs;
      description = "aarch64-darwin package set; the microvm runner executes on the mac.";
    };
  };

  config = {
    networking.hostName = name;
    system.stateVersion = "25.11";

    microvm = {
      hypervisor = "vfkit";
      inherit (cfg) vcpu mem;

      # Runner executes on the mac.
      vmHostPackages = cfg.hostPkgs;

      # No built-in NAT interface -- networking comes entirely from
      # vmnet-helper: `vmnet-run` hands vfkit a datagram socket on fd 4.
      interfaces = [ ];
      vfkit = {
        # Avoid locally compiling nixpkgs' vfkit on macOS; current cctools can
        # crash linking it. Use the Homebrew bottle installed during setup.
        package = cfg.hostPkgs.writeShellScriptBin "vfkit" ''
          exec /opt/homebrew/bin/vfkit "$@"
        '';
        extraArgs = [ "--device=virtio-net,fd=4,mac=${mac}" ];
        # x86_64 binaries via Rosetta (Apple Silicon).
        rosetta.enable = true;
      };

      shares = [
        {
          proto = "virtiofs";
          tag = "ro-store";
          source = "/nix/store";
          mountPoint = "/nix/.ro-store";
        }
        {
          proto = "virtiofs";
          tag = "workspace";
          source = workspace;
          mountPoint = "/workspace";
        }
        # Per-slot COPY of the host config repo (synced by `agentvm start`,
        # never the live checkout), mounted at the same $HOME-relative path as
        # on the mac so mkOutOfStoreSymlink dotfiles (~/.pi/agent, lumen, ...)
        # and sessionPath entries ($HOME/home-config/scripts) resolve there.
        {
          proto = "virtiofs";
          tag = "home-config";
          source = "${slotDir}/home-config";
          mountPoint = "/home/${cfg.user}/home-config";
        }
      ];

      # Writable /nix/store overlay on a per-slot disk image: direnv/nix
      # builds inside the VM work, and the cache survives restarts.
      writableStoreOverlay = "/nix/.rw-store";
      volumes = [
        {
          image = "store-overlay.img";
          mountPoint = "/nix/.rw-store";
          size = cfg.storeOverlaySizeMB;
        }
        {
          image = "home.img";
          mountPoint = "/home";
          size = cfg.homeSizeMB;
        }
      ];
    };

    # Root fs is tmpfs; keep nix builds off it or RAM fills up.
    # (~/.zshrc etc. are managed by home-manager, not tmpfiles.)
    systemd.tmpfiles.rules = [
      "d /nix/.rw-store/nix-build 0755 root root -"
      "d /home/${cfg.user} 0750 ${cfg.user} users -"
      "d /home/${cfg.user}/.local 0755 ${cfg.user} users -"
      "d /home/${cfg.user}/.local/share 0755 ${cfg.user} users -"
      "d /home/${cfg.user}/.local/share/docker 0710 root root -"
    ];

    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [ cfg.user ];
      sandbox = false;
      build-dir = "/nix/.rw-store/nix-build";
    };

    users.users.${cfg.user} = {
      isSystemUser = true; # isNormalUser forbids uid < 1000; we need the mac's uid
      createHome = true;
      home = "/home/${cfg.user}";
      group = "users";
      shell = pkgs.zsh;
      inherit (cfg) uid;
      extraGroups = [
        "wheel"
        "docker"
      ];
    };
    security.sudo.wheelNeedsPassword = false;
    services.getty.autologinUser = cfg.user; # serial console in the tmux pane

    services.openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
      # Keys come from the host's gitignored agentvms/authorized_keys via the
      # rsynced ~/home-config copy -- runtime data, so it never has to enter
      # flake sources or the store. StrictModes would reject the virtiofs
      # path's ownership chain; the VM boundary is the perimeter here.
      settings.StrictModes = false;
      authorizedKeysFiles = [ "/home/${cfg.user}/home-config/agentvms/authorized_keys" ];
    };

    # mDNS: `ssh vm-N.local` / http://vm-N.local:3000 from the mac over vmnet.
    services.avahi = {
      enable = true;
      publish = {
        enable = true;
        addresses = true;
      };
      nssmdns4 = true;
    };

    networking.useDHCP = lib.mkForce true; # vmnet's built-in DHCP
    # The VM boundary (+ vmnet --enable-isolation between slots) is the
    # perimeter; a guest firewall just gets in the way of dev servers.
    networking.firewall.enable = false;

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    programs.nix-ld.enable = true;
    environment.enableAllTerminfo = true;

    # The guest reads the mac's /nix/store over virtiofs, and that store sits
    # on case-insensitive APFS: nix's "case hack" renames case-colliding
    # entries (terminfo ships X/ vs x/, A/ vs a/, ...) to `x~nix~case~hack~1`
    # on unpack. NAR serialization strips the suffix back off, but a raw
    # virtiofs share exposes it, so every xterm-* terminfo lookup misses
    # ("'xterm-256color': unknown terminal type"). Rebuild a de-mangled db on
    # the guest's own case-sensitive tmpfs and search it first. Each source
    # package is de-hacked in a private staging dir (within one package the
    # colliding pair never clashes post-rename), then dir-merged with cp.
    systemd.services.terminfo-dehack = {
      description = "De-mangle nix case-hacked terminfo from the host store share";
      wantedBy = [ "multi-user.target" ];
      before = [
        "sshd.service"
        "getty.target"
      ];
      serviceConfig.Type = "oneshot";
      path = [ pkgs.findutils ];
      script = ''
        env=/run/current-system/sw/share/terminfo
        tmp=/run/terminfo.tmp
        rm -rf "$tmp"
        mkdir -p "$tmp"
        find "$env" -type l -print0 | xargs -0 -r readlink \
          | grep '^/nix/store/' | sed 's|\(/share/terminfo\)/.*|\1|' | sort -u \
          | while read -r src; do
            stage=$(mktemp -d)
            cp -rP --no-preserve=mode,ownership "$src/." "$stage/"
            find "$stage" -depth -name '*~nix~case~hack~*' | while read -r p; do
              mv "$p" "$(printf '%s' "$p" | sed 's/~nix~case~hack~[0-9]*$//')"
            done
            cp -rPf "$stage/." "$tmp/"
            rm -rf "$stage"
          done
        rm -rf /run/terminfo
        mv "$tmp" /run/terminfo
      '';
    };
    environment.extraInit = ''
      export TERMINFO_DIRS="/run/terminfo''${TERMINFO_DIRS:+:$TERMINFO_DIRS}"
    '';

    system.activationScripts.binbash = lib.stringAfter [ "binsh" ] ''
      ln -sfn /run/current-system/sw/bin/bash /bin/.bash.tmp
      mv /bin/.bash.tmp /bin/bash
    '';

    programs.bash.interactiveShellInit = ''
      if [[ -d /workspace && "$PWD" == "/home/${cfg.user}" ]]; then
        cd /workspace
      fi
    '';
    programs.zsh = {
      enable = true;
      interactiveShellInit = ''
        if [[ -d /workspace && "$PWD" == "/home/${cfg.user}" ]]; then
          cd /workspace
        fi
      '';
    };

    environment.shellAliases = {
      la = "ls -la";
      ll = "ls -alF";
    };

    environment.sessionVariables = {
      AGENTVM_NAME = name; # shell prompt prefix (dotfiles/zsh/prompt.zsh)
      AGENTVM_HOST_ADDR = hostAddr; # the mac; e.g. image: $AGENTVM_HOST_ADDR:5001/app in compose
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
        data-root = "/home/${cfg.user}/.local/share/docker";
        # Host-side registries (see README "Shared docker image cache"):
        # :5000 = pull-through Docker Hub mirror, :5001 = push registry for
        # locally built app images. Plain HTTP over the local vmnet link.
        registry-mirrors = [ "http://${hostAddr}:5000" ];
        insecure-registries = [
          "${hostAddr}:5000"
          "${hostAddr}:5001"
        ];
      };
    };

    # Guest-only system baseline. Everything user-facing (agents, editors,
    # shell utilities) comes from the host home profile via home-manager;
    # docker and zsh come from their modules above.
    environment.systemPackages =
      (with pkgs; [
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
        nodejs_22 # node/npm -- guest-only; host uses mise
      ])
      ++ sourceBuildInputs;

    # Heavy dep churn (node_modules) is slow over virtiofs. Optionally shadow
    # it with VM-local tmpfs -- host won't see it, which is usually a feature:
    # fileSystems."/workspace/node_modules" = {
    #   fsType = "tmpfs"; options = [ "size=6G" "mode=777" ];
    # };
  };
}
