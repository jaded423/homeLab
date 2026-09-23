---
type: component
title: CT 316 — sermons (pages + audio host)
host: sermons
ip: 192.168.68.116 (static, LAN-only)
tags: [lxc, ct316, sermons, nginx, caddy, book5, pi-gw1, archive]
related: [book5, tower, pi-gw1, access-model, storage]
---

Unprivileged Debian 13 LXC on [[book5]] (1 GB RAM, 2 cores, 8 GB root on `local-zfs-book5`),
created 2026-09-21 on [[tower]] (316 for John 3:16), **moved to book5 2026-09-23**. It is the
ONE home of the sermon site: follow-along pages + per-sermon `audio.mp3` + transcripts. The
Pocket's `~/llm/sermons` cache mirrors here nightly; the mp3 then lives only here.

**Shape (since 2026-09-23):**
```
phone / Pocket (tailnet) → https://sermons.jadedviber.com  (DNS → pi-gw1's tailnet IP)
  → pi-gw1 Caddy: TLS (LE DNS-01, Cloudflare) + reverse_proxy 192.168.68.116:80
  → CT 316 nginx over the house LAN → /srv/sermons
```
pi-gw1 is only the gate (no sermon files written to its SD card); the CT has **no Tailscale**.

| | |
|---|---|
| Data | `/srv/sermons` inside the CT rootfs (host path `/rpool/data/subvol-316-disk-0/srv/sermons`, owner uid 101000 = CT `sermons`). ~660 MB / 32 sermons at move time, ~20 MB each; grow rootfs with `pct resize 316 rootfs +NG`. |
| nginx | `:80`, autoindex, `allow 192.168.68.0/22; deny all` (so localhost gets 403 — expected), byte-range on `*.mp3` for seeking. |
| Front door | pi-gw1 `/etc/caddy/Caddyfile` `sermons.jadedviber.com` block → `reverse_proxy`. Pre-move copy of the Caddyfile: `Caddyfile.bak-2026-09-23`; pi-gw1 `/srv/sermons` = retired pre-move pages, safe to delete. |
| SSH | `ssh sermons` → `HostName 192.168.68.116`, `ProxyJump book5` (book5's Tailscale), `HostKeyAlias sermons`. Works home or away. |
| Writer | ONLY `scripts/bin/sermon-nightly.sh`: pages (`SERMON_HOST`) and archive (`SERMON_ARCHIVE`) both = `sermons:/srv/sermons`. sha256 read-back before a local mp3 is removed; never `--delete`. |
| Read-back | `trans -sermon` pulls a missing mp3 back from here before yt-dlp. |
| Backup | `tower:/media-pool/media/Sermons` holds the move-time copy (32 mp3). **Not refreshed yet** — nightly pull job still to build (homeLab TODO). |

**Why it moved (2026-09-23):** tower hard-hung twice (Sep 22 16:36, Sep 23 00:35) the day after
CT 316 arrived, after 29 days up; the only kernel WARNING on record is `__dev_change_net_namespace`
from `lxc-device` at this CT's vmbr0→vmbr1 re-bridge. Suspected (unproven): in-CT Tailscale /
netns churn. Moved off tower + Tailscale stripped to isolate it; tower stability watch in homeLab TODO.
Tower-era config: `tower:/root/316.conf.pre-move-2026-09-23`.

**Verify:** `ssh sermons 'du -sh /srv/sermons; ls /srv/sermons/*/audio.mp3 | wc -l'` ·
`curl -sI -r 0-1023 https://sermons.jadedviber.com/<slug>/audio.mp3` → `206`, `server: nginx`, `via: 1.1 Caddy`.
