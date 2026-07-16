# agentvms — ephemeral NixOS microVM sandboxes on macOS

Pool of N ephemeral NixOS VMs on macOS via microvm.nix + vfkit
(Virtualization.framework) + vmnet-helper. `cd project && agentvm start`
claims a free slot, mounts a copy of `$PWD` at `/workspace`, boots, and
SSHes in. Each VM gets its own /24, so the same project runs in parallel
slots with no port juggling — `http://vm-1.local:3000`,
`http://vm-2.local:3000`.

The guest home environment is not a hand-mirrored package list — it *is*
the host profile: home-manager runs inside each guest and imports the same
`profiles/<name>/home.nix` the mac uses, so packages, dotfiles, prompt, and
coding agents match one-to-one.

## Layout: generic core vs. personal wiring

The tool is split so the core could be published and reused:

| piece | file | role |
|---|---|---|
| NixOS module | `modules/agent-vm.nix` | one guest slot; everything site-specific is an option |
| pool builder | `pool.nix` | generic `mkPool`: settings + profiles → `nixosConfigurations`/`packages` |
| CLI | `bin/agentvm` | host-side lifecycle; reads `config.json`, no hardcoded personal paths |
| shared knobs | `config.json` | THE contract between bash and nix (see `config.example.json`) |
| personal layer | `default.nix` | this repo's instantiation: parses `config.json`, scans `../profiles` |

The root flake exports the generic pieces as `nixosModules.agentvm` and
`lib.mkAgentVmPool`; see "Reusing this" below.

## One-time setup

1. **Linux builder** (builds the aarch64-linux guests; most paths come from
   cache.nixos.org). This repo wires nix-darwin's Linux builder package into
   Determinate Nix via `/etc/nix/nix.custom.conf`; verify it before building:

   ```sh
   ssh linux-builder true
   nix store ping --store ssh-ng://linux-builder
   ```

2. **vfkit + vmnet-helper**
   - Install vfkit from Homebrew: `brew install vfkit`. The runner wraps this
     bottle instead of compiling nixpkgs' vfkit locally on macOS (current
     cctools can crash linking it). A different location goes in
     `config.json`'s `vfkitPath`.
   - macOS 26+: `brew tap nirs/vmnet-helper && brew install vmnet-helper`
     (no root needed). Optionally also vmnet-broker for faster native vmnet.
   - macOS 15 or earlier:
     `curl -fsSL https://github.com/nirs/vmnet-helper/releases/latest/download/install.sh | bash`
     Installs to `/opt/vmnet-helper` + a passwordless-sudo rule. Confirm the
     sudoers rule covers `vmnet-run` too, since the script invokes that.

3. **SSH key**: `agentvm start` initializes the gitignored local
   `authorized_keys` from your default SSH public key. To do it manually:
   `cp ~/.ssh/id_ed25519.pub ./authorized_keys`

4. **Knobs**: edit `config.json` (see the schema below). It is the single
   source shared by `pool.nix` and `bin/agentvm`.

5. **Sanity check the host before the first (slow) build**:

   ```sh
   agentvm doctor
   ```

6. **First build** (slow once, then cached). The VM configs are outputs of
   the root home-config flake, so new files must be committed first:
   `agentvm build` (or `nix build ~/home-config#vm-1`).

7. `bin/agentvm` is on PATH via `home.sessionPath` in `home.common.nix`.

## Usage

```
cd ~/code/some-project
agentvm start                # copy $PWD into a free slot, boot, ssh in
agentvm start 3 --detach     # boot a specific slot without attaching (scripting)
agentvm start --profile work # override the auto-detected guest home profile
agentvm ls                   # slot status: state, uptime, address, profile, workspace
agentvm ssh 2                # reattach a shell
agentvm exec 2 -- make test  # one-off command in /workspace, exit code passes through
agentvm diff 2               # what pulling the slot copy would change on the host
agentvm pull 2 [--delete]    # sync the slot copy back over the host checkout
agentvm ip 2                 # slot address, for scripts and browsers
agentvm attach 2             # serial console (tmux pane) for boot debugging
agentvm log 2 [-f]           # console log (kept per slot for post-mortems)
agentvm stop 2 | all         # graceful poweroff (--force to kill)
agentvm reset 2 | all        # wipe slot state: nix cache, /home, copies, firmware vars
agentvm doctor               # check vfkit, vmnet, builder, keys, identity, subnets
```

