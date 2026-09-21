---
type: component
title: CT 316 — sermons (archive + audio host)
host: sermons
ip: 192.168.71.152 (DHCP; reach it by tailnet name)
tags: [lxc, ct316, sermons, tailscale, nginx, zfs, tower, archive]
related: [tower, vm101-ubuntu, storage, mullvad, access-model]
---

Unprivileged Debian 13 LXC on [[tower]] (1 GB RAM, 2 cores, 8 GB root on `local-zfs-tower`),
created 2026-09-21 (316 for John 3:16). It is the **sermon archive**: the Pocket's
`~/llm/sermons` cache (per-sermon `audio.mp3` + transcripts + `meta.env`, plus `done.txt`/
`skip.txt`) mirrors here nightly, and the mp3 — the bulk, ~25 MB a sermon — then lives ONLY
here. Why a CT and not [[vm101-ubuntu]]: VM101 is walled off the tailnet by [[mullvad]]
lockdown; this box has no VPN and joins the tailnet as `sermons`, so the Pocket reaches it
from anywhere and VM101 stays untouched.

| | |
|---|---|
| Data | ZFS dataset `media-pool/media/Sermons` (compression off; mp3 is already compressed), bind-mounted at `/srv/sermons`; host-side owner uid 101000 = the CT's `sermons` user (uid 1000). Destroying the CT never touches the files. |
| Tailscale | node `sermons` (100.125.37.120); `/dev/net/tun` handed through with `--dev0`. |
| nginx | `http://sermons/` — autoindex over `/srv/sermons`, tailnet + home LAN only (`allow 100.64.0.0/10; allow 192.168.68.0/22`), byte-range on `*.mp3`. Ready for a listen-as-you-read player: `http://sermons/<slug>/audio.mp3`. Not built yet; the pages still come from pi-gw1 (`https://sermons.jadedviber.com`). |
| SSH | `ssh sermons` (sshConfig alias: user `sermons`, the Pocket's `id_ed25519`). |
| Writer | ONLY `scripts/bin/sermon-nightly.sh` (`archive_sermons`; `pull-sermon` wraps the same script). rsync every finished cache dir, read back the remote mp3's sha256, remove the local mp3 only on an equal hash. Tower down → "UNREACHABLE — local mp3s stay", retried next run. Never `--delete`. `ARCHIVE_ONLY=1` = re-verify/backfill without pulling. |
| Read-back | `trans -sermon` pulls a missing mp3 back from here before touching yt-dlp (`RETRANSCRIBE=1` still works). |

**Replaced:** `/media-pool/media/Sermons/` used to be a 55 GB yt-dlp mirror of the church
channel (310 `.mkv`, 2023–2026 — the first attempt at this stack, when the plan was to
transcribe from local video). Deleted 2026-09-21 on Joshua's call (re-downloadable; the
church keeps copies); the dataset now sits at the same path, so the Plex "Sermons" library
root (`/media/tower/Sermons`) is empty — remove or repoint it in Plex.

**Verify:** `ssh sermons 'du -sh /srv/sermons; ls /srv/sermons/*/audio.mp3 | wc -l'` ·
`curl -sI -r 0-1023 http://sermons/<slug>/audio.mp3` → `206`.
