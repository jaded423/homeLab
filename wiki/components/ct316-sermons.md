---
type: component
title: CT 316 — sermons (pages + audio host)
host: sermons
ip: 192.168.68.116 (static, LAN-only)
tags: [lxc, ct316, sermons, nginx, caddy, cloudflared, book5, pi-gw1, archive, cornerstone]
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
| nginx | `:80`, autoindex, `allow 192.168.68.0/22; deny all` (so localhost gets 403 — expected), byte-range on `*.mp3` for seeking. **Both blocks send `Cache-Control: no-cache` at server level (2026-09-28)** so pages revalidate on every load — without it a phone kept a day-old page by heuristic (Last-Modified) caching after a republish; mp3/png locations keep their own 1-day cache. |
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

**Public copy (added 2026-09-27) — `/srv/sermons-public` → https://cbw.jadedviber.com** (canonical since 2026-09-27 evening; `cornerstone.jadedviber.com` 301s to it, path kept). Same pages
with the ESV text removed (every reference stays; each becomes a "Read … on esv.org" link, pages carry
`noindex` while the church is phone-testing). Built on the Pocket by `scripts/bin/sermon-public.py` inside
`sermon-nightly.sh` (`SERMON_PUBLIC`; the build refuses to publish if any verse text survives) and rsynced
`--delete` for html/json. Served by a second nginx block (`sites-available/sermons-public`: `server_name
cbw.jadedviber.com`, no autoindex, `*.srt/*.txt/*.env/*.mp3` → 404, same LAN-only allow) — the
public site plays from YouTube by default; **since 2026-09-28 the page's Video | Audio switch streams `/<slug>/audio.mp3`, so the public block aliases that ONE path into the private tree** — `location ~ "^/(?<slug>\d{4}-\d{2}-\d{2}-[a-z0-9-]+)/audio\.mp3$" { alias /srv/sermons/$slug/audio.mp3; }` (ranges on, cache 1 d; pre-change copy `sermons-public.bak-2026-09-28`; every other private file still 404s). Every public listener's audio therefore rides the house uplink + cloudflared on pi-gw1, same as the private site's rides Caddy. Reach = **Cloudflare Tunnel on
[[pi-gw1]]** (live 2026-09-27; tunnel `pi-gw1` on the jaded423@ Cloudflare account's Zero Trust Free plan, token `~/.secrets/cf_tunnel_cornerstone` on the Pocket; `cloudflared` systemd service → origin `http://192.168.68.116:80`, original Host header passed
through, so nginx picks this block); no router port is opened and the house IP stays hidden. Only the
hostname routed in the tunnel is public — `sermons.` stays tailnet-only by construction. The
`cornerstone.jadedviber.com` name was pi-gw2's Kuma status URL (piGate `networks/cbw.md`) until 2026-09-27;
repurposed for this. **Both names are routes on the same tunnel** (origin `http://192.168.68.116:80`, Host header passed); `sites-available/sermons-cornerstone-redirect` = the `301` block, so phones see ONE origin (one PWA install). Inverted from cornerstone→cbw to cbw-canonical the same evening (aesthetics, Joshua). The app's own repo + relocation plan: `~/.claude/plans/sermons-standalone.md`.
Verify: `curl -s -o /dev/null -w '%{http_code}\n' https://cbw.jadedviber.com/` → `200` from off-tailnet, cornerstone → `301`;
`curl -s https://cbw.jadedviber.com/<slug>.html | grep -c 'class="vn"'` → `0`; `curl -s -o /dev/null -w '%{http_code}' -r 0-1023 https://cbw.jadedviber.com/<slug>/audio.mp3` → `206`.

**Verify:** `ssh sermons 'du -sh /srv/sermons; ls /srv/sermons/*/audio.mp3 | wc -l'` ·
`curl -sI -r 0-1023 https://sermons.jadedviber.com/<slug>/audio.mp3` → `206`, `server: nginx`, `via: 1.1 Caddy`.
