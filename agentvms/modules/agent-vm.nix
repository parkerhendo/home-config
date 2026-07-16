# One sandbox slot: system-level guest config only. The user's home
# environment (packages, dotfiles, prompt, agents) comes from home-manager
# importing a host profile -- see pool.nix, which also sets the `agentvm.*`
# options declared here.
#
# This module is generic: nothing in it is specific to one person's machine
# or repo. Site-specific values (user, uid, sizes, network scheme, credential
# forwarding, registry ports) arrive through the options below; pool.nix
# wires them from the shared config.json so the bash/nix boundary can't
# drift. It is written to be publishable as `nixosModules.agentvm`.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption mkEnableOption types;
  cfg = config.agentvm;

  name = "vm-${toString cfg.slot}";
  slotDir = "${cfg.stateBase}/${name}";

  # Native build baseline + common headers for source-building runtimes
  # (python via uv, ruby, node addons, ...); also exported via CPATH /
  # LIBRARY_PATH / PKG_CONFIG_PATH below so plain `make` finds them.
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

  # The host as seen from this slot: vmnet gives the host the subnet's
  # start address. Same subnetBase as bin/agentvm via config.json.
  hostAddr = "192.168.${toString (cfg.subnetBase + cfg.slot)}.1";

  repoMountPoint = "/home/${cfg.user}/${cfg.repoMount.dirName}";

  # Where sshd looks for keys: an explicit file wins, then the standard
  # location inside the repo copy, then only inline authorizedKeys.
  authorizedKeysFile =
    if cfg.authorizedKeysFile != null then
      cfg.authorizedKeysFile
    else if cfg.repoMount.enable then
      "${repoMountPoint}/agentvms/authorized_keys"
    else
      null;
