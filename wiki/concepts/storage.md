---
type: concept
title: Storage — Media Tiers, NFS Pool & Google Drive
tags: [storage, nfs, media, plex, qbittorrent, rclone, google-drive, zfs]
related: [vm101-ubuntu, tower, mullvad, network-topology]
---

Media storage tiers, the tower NFS pool that Plex reads from, the download→scan→move pipeline, and rclone Google Drive mounts. Media **services** (Plex/Jellyfin/qBittorrent) run on [[vm101-ubuntu]] and are detailed there; this page owns where the bytes physically live and how they move.

> **Design preference:** ONE disk / ONE mount per VM. The user dislikes split disks (fewer places to track, less to remember). VM 101 was deliberately consolidated to a single root disk in 2026-05 (see the `sdb` teardown below) — don't propose splitting a VM's storage without a named reason.

## VM 101 storage tiers (mapped 2026-05-26)

| Mount | Type / size | Backing | Holds |
|-------|-------------|---------|-------|
| `/` | local LVM ext4, ~300G root (`scsi0`/sda) | tower SSD zvol (`local-zfs-tower` = `rpool-tower`, Samsung 850 PRO 512GB) | OS, `/home/jaded/downloads` (virus sandbox), `/home/jaded/media` (legacy, EMPTY) |
| `/mnt/media-pool` | **NFS from tower `192.168.68.249`, 3.2T** (`nconnect=8`) | tower 4TB Seagate HDD pool (`media-pool`) | The real media store (Movies/Serials/Music) + Frigate recordings |
| `/mnt/ollama` | NFS from tower, 2T | tower HDD pool (`media-pool-vm`) | ollama models (~58G) |

**The 3.2T `/mnt/media-pool` NFS pool is the only store Plex reads.** Frigate recordings live on the same pool — that pool is the reason the 3.2T HDD was bought.