Two concurrent `agentvm start` runs never claim the same slot: slot
ownership is the tmux session itself, created atomically before any work
happens.

Env overrides: `AGENTVM_CONFIG` (config path), `AGENTVM_FLAKE`,
`AGENTVM_PROFILE` (host profile the guest home clones — builds the
`vm-N-<profile>` flake output; default is read from nix-darwin's
`/etc/agentvm-profile`, then detected from hostname/computer name, then
`config.json`'s fallback), `AGENTVM_WORKSPACE_MODE=live` (dangerous live
host mount; confirms interactively unless `AGENTVM_LIVE_ACK=yes`),
`AGENTVM_ISOLATE=0` (allow VM↔VM traffic; default isolated),
`AGENTVM_BOOT_TIMEOUT` (seconds to wait for guest ssh, default 90).

## Configuration reference (`config.json`)

Copy `config.example.json` to `config.json` and adjust. Required keys are
validated by the CLI at startup, by `pool.nix` at eval time, and by CI:

| key | meaning |
|---|---|
| `user`, `uid` | guest login user; MUST match your mac user/uid for virtiofs ownership |
| `slots` | pool size, 1..9 (the slot digit completes the MAC address) |
| `vcpu`, `mem` | per-guest CPU count and memory (MB, min 1024) |
| `storeOverlaySizeMB` | writable /nix/store overlay image per slot (min 1024) |
| `homeSizeMB` | persistent /home image per slot |
| `stateDir` | per-slot state: relative to `$HOME`, or an absolute path |
| `subnetBase` | slot N lives on `192.168.(subnetBase+N).0/24` |
| `macPrefix` | first 5.5 octets of guest MACs (locally administered) |
| `defaultProfile` | guest home profile when auto-detection finds nothing |

Optional keys (safe defaults when absent): `vfkitPath`
(`/opt/homebrew/bin/vfkit`), `repoMountName` (`home-config`),
`forwardSshAgent` (false), `forwardGhToken` (false), `dockerMirrorPort` /
`dockerPushPort` (null = disabled).

## Getting work out of a slot

`/workspace` is a per-slot copy; nothing the guest does touches your real
checkout. Three ways to extract the results:

1. `agentvm diff N` then `agentvm pull N` — file-level sync back to the
   host checkout (deletions only with `--delete`; dependency dirs like
   `node_modules` are excluded both ways, and `.git/` never syncs back —
   guest-written hooks/config must not execute on the host).
2. Git-level, including commits made inside the slot:
   `git fetch ~/.local/state/agentvms/vm-N/workspace <branch>` — git
   transfers objects only, so this is the safe way to take guest commits.
3. Push from inside the guest (with `forwardSshAgent`/`forwardGhToken` on).

## Shared docker image cache

Each guest runs its own dockerd. With `dockerMirrorPort`/`dockerPushPort`
set, all slots use two registries on the mac (reached at the slot's vmnet
gateway, `192.168.<subnetBase+N>.1`, exported in the guest as
`$AGENTVM_HOST_ADDR`):

