# Determinate-Nix-friendly linux-builder wiring.
#
# nix-darwin's built-in `nix.linux-builder` requires `nix.enable = true`, which
# fights Determinate Nix's managed /etc/nix/nix.conf. This module reproduces
# the pieces we actually need — a launchd daemon that boots the builder VM
# plus the extra-trusted-users/builders lines — by patching Determinate's
# `/etc/nix/nix.custom.conf` hook and installing the builder's ssh key into
# the primary user's ~/.ssh directory.
{ config, pkgs, ... }:

let
  primaryUser = config.system.primaryUser;
  userSshDir = "/Users/${primaryUser}/.ssh";
  userKeyPath = "${userSshDir}/linux-builder_ed25519";

  # Bind the ed25519 public key once; the base64 form the `builders =` line
  # needs is derived from it at activation time, so the two can't drift.
  builderHostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJBWcxb/Blaqt1auOtE+F8QUWrUotiC5qBJ+UuEWdVCb";

  # Shared root-key installer used by both preActivation and the launchd
  # daemon so we don't drift two copies of the same chown/chmod/install
  # sequence.
  installBuilderKey = pkgs.writeShellScript "install-linux-builder-key" ''
    set -eu
    if [ ! -e /etc/nix/builder_ed25519 ]; then
      exit 0
    fi
    /usr/sbin/chown root:wheel /etc/nix/builder_ed25519
    /bin/chmod 0600 /etc/nix/builder_ed25519
    /bin/mkdir -p ${userSshDir}
    /usr/bin/install -m 0600 -o ${primaryUser} -g staff \
      /etc/nix/builder_ed25519 ${userKeyPath}
    rm -f /etc/nix/builder_ed25519_nixbld
  '';
in
{
  environment.etc."ssh/ssh_config.d/100-linux-builder.conf".text = ''
    Host linux-builder
      User builder
      Hostname 127.0.0.1
      HostKeyAlias linux-builder
      UserKnownHostsFile /etc/ssh/ssh_known_hosts.d/100-linux-builder
      Port 31022
      IdentityFile ${userKeyPath}
      IdentitiesOnly yes
  '';

  environment.etc."ssh/ssh_known_hosts.d/100-linux-builder".text = ''
    linux-builder ${builderHostKey}
  '';

  system.activationScripts.preActivation.text = ''
        mkdir -p /var/lib/linux-builder /etc/nix

        # Determinate Nix includes /etc/nix/nix.custom.conf from its managed
        # nix.conf. Patch that hook instead of using nix-darwin's `nix.*`
        # settings, which require `nix.enable = true`.
        custom=/etc/nix/nix.custom.conf
        tmp=$(/usr/bin/mktemp)
        if [ -e "$custom" ]; then
          /usr/bin/awk '
            /^# BEGIN nix-darwin linux-builder$/ { skip = 1; next }
            /^# END nix-darwin linux-builder$/ { skip = 0; next }
            !skip { print }
          ' "$custom" > "$tmp"
        else
          : > "$tmp"
        fi
        b64=$(printf '%s' '${builderHostKey} root@nixos' | /usr/bin/base64)
        cat >> "$tmp" <<EOF
    # BEGIN nix-darwin linux-builder
    extra-trusted-users = @admin ${primaryUser}
    builders = ssh-ng://builder@linux-builder aarch64-linux /etc/nix/builder_ed25519 1 - - - $b64
    builders-use-substitutes = true
    # END nix-darwin linux-builder
    EOF
        /usr/bin/install -m 0644 "$tmp" "$custom"
        rm -f "$tmp"

        ${installBuilderKey}
  '';

  launchd.daemons.linux-builder = {
    script = ''
      export NIX_SSL_CERT_FILE=/etc/nix/macos-keychain.crt
      export TMPDIR=/run/org.nixos.linux-builder USE_TMPDIR=1
      rm -rf "$TMPDIR"
      mkdir -p "$TMPDIR"
      trap 'rm -rf "$TMPDIR"' EXIT
      (
        while [ ! -e /etc/nix/builder_ed25519 ]; do
          sleep 1
        done
        ${installBuilderKey}
      ) &
      exec ${pkgs.darwin.linux-builder}/bin/create-builder
    '';
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
      WorkingDirectory = "/var/lib/linux-builder";
      StandardOutPath = "/var/log/linux-builder.log";
      StandardErrorPath = "/var/log/linux-builder.log";
    };
  };
}
