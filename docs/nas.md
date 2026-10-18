# NAS shares

Two NFS shares from the NAS appear under `~/nas`, mounted on demand. Configured
in `nas.nix`.

| Path | Share on the NAS |
|---|---|
| `~/nas/media` | `/volume1/media` |
| `~/nas/backup` | `/volume2/backup` |

They're mounted on demand by autofs (`nas.nix`): nothing is mounted until you `cd` into
one, and it unmounts again after 10 idle minutes. **Away from the home network nothing
breaks** — there's no mount to fail at boot and no unit left in a failed state. `ls ~/nas`
still lists both directories; only reaching inside one fails, after about 6 seconds
(`soft,timeo=30,retrans=2`), with an I/O error instead of a hung process.

The NAS address is the secret `nas_host`, so it's not in this public repo. autofs is used
instead of `fileSystems`/`x-systemd.automount` precisely because it reads its map at
runtime: a `fileSystems.<path>.device` would put the address in `/etc/fstab` and the
world-readable Nix store. The share paths and mount options are not secret and stay in
`nas.nix`.

Day-to-day:

```sh
ls ~/nas/media              # triggers the mount
findmnt -t nfs              # what's mounted right now
systemctl status autofs     # and journalctl -u autofs if a mount fails
```

- **Changing a share or an option:** edit `shares` / `nfsOptions` in `nas.nix`.
- **Changing the NAS address:** `sops secrets/secrets.yaml`. sops-nix re-renders the map
  and reloads autofs; a share already mounted from the old address stays until it goes
  idle (or `sudo umount ~/nas/<share>`).
- **Ownership:** the mounts use NFSv3, which passes numeric uid/gid through unchanged, so
  files owned by uid 1000 on the NAS show up as yours. The NAS also offers NFSv4, but
  without a shared idmapd domain v4 would report everything as `nobody:nobody`.

`~/nas` itself is created by autofs and holds no data of its own, so it needs no backup.