- **`:5000` — pull-through Docker Hub mirror.** The first slot to pull an
  image populates the host cache; the rest fetch layers over the local vmnet
  link. Docker-Hub-only (dockerd mirrors don't cover ghcr.io etc.).
- **`:5001` — push registry for your own images.** Build the app image once
  (host or any slot), push it, and every slot pulls at LAN speed.

One-time host setup (runs in OrbStack):

```sh
docker run -d --restart=always --name registry-mirror -p 5000:5000 \
  -e REGISTRY_PROXY_REMOTEURL=https://registry-1.docker.io \
  -v registry-mirror:/var/lib/registry registry:2
docker run -d --restart=always --name registry-local -p 5001:5000 \
  -v registry-local:/var/lib/registry registry:2
```

Typical flow — build once, run an instance per slot:

```sh
# host
docker build -t localhost:5001/myapp:dev . && docker push localhost:5001/myapp:dev
# compose file (env is interpolated per slot)
#   image: ${AGENTVM_HOST_ADDR}:5001/myapp:dev
```

If the registries aren't running, guests fall back to pulling upstream
directly — the mirror is best-effort. Extracted layers still live in each
slot's home image; only downloads/builds are deduplicated.

## One-to-one clone of the host

`pool.nix` runs home-manager inside each guest and imports the same
`profiles/<name>/home.nix` (auto-detected from nix-darwin's active profile
marker, fallback hostname/computer-name mapping, fallback
`config.json`'s `defaultProfile`, override with `AGENTVM_PROFILE`) that
`darwin-rebuild` uses on the mac, which pulls in `home.common.nix`: the
same packages (coding agents, `atuin`, `neovim`, `gh`, ...), the same zsh
setup/prompt, the same git/tmux/nvim dotfiles. Mac-only bits are guarded
with `lib.optionals pkgs.stdenv.isDarwin`; mac GUI configs (ghostty,
aerospace) simply dangle unused in the guest.

Dotfiles wired with `mkOutOfStoreSymlink` point at `$HOME/home-config/...`,
so `agentvm start` rsyncs the repo into the slot's state dir and mounts that
copy at `/home/<user>/home-config` — the same `$HOME`-relative path as on
the mac. Like `/workspace`, it's a copy, not the live checkout: dotfile
edits on the host show up on the slot's next `agentvm start`, and nothing
the guest does can touch a real host path.

On top of the profile, `modules/agent-vm.nix` adds a guest-only system
baseline: bootstrap tools (`curl`, `gnupg`, `python311`, `uv`, `zsh`,
`nodejs`, archive utilities), `direnv`/`nix-direnv`, Nix flakes, terminfo,
and a native build baseline + common headers for source-building runtimes
(`gcc`, `make`, `pkg-config`, `openssl`, `zlib`, `readline`, `sqlite`,
`gdbm`, `libffi`, `libyaml`, `bzip2`, `xz`, `ncurses`). The VM also includes
Docker/Compose and AWS CLI v2 for common local service workflows. It puts
`/workspace/venv/bin` and mise shims on PATH so commands installed by
`make develop` / `mise install` are available to plain `make` and shell
commands. Project-specific runtimes and other toolchains should still come
from the repo's `mise` config or `nix develop` shell.

## Guest lifecycle & self-maintenance

Baked into the module so slots keep working for weeks:

- **Clock**: chrony with unrestricted `makestep` — the laptop suspends with
  VMs running, and without stepping, TLS breaks after every resume.
- **Disk**: weekly guest `nix gc` plus `min-free`/`max-free`, docker
  auto-prune, capped container logs, and `fstrim` so the sparse images give
  space back to APFS. `agentvm reset N` remains the big hammer.
- **Memory**: zram swap absorbs runaway builds instead of hard-OOMing.
- **Logs**: journald is capped (tmpfs root); the host keeps each slot's
  serial console in `<state>/vm-N/console.log` (`agentvm log N`).
- **SSH identity**: guest host keys persist in the /home image, so
  known_hosts survives reboots and trust-on-first-use means something.
  `agentvm reset` wipes both sides together.

## Security model (honest version)

The threat model is untrusted agent code running inside a guest. Root in
the guest is assumed (passwordless sudo — the sandbox boundary is the VM,
not the user).

What the design gives you:

- **Host filesystem**: guests only see `/nix/store` read-only, plus per-slot
  *copies* of the workspace and config repo. No writable path into real
  host state. `AGENTVM_WORKSPACE_MODE=live` deliberately breaks this — the
  CLI warns loudly; use it only for code you'd run on the host anyway.
- **Slot-to-slot**: vmnet `--enable-isolation` is on by default
  (`AGENTVM_ISOLATE=0` opts out), and each slot has a distinct /24.
- **Host network**: guests CAN reach services listening on the host (the
  vmnet gateway, e.g. the docker registries) and anything the host routes.
  Treat host-bound services as guest-reachable.
- **Connection integrity**: the CLI only connects to addresses inside the
  slot's own subnet, validated against the DHCP lease file — a LAN device
  advertising `vm-N.local` over mDNS cannot receive your session (or your
  forwarded credentials). Guest SSH host keys persist per slot, so a
  changed identity is an error, not a silent re-trust.
- **Credentials**: `forwardSshAgent` and `forwardGhToken` are explicit
  opt-ins in `config.json`. While a session is attached, guest code can use
  the forwarded agent (it cannot read the keys themselves) and the GH_TOKEN
  it received. Scope what you forward: run a dedicated agent holding only a
  deploy key (`SSH_AUTH_SOCK=<scoped-agent> agentvm ssh N`), or add keys
  with `ssh-add -c` so every guest signature needs a host-side click; log
  `gh` into a fine-grained PAT rather than your primary identity. With both
  off, nothing credential-shaped enters the guest; push from the host.
- **Registry trust**: anything a guest pushes to the shared `:5001`
  registry will be pulled by other slots and possibly the host. Treat
  images there as guest-controlled; don't `docker run` them on the host
  with mounts you care about.
- **sshd `StrictModes=false`**: required because authorized_keys arrives
  over virtiofs with host ownership. A guest process could append keys to
  its own copy — that grants access to the same sandbox it already runs
  in, not to the host; the file is re-synced from the host every start.

## Reusing this outside this repo

The root flake exports the generic core:

- `nixosModules.agentvm` — the per-slot guest module; every site-specific
  value (user, sizes, network scheme, registry ports, repo mount,
  credential pass-through) is an option with a documented default.
- `lib.mkAgentVmPool` — `import agentvms/pool.nix`; call it with
  `{ nixpkgs, home-manager, microvm }` then
  `{ settings, profiles, extraModules ?, allowUnfree ?, guestSystem ?,
  hostSystem ? }` where `settings` is your parsed `config.json` and
  `profiles` an attrset of home-manager modules.
- `bin/agentvm` + `config.example.json` — the CLI reads everything from
  the config file; profile hostname auto-detection degrades gracefully in
  repos without a `profiles/` tree.

`agentvms/default.nix` in this repo is the reference instantiation (~25
lines).

## Troubleshooting

| symptom | likely cause | fix |
|---|---|---|
| `nix build` can't find `vm-N-<profile>` | profile not committed (git+file flakes only see committed files) | commit, or check `agentvm doctor` profile check |
| build fails immediately | linux-builder down | `ssh linux-builder true`; see `modules/linux-builder.nix` |
| `no ssh after 90s` | boot failure | `agentvm log N` / `agentvm attach N`; often a mount or firmware-var issue → `agentvm reset N` |
| ssh: host identification changed | slot's /home image was wiped outside `reset` | `rm <state>/vm-N/known_hosts` |
| `vm-N unreachable` while running | mDNS/lease lag after resume | wait a few seconds; `agentvm ip N` to see what resolves |
| TLS/cert errors in guest after laptop sleep | clock drift | fixed by chrony makestep; if persistent, `agentvm stop N && agentvm start` |
| guest "no space left" in /nix | store overlay full | guest `nix-collect-garbage -d`, or `agentvm reset N` |
| slot subnet collides with another VM product | e.g. Docker Desktop uses 192.168.65.0/24 | change `subnetBase`; `agentvm doctor` warns about routed slot subnets |
| all slots busy but `ls` shows stale state | VM died mid-boot | `agentvm stop N` clears the session, then start again |

## Design notes / deltas from the mini-PC version

- **No systemd host module on macOS** — each slot's runner runs inside a
  detached tmux session (`agentvm attach N` = console). Stop = graceful
  poweroff with a 30s window, then kill. The tmux session doubles as the
  slot lock, so claiming is atomic.
- **No Tailscale needed** — VMs are local; mDNS gives `vm-N.local` for the
  browser. (If you want phone access later, run tailscale in the guests.)
- **Laptop, not always-on box** — closed lid suspends VMs. `caffeinate -s`
  while plugged in if you want agents chewing overnight.
- **Workspace mount is constant, eval is pure**: the VM always mounts the
  per-slot `workspace/` state dir; `agentvm start` populates it — an rsync
  copy of `$PWD` by default, or a symlink to the live checkout with
  `AGENTVM_WORKSPACE_MODE=live`. No env vars or `--impure` feed the build,
  so the runner is identical wherever it's built.
- **SSH keys ride the repo copy**: the gitignored `agentvms/authorized_keys`
  reaches the guest via the rsynced repo mount, and guest sshd reads it from
  there — runtime data stays out of flake sources and the store.
- **Persistent per slot**: writable /nix/store overlay (warm direnv/build
  cache) + `/home` image (agent auth survives). Root fs is tmpfs — OS state
  is fresh every boot. `agentvm reset N` wipes the persistent bits.
- **Slot cap**: 9 slots max — the slot digit is the last MAC nibble. Fine
  for a laptop; lifting it means a two-digit MAC scheme and a lease-file
  migration.

## Validated locally

- Linux builder SSH and `ssh-ng://linux-builder` builds.
- `nix build <repo>#vm-1` from macOS into an aarch64-linux VM runner.
- `vmnet-run` fd 4 handoff to vfkit.
- mDNS SSH to `vm-1.local` / `vm-2.local`.
- Parallel slots on distinct subnets serving the same port (`:3000`).