**`sdb` destroyed 2026-05-26** — VM 101 used to carry a second local disk (`scsi1`, 100G ext4 at `/home/jaded/docker/llamacpp/models`) holding only redownloadable Qwen3-30B GGUFs (too big for tower's M4000 anyway). It was hot-unplugged and destroyed to return the VM to one disk: guest `umount` + comment fstab line → tower `qm set 101 --delete scsi1` → `qm disk unlink 101 --idlist unused0`. Returned ~54G to tower's SSD pool. If root ever needs more space, grow the single disk instead of adding one: `qm resize 101 scsi0 +NG` then online `pvresize /dev/sda3; lvextend -l +100%FREE; resize2fs`.

**Best space check:** `ssh ubuntu 'df -hT'` (local root vs NFS pool at a glance).

## NFS pool (export from tower)

Media lives on [[tower]] at `/media-pool/media/` (ZFS HDD), NFS-mounted on VM 101 at `/mnt/media-pool/`. (Previously `/srv/media/` on book5 — migrated Jan 6, 2026.)

**Export** (`/etc/exports` on tower):
```bash
/media-pool/media 192.168.68.101(rw,sync,no_subtree_check,no_root_squash,crossmnt)
/media-pool/ollama 192.168.68.101(rw,sync,no_subtree_check,no_root_squash)
```

> **Critical:** `crossmnt` is required for `/media-pool/media` because Movies and Serials are separate ZFS child datasets. Without it, those directories appear EMPTY over NFS.

**Mount** (`/etc/fstab` on VM 101):
```bash
192.168.68.249:/media-pool/media /mnt/media-pool nfs defaults 0 0
192.168.68.249:/media-pool/ollama /mnt/ollama nfs defaults 0 0
```

**Verify:** `ssh jaded@192.168.68.101 "df -h | grep media-pool"` · **Library size:** `ssh root@192.168.68.249 "du -sh /media-pool/media/*"`

## Directory layout (`/media-pool/media/`)

- **TV Shows** → `/media-pool/media/Serials/` as `Show Name/Season XX/episodes...`
- **Movies** → `/media-pool/media/Movies/` (standalone at root, franchises in folders)
- Plex library roots (inside container, `/mnt/media-pool` → `/media/tower`): Movies=`/media/tower/Movies`, TV=`/media/tower/Serials`, Sermons=`/media/tower/Sermons`

Star Wars movies are numbered by in-universe chronology (01-03 prequels, 04-05 anthology, 06-08 originals, 09-11 sequels).

## Media pipeline: download → scan → move

qBittorrent (Docker) downloads to `/home/jaded/downloads` — a **local root sandbox kept on purpose** so files are ClamAV-scanned before touching the NFS pool. A cron job then organizes verified media onto the pool.

**`scan-and-move.sh`** (`/home/jaded/scripts/scan-and-move.sh`):
1. Scans `/home/jaded/downloads/` for completed downloads
2. Queries qBittorrent API to verify completion (via `.!qB` incomplete-file markers)
3. Runs ClamAV virus scan (`docker exec clamav clamdscan`)
4. ffprobe quality-score + dedup
5. Organizes into `/mnt/media-pool/{Movies,Serials,Music}` (TV → `Show/Season XX/`) via `safe_move()` (copy → verify → delete)

Force a run: `ssh ubuntu '/home/jaded/scripts/scan-and-move.sh'` · watch `tail -f /home/jaded/scripts/scan.log`

> NOTE: The deep-doc (`media-server.md`) records the cron as **disabled Dec 27 2025** pending a rework (return-value bugs in `is_download_complete()` — script proceeded even when logging "SKIPPING"). The newer VM-101 mapping (2026-05-26) describes it running **every 10 min** after the `.!qB` fix below. Treat cadence as uncertain and verify the crontab before relying on it.

### qBittorrent completion handling (fix 2026-05-26)

Completion detection was broken: qBit torrent names ≠ download folder names, and `TempPathEnabled`/`AddExtensionToIncompleteFiles` were **off**, so qBit never wrote the `.!qB` markers the script expected. The script saw pre-allocated zero-filled partials as "complete" and copied junk to NFS every run — only the `is_file_valid` ftyp/mkv-magic safety check blocked the bad moves.

- **Fix:** set `Session\AddExtensionToIncompleteFiles=true` in `/var/lib/docker/volumes/qbit-config/_data/qBittorrent/qBittorrent.conf`. **Must edit while the container is stopped** — qBit rewrites the conf on clean exit. Then force-recheck (`POST /api/v2/torrents/recheck hashes=all`) to rename in-progress files to `*.!qB`. Now `has_incomplete_files` correctly skips partials.
- qBit web UI: `http://192.168.68.101:8080`. Earlier tuning (Dec 27 2025): removed the 1 MB/s limit, enabled UPnP/port forwarding, max connections 500.

> **GOTCHA — free local disk after a title lands in Plex:** the script deletes the source from `/downloads` after the move, but qBit keeps **seeding** the now-deleted files, holding their FDs open → space is NOT reclaimed (`df` stays high while `du` drops; `sudo lsof +L1 | grep deleted` shows the held files). **Fix: Stop or Remove the completed torrent in the qBit GUI** → closes FDs → space frees instantly. Not auto-deleted by choice (rare use).

qBit is routed through the VM 101 Mullvad exit — see [[mullvad]] (used for downloading games + movies Joshua owns physical copies of; follows the active exit hop).

## Google Drive integration (rclone on VM 101)

rclone FUSE mounts with VFS caching expose two Google accounts on VM 101. Best for documents/configs/backups; **not** for video editing or databases.

```
/home/jaded/GoogleDrives/
├── elevated/   (joshua@elevatedtrading.com)  → MyDrive / SharedDrives / OtherComputers
└── jaded/      (jaded423@gmail.com)          → MyDrive / SharedDrives / OtherComputers
# Convenience symlinks
/home/jaded/elevatedDrive → GoogleDrives/elevated
/home/jaded/GoogleDrive   → GoogleDrives/jaded
```

| Account | rclone remote | Mount point | systemd (user) service |
|---------|---------------|-------------|------------------------|
| Personal (`jaded423@gmail.com`) | `gdrive` | `~/GoogleDrives/jaded/MyDrive/` | `rclone-gdrive.service` |
| Work (`joshua@elevatedtrading.com`) | `elevated` | `~/GoogleDrives/elevated/MyDrive/` (holds Elevated Vault) | `rclone-elevated.service` |

**VFS settings:** cache mode `writes`, max age 24h, read chunk 128MB, buffer 64MB. First access is slow (cloud fetch); cached files fast for 24h; writes cached and uploaded in the background.

**Service management:**
```bash
systemctl --user status  rclone-elevated.service   # or rclone-gdrive.service
systemctl --user restart rclone-elevated.service
systemctl --user enable  rclone-elevated.service
journalctl --user -u rclone-elevated.service -f
```

**rclone checks:** `rclone listremotes` · `rclone lsd gdrive:` / `rclone lsd elevated:` · `rclone about gdrive:` (space)

### Proxmox node access (SSHFS)

Both Proxmox nodes re-mount the Drives from VM 101 over SSHFS (`/etc/fstab`):
```bash
jaded@192.168.68.101:/home/jaded/GoogleDrives/elevated /mnt/elevated fuse.sshfs defaults,allow_other,_netdev,reconnect,IdentityFile=/root/.ssh/id_rsa 0 0
jaded@192.168.68.101:/home/jaded/GoogleDrives/jaded    /mnt/jaded    fuse.sshfs defaults,allow_other,_netdev,reconnect,IdentityFile=/root/.ssh/id_rsa 0 0
```
Obsidian.nvim points at `/mnt/elevated/MyDrive/Elevated Vault` (`~/.config/nvim/lua/plugins/tools/obsidian.lua`).

> NOTE: `google-drive.md` also documents a Samba path for other VMs to reach the Drives. Samba was **RETIRED 2026-05-27** (smbd disabled on book5 — unused, `/root`-share security smell), so the CIFS mount route is no longer available; use SSHFS or the rclone mounts directly.

## Sources

- `~/.claude/docs/homelab/media-server.md` (media layout, NFS export/mount, scan-and-move, qBit)
- `~/.claude/docs/homelab/google-drive.md` (rclone mounts, systemd services, SSHFS)
- `~/projects/homeLab/CLAUDE.md` lines 45–119 (Operational Current State — Mullvad exit, Samba retirement, 2.5G NIC)
- Memory `project_vm101_media_layout` (2026-05-26 storage-tier mapping, `sdb` teardown, `.!qB` fix, seeding-FD gotcha)