in
{
  options.agentvm = {
    user = mkOption {
      type = types.str;
      description = "Guest login user; matches the host user for virtiofs ownership.";
    };
    uid = mkOption {
      type = types.ints.positive;
      description = "The host user's uid (`id -u`); must match for sane virtiofs ownership.";
    };
    slot = mkOption {
      type = types.ints.between 1 9; # single MAC digit (xx:xx:xx:xx:xx:0N)
      description = "Pool slot number; determines hostname, MAC, subnet, and state dir.";
    };
    stateBase = mkOption {
      type = types.str;
      description = "Absolute host directory holding per-slot state (disk images, copies).";
    };
    vcpu = mkOption {
      type = types.ints.positive;
      description = "Number of guest vCPUs.";
    };
    mem = mkOption {
      type = types.ints.positive;
      description = "Guest memory in MB.";
    };
    storeOverlaySizeMB = mkOption {
      type = types.ints.positive;
      description = "Size of the writable /nix/store overlay image in MB.";
    };
    homeSizeMB = mkOption {
      type = types.ints.positive;
      description = "Size of the persistent /home image in MB.";
    };
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
      description = "Host (darwin) package set; the microvm runner executes on the host.";
    };
    vfkitPath = mkOption {
      type = types.str;
      default = "/opt/homebrew/bin/vfkit";
      description = ''
        Host path to the vfkit binary. The Homebrew bottle is used instead of
        compiling nixpkgs' vfkit locally on macOS (current cctools can crash
        linking it). Shared with bin/agentvm via config.json's `vfkitPath`.
      '';
    };
    rosetta = mkOption {
      type = types.bool;
      default = true;
      description = "Run x86_64 binaries via Rosetta (Apple Silicon hosts).";
    };

    repoMount = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Mount a per-slot COPY of the config repo (synced by `agentvm start`,
          never the live checkout) at the same $HOME-relative path as on the
          host, so mkOutOfStoreSymlink dotfiles and sessionPath entries
          resolve inside the guest.
        '';
      };
      dirName = mkOption {
        type = types.str;
        default = "home-config";
        description = ''
          Basename of the repo mount under the guest $HOME. Must match
          config.json's `repoMountName` (bin/agentvm rsyncs the repo into
          <slot state dir>/<dirName>).
        '';
      };
    };

    authorizedKeysFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Guest path of the SSH authorized_keys file. Defaults to
        `agentvms/authorized_keys` inside the repo mount -- runtime data that
        never enters flake sources or the store. Set explicitly if the repo
        mount is disabled or laid out differently.
      '';
    };
    authorizedKeys = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Inline SSH public keys for the guest user (alternative to authorizedKeysFile).";
    };

    ssh = {
      acceptEnv = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "GH_TOKEN" ];
        description = ''
          Environment variables guest sshd accepts from the client. pool.nix
          adds GH_TOKEN when config.json sets `forwardGhToken`, matching the
          SendEnv in bin/agentvm.
        '';
      };
      hostAgentSocket = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Point git's ssh at the forwarded host ssh-agent socket that
          bin/agentvm links to ~/.ssh/agent.sock on connect. Enabled by
          pool.nix when config.json sets `forwardSshAgent`.
        '';
      };
      knownHosts = mkOption {
        type = types.attrsOf types.str;
        default = {
          # git-over-ssh via the forwarded agent shouldn't die on first-use
          # host key verification (the guest has no ~/.ssh).
          "github.com" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
        };
        description = "Pre-seeded SSH host keys for the guest.";
      };
    };

    docker = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Run dockerd in the guest (data-root on the persistent /home image).";
      };
      package = mkOption {
        type = types.package;
        default = pkgs.docker_29;
        defaultText = lib.literalExpression "pkgs.docker_29";
        description = "Docker package for the guest daemon.";
      };
      mirrorPort = mkOption {
        type = types.nullOr types.port;
        default = null;
        example = 5000;
        description = ''
          Port of a pull-through Docker Hub mirror on the host, reached at
          the slot's vmnet gateway. Null disables the mirror; guests then
          pull upstream directly. See README "Shared docker image cache".
        '';
      };
      pushPort = mkOption {
        type = types.nullOr types.port;
        default = null;
        example = 5001;
        description = "Port of a host-side push registry for locally built images. Null disables it.";
      };
    };

    baselinePackages = mkOption {
      type = types.listOf types.package;
      default = with pkgs; [
        bashInteractive
        awscli2
        curl
        gnupg
        gcc
        gnumake
        pkg-config
        python311
        unzip
        uv
        zip
        nodejs_22 # node/npm for bootstrap; project toolchains come from mise/nix develop
      ];
      defaultText = lib.literalMD "an opinionated dev-sandbox bootstrap set (compiler, python+uv, node, aws cli, archive tools)";
      description = ''
        Guest system bootstrap baseline. Override wholesale to change the
        tool's opinion; use extraPackages to only add. User-facing tools
        should come from the home-manager profile instead.
      '';
    };
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = ''
        Additional guest system packages on top of baselinePackages.
      '';
    };

    pathPrefix = mkOption {
      type = types.listOf types.str;
      default = [
        "/workspace/venv/bin"
        "$HOME/.local/share/mise/shims"
      ];
      description = ''
        Entries prepended to PATH in every shell, so commands installed by
        `make develop` / `mise install` are visible to plain `make` and
        non-interactive shells.
      '';
    };
  };

  config = {
    assertions = [
      {
        assertion = cfg.subnetBase + cfg.slot <= 254;
        message = "agentvm: subnetBase (${toString cfg.subnetBase}) + slot (${toString cfg.slot}) exceeds 254; 192.168.x networks would collide or overflow.";
      }
      {
        assertion = cfg.mem >= 1024;
        message = "agentvm: mem is ${toString cfg.mem} MB; guests need at least 1024 MB to boot reliably.";
      }
      {
        assertion = authorizedKeysFile != null || cfg.authorizedKeys != [ ];
        message = "agentvm: no SSH access configured -- enable repoMount, set authorizedKeysFile, or provide authorizedKeys.";
      }
      {
        assertion = cfg.storeOverlaySizeMB >= 1024;
        message = "agentvm: storeOverlaySizeMB below 1024 leaves no room for direnv/nix builds.";
      }
    ];

    networking.hostName = name;
    system.stateVersion = "25.11";

    microvm = {
      hypervisor = "vfkit";
      inherit (cfg) vcpu mem;

      # Runner executes on the host.
      vmHostPackages = cfg.hostPkgs;

      # No built-in NAT interface -- networking comes entirely from
      # vmnet-helper: `vmnet-run` hands vfkit a datagram socket on fd 4.
      interfaces = [ ];
      vfkit = {
        package = cfg.hostPkgs.writeShellScriptBin "vfkit" ''
          exec ${cfg.vfkitPath} "$@"
        '';
        extraArgs = [ "--device=virtio-net,fd=4,mac=${mac}" ];
        rosetta.enable = cfg.rosetta;
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
      ]
      ++ lib.optional cfg.repoMount.enable {
        # Per-slot COPY of the config repo (synced by `agentvm start`, never
        # the live checkout), mounted at the same $HOME-relative path as on
        # the host so mkOutOfStoreSymlink dotfiles and sessionPath entries
        # resolve there.
        proto = "virtiofs";
        tag = "repo-config";
        source = "${slotDir}/${cfg.repoMount.dirName}";
        mountPoint = repoMountPoint;
      };

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
      "d /home/.sshd 0700 root root -"
      "d /home/${cfg.user} 0750 ${cfg.user} users -"
      "d /home/${cfg.user}/.local 0755 ${cfg.user} users -"
      "d /home/${cfg.user}/.local/share 0755 ${cfg.user} users -"
    ]
    ++ lib.optional cfg.docker.enable "d /home/${cfg.user}/.local/share/docker 0710 root root -";

    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [ cfg.user ];
      sandbox = false;
      build-dir = "/nix/.rw-store/nix-build";
      # The store overlay is a fixed-size image; keep builds from wedging it.
      min-free = 1024 * 1024 * 1024; # start GC below 1 GiB free
      max-free = 3 * 1024 * 1024 * 1024; # stop once 3 GiB are free
    };
    # The overlay accumulates direnv/build cruft across restarts; prune it
    # before it fills the fixed-size image.
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };

    users.users.${cfg.user} = {
      isSystemUser = true; # isNormalUser forbids uid < 1000; we need the host's uid
      createHome = true;
      home = "/home/${cfg.user}";
      group = "users";
      shell = pkgs.zsh;
      inherit (cfg) uid;
      openssh.authorizedKeys.keys = cfg.authorizedKeys;
      extraGroups = [ "wheel" ] ++ lib.optional cfg.docker.enable "docker";
    };
    security.sudo.wheelNeedsPassword = false;
    services.getty.autologinUser = cfg.user; # serial console in the tmux pane

    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
        # Keys come from the gitignored agentvms/authorized_keys via the
        # rsynced repo copy -- runtime data, so it never has to enter flake
        # sources or the store. StrictModes would reject the virtiofs path's
        # ownership chain; the VM boundary is the perimeter here.
        StrictModes = false;
      }
      // lib.optionalAttrs (cfg.ssh.acceptEnv != [ ]) {
        # Host creds pass-through, matching bin/agentvm's SendEnv.
        AcceptEnv = cfg.ssh.acceptEnv;
      };
      authorizedKeysFiles = lib.optional (authorizedKeysFile != null) authorizedKeysFile;
      # Persist host keys in the /home image: the guest keeps one SSH
      # identity across boots, so the host-side known_hosts stays valid and
      # trust-on-first-use actually means something. `agentvm reset` wipes
      # both sides together.
      hostKeys = [
        {
          path = "/home/.sshd/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];
    };

    programs.ssh.knownHosts = lib.mapAttrs (_: key: { publicKey = key; }) cfg.ssh.knownHosts;

    environment.etc = lib.mkIf cfg.ssh.hostAgentSocket {
      # git-over-ssh through the forwarded host agent (bin/agentvm links the
      # per-connection socket to ~/.ssh/agent.sock).
      gitconfig.text = ''
        [core]
          sshCommand = ssh -o IdentityAgent=/home/${cfg.user}/.ssh/agent.sock
      '';
    };

    # mDNS: `ssh vm-N.local` / http://vm-N.local:3000 from the host over vmnet.
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

    # The laptop suspends with VMs running; the guest clock freezes and TLS
    # starts failing after resume. chrony with unrestricted makestep snaps it
    # back instead of slewing for hours.
    services.timesyncd.enable = false;
    services.chrony = {
      enable = true;
      extraConfig = ''
        makestep 1 -1
      '';
    };

    # Compressed swap keeps runaway agent builds from hard-OOMing the guest;
    # the root fs is tmpfs, so there is no disk to swap to.
    zramSwap.enable = true;

    # Return freed blocks in the store-overlay/home images to the host's
    # filesystem (the images are sparse; without trim they only ever grow).
    services.fstrim.enable = true;

    # Journald writes to the tmpfs root -- cap it so logs can't eat guest RAM.
    services.journald.extraConfig = ''
      SystemMaxUse=64M
      RuntimeMaxUse=64M
    '';

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    programs.nix-ld.enable = true;
    environment.enableAllTerminfo = true;

    # The guest reads the host's /nix/store over virtiofs, and that store sits
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

    system.activationScripts.cargoConfig = lib.stringAfter [ "users" ] ''
      install -d -m0755 -o ${cfg.user} -g users /home/${cfg.user}/.cargo
      cat > /home/${cfg.user}/.cargo/config.toml <<'EOF'
[net]
git-fetch-with-cli = true
EOF
      chown ${cfg.user}:users /home/${cfg.user}/.cargo/config.toml
      chmod 0644 /home/${cfg.user}/.cargo/config.toml
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
      AGENTVM_HOST_ADDR = hostAddr; # the host; e.g. image: $AGENTVM_HOST_ADDR:5001/app in compose
      MISE_NODE_COMPILE = "0"; # use prebuilt Node binaries; compiling Node in microVMs is too slow/OOM-prone
      CPATH = lib.makeSearchPathOutput "dev" "include" sourceBuildInputs;
      LIBRARY_PATH = lib.makeLibraryPath sourceBuildInputs;
      PKG_CONFIG_PATH = lib.makeSearchPathOutput "dev" "lib/pkgconfig" sourceBuildInputs;
      UV_PYTHON_PREFERENCE = "only-system";
      CARGO_NET_GIT_FETCH_WITH_CLI = "true";
    };
    environment.shellInit = ''
      export PATH="${lib.concatStringsSep ":" cfg.pathPrefix}:$PATH"
    '';

    virtualisation.docker = lib.mkIf cfg.docker.enable {
      enable = true;
      package = cfg.docker.package;
      # Image/container cruft accumulates in the fixed-size /home image.
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
      daemon.settings = {
        data-root = "/home/${cfg.user}/.local/share/docker";
        # Unbounded container logs otherwise fill the /home image.
        log-driver = "json-file";
        log-opts = {
          max-size = "10m";
          max-file = "3";
        };
      }
      // lib.optionalAttrs (cfg.docker.mirrorPort != null) {
        # Host-side pull-through Docker Hub mirror (see README "Shared docker
        # image cache"). Plain HTTP over the local vmnet link.
        registry-mirrors = [ "http://${hostAddr}:${toString cfg.docker.mirrorPort}" ];
      }
      // lib.optionalAttrs (cfg.docker.mirrorPort != null || cfg.docker.pushPort != null) {
        insecure-registries =
          lib.optional (cfg.docker.mirrorPort != null) "${hostAddr}:${toString cfg.docker.mirrorPort}"
          ++ lib.optional (cfg.docker.pushPort != null) "${hostAddr}:${toString cfg.docker.pushPort}";
      };
    };

    # Guest-only system baseline: bootstrap tools plus the native build
    # inputs. Everything user-facing (agents, editors, shell utilities)
    # comes from the home profile via home-manager; docker and zsh come from
    # their modules above.
    environment.systemPackages =
      cfg.baselinePackages
      ++ lib.optional cfg.docker.enable pkgs.docker-compose
      ++ sourceBuildInputs
      ++ cfg.extraPackages;

    # Heavy dep churn (node_modules) is slow over virtiofs. Optionally shadow
    # it with VM-local tmpfs -- host won't see it, which is usually a feature:
    # fileSystems."/workspace/node_modules" = {
    #   fsType = "tmpfs"; options = [ "size=6G" "mode=777" ];
    # };
  };
}
