# /etc/fstab boot-resilience best practices

How to write `/etc/fstab` so that a missing, reordered, or failing **non-root**
disk can never drop the machine to emergency mode at boot. Distilled from
hardening TheBeast after an unseated secondary disk (lacking `nofail`) sent it
to emergency mode with no SSH and no display.

## Core rules

1. **Always use `UUID=`**, never `/dev/sdX`. Device names (`sda`, `nvme1n1`)
   are assigned in detection order and change when disks are added, removed, or
   reseated. UUIDs are stable. Get them from `lsblk -f` or `sudo blkid`.

2. **Only `/` is fail-hard.** The root filesystem is the one mount the system
   genuinely cannot run without, so it keeps `pass 1` and **never** gets
   `nofail`. Everything else is non-essential to reaching a login prompt.

3. **Every non-root mount gets `nofail,x-systemd.device-timeout=5s`.**
   - `nofail` — boot continues even if the device is absent or the mount fails.
   - `x-systemd.device-timeout=5s` — systemd waits at most 5s for the device
     instead of the default 90s before giving up. (Always write the `s` unit.)
   - This applies to `/boot/efi` too: the ESP is only needed for kernel and
     bootloader updates, not at runtime, so a flaky ESP should not block boot.

4. **Optional `/mnt/*` disks: add `x-systemd.automount`.** With automount the
   filesystem is not mounted at boot at all — it mounts lazily on first access
   to its mountpoint. Combined with `nofail` this means an optional disk can
   never participate in (or block) the boot critical path.
   - Direct mounts that must be ready early (e.g. `/home`, needed at login)
     stay direct — just `nofail` + the timeout, no automount.

5. **fsck pass field:**
   - `/` → `1`
   - other ext4 → `2`
   - vfat (ESP) and NTFS → `0` (never fsck these at boot)

6. **NTFS: prefer the in-kernel `ntfs3` driver** over the FUSE `ntfs-3g`.
   - Check support: `modinfo ntfs3`. On kernel >= 5.15 (Ubuntu 22.04+) it is
     built in. `ntfs-3g` may not even be installed.
   - Set sane ownership so the desktop user owns the files:
     `uid=1000,gid=1000,umask=022` (match `id <user>`).
   - Caveat: if Windows fast-startup / hibernation left the volume "dirty",
     `ntfs3` mounts it **read-only**. That is expected, not a failure — disable
     fast startup in Windows for reliable read-write.

7. **Comment every entry**: which physical disk, mount point, and purpose. When
   a disk fails at 3am the comment is what tells you which one to pull.

## Handling a suspect / disconnected disk

- **Never enable a disk you cannot currently see in `lsblk`.** If an fstab
  `UUID=` has no matching present device, leave it commented — do not guess.
- Keep a disk under investigation commented (or `noauto`) until it has been
  SMART-checked (`sudo smartctl -a /dev/sdX`) and fsck'd clean. Leave the line
  in best-practice form so it is a one-line uncomment once the disk is healthy.

## Safe edit procedure (no reboot, reversible)

```bash
# 1. Back up first, timestamped.
sudo cp -a /etc/fstab /etc/fstab.$(date +%Y%m%d-%H%M%S).bak

# 2. Never edit blind: reconcile every entry against live devices.
lsblk -f
sudo blkid
findmnt --real

# 3. Edit, then validate WITHOUT rebooting:
sudo systemctl daemon-reload   # re-read fstab into systemd mount units
sudo findmnt --verify          # static sanity check of /etc/fstab
sudo mount -a                  # mount everything (sets up automount points)

# If anything errors, restore immediately:
#   sudo cp -a /etc/fstab.<stamp>.bak /etc/fstab && sudo systemctl daemon-reload
```

Notes:
- `mount -a` does **not** remount already-mounted filesystems, so changed
  options on `/`, `/home`, `/boot/efi` only take effect on the next reboot.
  `findmnt --verify` is what catches syntax/option errors before that reboot.
- Test an `x-systemd.automount` entry live by accessing its mountpoint, e.g.
  `ls /mnt/BigByte`.

## Reference entry shapes

```
# Root - essential, fail-hard (NO nofail)
UUID=<root-uuid>   /          ext4   errors=remount-ro                                              0 1

# EFI - non-root, must not block boot
UUID=<efi-uuid>    /boot/efi  vfat   umask=0077,nofail,x-systemd.device-timeout=5s                  0 0

# /home - direct mount, available at login, but never blocks boot
UUID=<home-uuid>   /home      ext4   defaults,errors=remount-ro,nofail,x-systemd.device-timeout=5s  0 2

# Optional data disk - automount on first access, never touches boot
UUID=<ntfs-uuid>   /mnt/Data  ntfs3  nofail,x-systemd.automount,x-systemd.device-timeout=5s,uid=1000,gid=1000,umask=022  0 0
UUID=<ext4-uuid>   /mnt/Back  ext4   nofail,x-systemd.automount,x-systemd.device-timeout=5s          0 2
```
