# agentvms — Szymon Kaliski's microVM pool, but on the Mac itself

Pool of N ephemeral NixOS VMs on macOS via microvm.nix + vfkit
(Virtualization.framework) + vmnet-helper. `cd project && agentvm start`
claims a free slot, mounts `$PWD` at `/workspace`, boots, and SSHes in.
Each VM gets its own IP, so the same project runs in parallel slots with no
port juggling — `http://vm-1.local:3000`, `http://vm-2.local:3000`.

## One-time setup

1. **Linux builder** (builds the aarch64-linux guests; most paths come from
   cache.nixos.org). This repo wires nix-darwin's Linux builder package into
   Determinate Nix via `/etc/nix/nix.custom.conf`; verify it before building:

   ```sh
   ssh linux-builder true
   nix store ping --store ssh-ng://linux-builder
   ```

2. **vmnet-helper**
   - macOS 26+: `brew tap nirs/vmnet-helper && brew install vmnet-helper`
     (no root needed). Optionally also vmnet-broker for faster native vmnet.
   - macOS 15 or earlier:
     `curl -fsSL https://github.com/nirs/vmnet-helper/releases/latest/download/install.sh | bash`
     Installs to `/opt/vmnet-helper` + a passwordless-sudo rule. Confirm the
     sudoers rule covers `vmnet-run` too, since the script invokes that.

3. **SSH key**: `agentvm start` initializes the ignored local
   `authorized_keys` from your default SSH public key. To do it manually:
   `cp ~/.ssh/id_ed25519.pub ./authorized_keys`

4. **Knobs**: edit the top of `flake.nix` (user, uid via `id -u`, slot count,
   vcpu/mem/disk sizes, stateBase).

5. **First build** (slow once, then cached). Use `path:` if this directory is
   untracked inside a parent Git repo:
   `AGENTVM_WORKSPACE=$PWD nix build --impure path:$PWD#vm-1`

6. Put `bin/agentvm` on PATH (home-manager `home.packages` wrapper or a
   symlink into `~/.local/bin`).

## Usage

```
cd ~/code/some-project
agentvm start          # copy $PWD into the slot, mount copy -> /workspace, ssh in
agentvm ls             # slot status + which project each is on
agentvm ssh 2          # reattach a shell
agentvm attach 2       # serial console (tmux pane) for boot debugging
agentvm stop 2 | all
agentvm reset 2        # wipe slot state: nix cache, /home, workspace copy, firmware vars
```

Env overrides: `AGENTVM_SLOTS`, `AGENTVM_USER`, `AGENTVM_STATE`,
`AGENTVM_FLAKE`, `AGENTVM_WORKSPACE_MODE=live` (dangerous live host mount),
`AGENTVM_ISOLATE=0` (allow VM↔VM traffic; default isolated).

## Bundled dev tools

The guest intentionally stays minimal. It includes bootstrap and navigation
tools (`git`, `curl`, `gnupg`, `jq`, `python`, `ripgrep`, `tmux`, archive utilities) plus
`mise`, `direnv`/`nix-direnv`, Nix flakes, and a small native build baseline
+ common headers for source-building runtimes (`gcc`, `make`, `pkg-config`,
`openssl`, `zlib`, `readline`, `sqlite`, `gdbm`, `libffi`, `libyaml`, `bzip2`,
`xz`, `ncurses`). The VM also includes Docker/Compose and AWS CLI v2 for
common local service workflows. It puts `/workspace/venv/bin` and mise shims on
PATH so commands installed by `make develop` / `mise install` are available to
plain `make` and shell commands. Project-specific runtimes and other toolchains
should come from the repo's `mise` config or `nix develop` shell.

## Design notes / deltas from the mini-PC version

- **No systemd host module on macOS** — each slot's runner runs inside a
  detached tmux session (`agentvm attach N` = console). Stop = graceful
  poweroff, then kill the session.
- **No Tailscale needed** — VMs are local; mDNS gives `vm-N.local` for ssh
  and browser. (If you want phone access later, run tailscale in the guests.)
- **Laptop, not always-on box** — closed lid suspends VMs. `caffeinate -s`
  while plugged in if you want agents chewing overnight.
- **Workspace copy is impure-eval**: `agentvm start` rsyncs `$PWD` into
  the per-slot state directory and exports that copy as `AGENTVM_WORKSPACE`
  before rebuilding the runner with `--impure` (cheap after first build — only
  the runner script changes). Destructive writes in `/workspace` affect the
  slot copy, not the original host checkout. Dependency/build artifacts such as
  `venv`, `.venv`, `node_modules`, `.direnv`, `bazel-*`, `dist`, `build`, and
  `target` are excluded so macOS-specific outputs are recreated inside Linux.
  Set `AGENTVM_WORKSPACE_MODE=live` to restore the old live-mount behavior.
- **Persistent per slot**: writable /nix/store overlay (warm direnv/build
  cache) + `/home` image (agent auth survives). Root fs is tmpfs — OS state
  is fresh every boot. `agentvm reset N` wipes the persistent bits.
- **Slot-to-slot isolation**: vmnet `--enable-isolation` is on by default,
  so one compromised agent can't poke another slot. Each slot also uses a
  distinct `/24` (`vm-1` = `192.168.65.0/24`, `vm-2` = `192.168.66.0/24`, ...),
  avoiding host routing collisions when multiple VMs run at once.

## Security reminders

By default, `/workspace` is a per-slot copy under `~/.local/state/agentvms`,
not the original host checkout. Destructive actions in the VM can still destroy
that copy, but should not modify your real repo unless you opt into
`AGENTVM_WORKSPACE_MODE=live`. Review or export changes from the slot copy
before applying them to the host checkout. No SSH keys or agent forwarding go
into the VMs — push from the host.

## Validated locally

- Linux builder SSH and `ssh-ng://linux-builder` builds.
- `nix build --impure path:$PWD#vm-1` from macOS into an aarch64-linux VM runner.
- `vmnet-run` fd 4 handoff to vfkit.
- mDNS SSH to `vm-1.local` / `vm-2.local`.
- Parallel slots on distinct subnets serving the same port (`:3000`).
