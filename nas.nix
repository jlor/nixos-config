{ config, lib, ... }:

# On-demand NFS mounts from the NAS, under ~/nas.
#
# Nothing is mounted until you actually touch one of the directories, and it
# unmounts itself again once idle. Off the home network that means there is no
# mount to fail: no hang at boot, no unit sitting in a failed state, and
# `ls ~/nas` still lists the shares. Only reaching *into* one errors out, and
# it does so in a few seconds instead of blocking forever.
#
# This uses autofs rather than `fileSystems` with x-systemd.automount, because
# autofs reads its map file at runtime. That lets the NAS address come from a
# sops template (/run/secrets/rendered/..., in RAM) instead of being baked into
# /etc/fstab and the world-readable Nix store, which is what a
# `fileSystems.<path>.device` would do. See secrets.nix for the secret itself.
let
  username = "jlor";
  mountPoint = "/home/${username}/nas";

  # Directory under ~/nas  ->  export on the NAS (`showmount -e` lists them).
  shares = {
    media = "/volume1/media";
    backup = "/volume2/backup";
  };

  # soft: give up with an I/O error instead of hanging a process forever in
  #   uninterruptible sleep, which is what a `hard` mount does when the NAS
  #   isn't there. This is the option that keeps a missing NAS a non-event.
  # timeo=30 (deciseconds) + retrans=2: so "give up" means ~6 seconds, not ~3
  #   minutes of default retries.
  # nfsvers=3: the NAS exports v3 and v4, but v4 maps ownership through idmapd
  #   by username, and with no common domain between here and the NAS every file
  #   would come back owned by nobody:nobody. v3 passes the numeric uid/gid
  #   straight through, which matches jlor = uid 1000 on both ends.
  nfsOptions = lib.concatStringsSep "," [
    "fstype=nfs"
    "nfsvers=3"
    "soft"
    "timeo=30"
    "retrans=2"
    "rsize=1048576"
    "wsize=1048576"
    "noatime"
  ];

  # Degrade gracefully: until `sops secrets/secrets.yaml` has a nas_host, this
  # whole module is inert rather than an evaluation error (see CLAUDE.md).
  hasHost = config.sops.secrets ? nas_host;
in
{
  config = lib.mkIf hasHost {
    # Pulls in nfs-utils (mount.nfs, which autofs shells out to) and the local
    # NFSv3 lock daemons rpcbind/rpc-statd. All local; nothing here reaches for
    # the NAS at boot.
    boot.supportedFilesystems.nfs = true;

    # The autofs map, with the address filled in at boot. Only the hostname is
    # secret; the shares and mount options stay readable here.
    sops.templates."nas-shares" = {
      content = lib.concatLines (
        lib.mapAttrsToList (
          dir: export: "${dir} -${nfsOptions} ${config.sops.placeholder.nas_host}:${export}"
        ) shares
      );
      # Changing the address re-reads the map in place (SIGHUP) rather than
      # restarting autofs underneath a live mount.
      reloadUnits = [ "autofs.service" ];
    };

    services.autofs = {
      enable = true;
      timeout = 600; # unmount a share after 10 idle minutes
      # --ghost creates the share directories for real, so `ls ~/nas` works
      # (and shows something in Nautilus) without touching the network.
      autoMaster = ''
        ${mountPoint} file:${config.sops.templates."nas-shares".path} --ghost
      '';
    };
  };
}
