---
type: component
title: VM 101 — Ubuntu (media / services / Mullvad box)
tags: [vm101, ubuntu, media, plex, frigate, ollama, mullvad, docker, services]
related: [tower, vm111-homeassistant, mullvad, watchdogs, gpu-passthrough, storage, access-model]
host: ubuntu
ip: 192.168.68.101
---

# VM 101 — Ubuntu (`ubuntu` / `vm101`)

The busiest node in the lab: media servers, local LLM inference, NVR, torrents,
game-streaming and transcription — all Docker/systemd on one Ubuntu Server 22.04 VM
running on [[tower]]. It is **the only machine on Mullvad** (native WireGuard client,
lockdown ON) → see [[mullvad]]. Sibling VM on the same host = [[vm111-homeassistant]].

## At a glance

| Property | Value |
|----------|-------|
| VMID | 101 (on [[tower]], rpool) |
| Hostname | ubuntu-server |
| OS | Ubuntu Server 24.04.4 LTS (verified 2026-09-30, kernel 6.8.0-146; 26.04.1 is offered but not taken — the NVIDIA 535 passthrough stack is the risk, see TODO) |
| User | `jaded` (passwordless sudo, in `docker` group) |
| RAM / vCPU | 48 GB / 28 cores |
| Disk | 292 GB root (tower rpool); 84 GB free on 2026-09-30 |
| NIC | `enp6s18`, IP **192.168.68.101**, gw `.1` — on tower's **2.5G `vmbr1`** since 2026-06-19 |
| GPU | NVIDIA Quadro M4000 (8 GB, vfio passthrough from tower) → [[gpu-passthrough]] |
| Access | `ssh ubuntu` → **ProxyJump tower** (Mullvad walls off the tailnet) → [[access-model]] |

> NOTE: older deep doc lists the NIC as `eth0` on `vmbr0`; current state (CLAUDE.md
> 2026-06-19 / 2026-07-02) is `enp6s18` on the 2.5G `vmbr1`. After any tower reboot/power
> event, **verify the tap master** re-attached: `bridge link show | grep tap` (the
> `ip link set tapNi0 master vmbr1` fix is runtime-only). STO single-hop ~1.18 Gbps down
> since the 2.5G merge (was ~950 Mbps on the old 1G).

## Access

```bash
ssh ubuntu            # bare alias → ProxyJump tower (Mullvad lockdown blocks the tailnet)
ssh vm101
ssh jaded@192.168.68.101
```

Tailscale was **removed from VM101 entirely (2026-06-19)** — the daemon was purged and the
node deleted from the tailnet; Mullvad lockdown always showed it offline and access was
never via Tailscale anyway. Web UIs for VM101 apps stay on **Twingate** (Mullvad/LAN-only,
not MagicDNS). Full model → [[access-model]].

> **Both Odoos share one Twingate resource** ("Odoo", addr `192.168.68.101`, alias
> `odoo.lab`, TCP ports **`8069-8070`**): `odoo.lab:8069` = test/business, `odoo.lab:8070`
> = personal/finance (same host, different container ports). To expose a new port, widen
> that resource's TCP range in the TG admin console — **not** a DNS/alias change. **Gotcha:**
> after a port change the TG *client* caches the old policy and returns `ERR_CONNECTION_REFUSED`
> (an active refuse, not a timeout) on the new port — quit/relaunch the client (or just re-hit
> the URL) to force a policy re-pull. The direct IP `192.168.68.101:8070` bypasses TG entirely.

## Service inventory

This page owns the full VM101 service list. Ports, purpose, and compose location:

| Service | Port(s) | Type | Location | Purpose |
|---------|---------|------|----------|---------|
| **Plex** | 32400 | docker | `~/docker/plex/` | Primary media server (`/mnt/media-pool/media`). Binds UDP to the LAN IP → **some Plex cloud/discovery traffic bypasses Mullvad by design** (not a misconfig); local streaming stays on tunnel |
| **Jellyfin** | 8096 | docker | `~/docker/` | Backup media server (same content) |
| **qBittorrent** | 8080 | docker | `~/docker/` | Torrent client (Web UI); downloads to `/mnt/media-pool/media/downloads`. Follows the active Mullvad exit |
| **Ollama** | 11434 | systemd | — | Local LLM inference API; models on NFS `/mnt/ollama/models` (`OLLAMA_MODELS` override). GPU limits below |
| **Open WebUI** | 3000 | docker | `~/docker/open-webui/` | Chat UI for Ollama |
| **Frigate** | 5000 (UI/nginx), 5001 (backend), 8554 (RTSP), 8555 (WebRTC) | docker | `~/docker/frigate/` | NVR, 2 Tapo cameras (below). Labeled `autoheal=true` → [[watchdogs]] |
| **Mosquitto** | 1883 | docker | `~/docker/frigate/` | MQTT broker for Frigate |
| **Local ALPR** | 8088 | docker | — | License-plate recognition |
| **Plate Recognizer** | internal | docker | — | ALPR engine (feeds Frigate) |
| **CodeProject.AI** | 32168 | docker | — | **Stopped** |
| **steam-headless** | 8083 (web desktop), 47990 (Sunshine) | docker | — | Game-stream rig (`josh5/steam-headless`), uses the passed-through M4000; NVENC walled by Maxwell EOL → software x264 |
| **whisper** | on-demand | docker | `~/docker/whisper` | `local/faster-whisper` CPU transcription (`docker compose run` profile `manual`; distil-large-v3 int8 24-thread ≈ 4.1× realtime; GPU walled by Maxwell → CPU-only). Feeds the Mac `trans -sermon` tool |
| **Odoo** | 8069 | docker | `~/docker/odoo/` | Business ERP — **test/staging** instance (Odoo 17, matches work). `odoo-db` PostgreSQL 15 |
| **Odoo (personal/finance)** | 8070 | docker | `~/docker/odoo-personal/` | **Personal expense tracking** — Odoo 19 Community + OCA (`account_financial_report`, `web_responsive`), `odoo-db-personal` PostgreSQL 16. Fully isolated from the 8069 test stack (own network/DB, no shared data). Owned by the [finance project](~/projects/personal/finance/CLAUDE.md); secrets in the box `~/docker/odoo-personal/.env` (gitignored) |
| **Nextcloud** (sandbox) | 8085 | docker | `~/docker/nextcloud/` | **Tinker instance, no real data** (2026-09-30) — `nextcloud:apache` + `nextcloud-db` PostgreSQL 16 + `nextcloud-redis`; data in `./html` + `./db` beside the compose. Plain HTTP on the LAN IP (`trusted_domains` = `192.168.68.101`). Admin account is made in the browser on first visit. Part of the de-Google exploration |
| **Grist** (sandbox) | 8484 | docker | `~/docker/grist/` | **Tinker instance** (2026-09-30) — `gristlabs/grist:stable` (`latest` is the nightly build), gVisor formula sandbox, data in `./persist`. "No authentication" mode: anyone on the LAN is `j@jadedviber.com` in the browser; the API still needs a key. API from the Pocket = `grist-api <path>` (`scripts/bin`), key in 1Password `op://Lab/Grist sandbox/credential`, fetched per call by `op run` — the first real `op` consumer (2026-10-01) |
| **Immich** (sandbox) | 2283 | docker | `~/docker/immich/` | **Tinker instance** (2026-09-30) — the project's own `docker-compose.yml` + `.env` (server, machine-learning on CPU, valkey, postgres). Library in `./library`, DB in `./postgres` on the root disk — fine for test photos; the real library waits for the 10 TB pool and its own dataset |
| **Gitea** | 3001 (web), 2223 (ssh) | docker | `~/docker/gitea/` | Self-hosted git mirror; the weekly `push-all` skill pushes here (16 repos) alongside GitHub + Pi1 |
| **ClamAV** | — | docker | `~/docker/` | Antivirus scanning |
| **Portainer** | 9000 | `docker run` | — | Docker management UI |
| **autoheal** | — | docker | `~/docker/frigate/` | `willfarrell/autoheal` — restarts unhealthy labeled containers → [[watchdogs]] |

> NOTE: the authoritative CLAUDE.md service line (2026-06-19) enumerates Plex/Jellyfin/
> Ollama/Frigate/qBittorrent/Local ALPR/Plate Recognizer/CodeProject.AI(stopped)/
> steam-headless/whisper. Open WebUI, Odoo, Gitea, Mosquitto, ClamAV, Portainer come from
> the older deep doc — likely still live (Gitea is confirmed by the current `push-all`
> mirror) but not re-verified in the current-state line.

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'   # all containers
cd ~/docker/<service> && docker compose up -d          # (re)start a compose service
cd ~/docker/<service> && docker compose logs -f
docker restart <container>
```

All compose stacks live under `~/docker/` (`frigate/`, `gitea/`, `odoo/`, `open-webui/`,
`plex/`, `whisper/`, …).

## Ollama (LLM inference)

Models on the HDD via NFS (`/mnt/ollama/models`). GPU = M4000 (8 GB VRAM) → hybrid mode.

| Model | Size | Best for | Speed |
|-------|------|----------|-------|
| `qwen3-pure-hybrid` | 18 GB | Complex reasoning / coding | ~14 tok/s |
| `qwen-gon-jinn-hybrid` | 14 GB | General tasks | ~12 tok/s |
| `qwen2.5-coder:7b` | 4.7 GB | Code generation | Fast (full GPU) |
| `llama3.2:3b` | 2.0 GB | Quick queries | Very fast |

**GPU limit:** ≤18 GB models run hybrid GPU+CPU (~10–14 tok/s); **19 GB+ crash CUDA** and
need CPU-only (`OLLAMA_NUM_GPU=0` — 70B ≈ 1.47 tok/s, slow but usable).

```bash
ollama list
ollama run qwen2.5-coder:7b
systemctl status ollama && sudo systemctl restart ollama
```

## Frigate NVR

Continuous 24/7 recording on the HDD NFS pool (async, ~130 MB/s), ~35 GB/day → ~1 TB at
30-day retention. Config `~/docker/frigate/docker-compose.yml`; UI `http://192.168.68.101:5000`.

| Camera | Model | IP | Link | Resolution | Codec |
|--------|-------|-----|------|------------|-------|
| PetCam (Tapo) | *(unrecorded — check Tapo app → Device Info)* | 192.168.68.75 | — | 2560×1440 (2K) | H.264 |
| Porch (Tapo) | **C560WS** hw 1.0, fw 1.1.10 | 192.168.68.76 | Wi-Fi (`Spaceballs`) | 3840×2160 (4K) | H.265 |

> **C560WS has NO PoE.** It has a 10/100 ethernet port but powers from a 12V DC barrel plug,
> so a wired run still needs power at the camera — or a **PoE splitter** (PoE in → 12V DC +
> ethernet out) to get down to a single cable. Model captured 2026-08-07 from the Tapo app;
> ONVIF (port 2020) requires auth and HA only sees these through Frigate, so the app is the
> quickest source of truth for camera hardware.

Frigate's nginx (5000) can serve the page shell while the backend (5001) is wedged → shows
"unhealthy" with a blank UI; that's the failure mode **autoheal** catches (POSTs a webhook →
HA notification when it fires). If it fires often, root-cause the `plate_recognizer` →
`/api/events/.../clip.mp4` export stall. Self-healing detail → [[watchdogs]].

**Detector = OpenVINO on CPU, container pinned to 6 CPUs (`cpuset: "0-5"`, 2026-10-02).** OpenVINO
sizes its thread pool to the CPUs it can see; with all 28 vCPUs visible it spun 28 threads at ~5.5
cores for ~0.2 core of real work (SSDLite MobileNet, ~25 inferences/s). Pinned: detector ~1.2 cores,
inference 7 → 10 ms, 0 skipped frames. **GPU detection is not possible on the M4000 with Frigate
0.16+** (tested 0.17.1): the image's ONNX Runtime 1.22 / CUDA 12.5 has no kernels for Maxwell
(`cudaErrorNoKernelImageForDevice`), and the TensorRT libraries are no longer shipped. The old
"ran on GPU" era was the pre-0.16 TensorRT detector. The M4000 still does video decode. A GPU
detector needs a newer card or a Coral/Hailo → [[gpu-passthrough]]. Config has a third camera,
`tapo_doorbell` (`192.168.68.77`), which was unreachable on 2026-10-02.

```bash
docker logs frigate -f
cd ~/docker/frigate && docker compose restart frigate
```

## Mullvad (summary — full detail in [[mullvad]])

**VM101 is the only Mullvad machine** (tower/host is never on Mullvad — full NIC, direct).
Native WireGuard client, **lockdown / kill-switch always ON** (no VPN-off mode), custom DNS
→ Pi-hole `192.168.68.248`.

- **Default / everyday = single-hop Stockholm** (`mv-sto`) — used for everything incl.
  downloads. ~1.18 Gbps down.
- **Swap to multihop `se sto` → `us dal` (Dallas)** (`mv-dal`) **only when launching a
  game**: Rockstar/Steam reject a Sweden exit IP ("unusual activity detected") — a US exit
  is the only way to log in.
- Swap aliases live in VM101's `~/.zshrc` (user `jaded`). All Mullvad-routed apps (qBit,
  etc.) follow the active exit. From the Mac, the `mvpn` zsh function drives it.

**IPv6 disabled (2026-07-02):** `/etc/sysctl.d/99-disable-ipv6.conf` (`disable_ipv6=1` +
`accept_ra=0` on `enp6s18`; `::1` kept). Removed the router-RA ULA so outbound is IPv4 —
IPv6-through-Mullvad was tarpitting Debian mirrors (~52 KB/s vs 5.4 MB/s on v4).

## Storage (summary — full tiers in [[storage]])

NFS mounts from tower's media-pool (Plex/Frigate/Ollama read only these; ~3.2T pool):

| Mount | Purpose |
|-------|---------|
| `/mnt/media-pool/media` | Plex / Jellyfin / qBit content |
| `/mnt/ollama/models` | Ollama LLM models |
| `/mnt/media-pool/frigate` | NVR recordings |

```bash
df -h | grep media-pool     # check mounts
sudo mount -a               # remount all (fstab)
```

> NOTE: the older ubuntu.md lists the Ollama mount as `/mnt/media-pool/ollama`; the
> ollama-specific services doc (and the `OLLAMA_MODELS` override) use `/mnt/ollama/models`.

## GPU (summary — full detail in [[gpu-passthrough]])

M4000 is vfio-bound from [[tower]] to VM101 (the only host-visible GPU in the lab).
NVENC is walled by Maxwell EOL → steam-headless and whisper fall back to software/CPU.

**GPU-enabled btop 1.4.7** (2026-07-03) is source-built at **`/usr/local/bin/btop`**
(`GPU_SUPPORT=true`, `CXX=g++-14`) — renders the M4000 box (util/vram/temp/clocks). The old
**snap btop was removed** (`/snap/bin` shadowed `/usr/local/bin` in login-shell PATH, hiding
the GPU box). GOTCHA: the official static release ships `GPU_SUPPORT=false` (musl can't
dlopen glibc NVML) → **must build from source**, and 1.4.7 needs **g++ ≥ 14** (uses C++23
`std::ranges::to`; stock g++-13 fails).

## Scheduled mail — the "home email" sender (2026-09-16)

VM101 is the always-on box, so timed/automated mail from Joshua's own identity runs here, not from a laptop.

- **Identity:** `j@jadedviber.com` (jadedviber.com Workspace org). Token in `~/.config/gsuite/` (user `jaded`), issued by an **Internal** OAuth client (GCP project `mcps`) → never expires. The box did its **own consent**, no token copied in: `ssh -t -L 8765:localhost:8765 ubuntu 'GSUITE_AUTH_PORT=8765 ~/.venvs/gsuite/bin/gsuite auth'`, open the printed URL on the laptop. (`GSUITE_AUTH_PORT` added to the gsuite package for exactly this.)
- **Install:** `~/projects/gsuite` (clone of jaded423/gsuite) into `~/.venvs/gsuite`; client file + settings in `~/.config/gsuite/`.
- **Helper:** `~/.local/bin/gmail-send TO "SUBJECT" < body.txt` — plain-text send as j@. Verified 2026-09-16 (test to jaded423).
- **Scheduling — `~/.local/bin/gmail-at "YYYY-MM-DD HH:MM" TO "SUBJECT" < body.txt`** (added 2026-09-17). Writes a **persistent** systemd user timer + service pair (`~/.config/systemd/user/mail-<stamp>-<slug>.{timer,service}`) plus a runner + body under `~/.local/share/mail-at/`. `Persistent=true` → if the VM was down at fire time it sends on next boot instead of dropping silently; `loginctl enable-linger jaded` is ON (2026-09-17) so nothing needs a login. Units **self-remove after a good send**; a failed send leaves them in place so `gmail-at --list` / `journalctl --user -u 'mail-*'` shows it. `gmail-at --cancel NAME` drops one. First real job: the Point4 reminder to joshua@elevatedtrading.com, 2026-09-17 09:45. **This is what "schedule an email for 9am" means** — arm it here from j@; a Gmail draft is not a scheduled email. Recurring mail: hand-write a `*.timer` pair, or a crontab line piping into `gmail-send`.
- **Why not a personal Gmail token here:** consumer accounts sit on an External-Testing OAuth app → refresh tokens die every 7 days → a scheduler here would stop silently. Detail: brain `jadedviber-workspace-org`, `gsuite-home-instance`.

## 1Password lab — `~/op-lab/` (2026-09-30, throwaway)

Test bed for "can a GUI-less host run a job whose secret lives in 1Password?" — answer: yes.

- **CLI:** `~/.local/bin/op` 2.39.0 (user bin, no sudo; not on the non-interactive PATH, so scripts call it by full path).
- **Auth:** a 1Password **service account** scoped read-only to the `Lab` vault. Its token sits in `~/.config/op/sa.token` (600); `run.sh` exports it as `OP_SERVICE_ACCOUNT_TOKEN` for the one command. `~/.config/op` must be **700** or `op` refuses to start.
- **Flow:** `.env` holds a reference (`op://Lab/op-lab dummy/password`) → `op run --env-file=.env -- ./check.sh` resolves it at launch → the job sees the value in its env; nothing lands on disk, and `op run` conceals the value in the child's output.
- **Run:** `ssh ubuntu '~/op-lab/run.sh'` → `PASS: correct password received (len 5)`.
- **Teardown:** `rm -rf ~/op-lab ~/.config/op/sa.token` + delete the service account and the `Lab` vault in 1Password.

## Troubleshooting

```bash
# NFS mounts missing
ls /mnt/media-pool/ && sudo mount -a && cat /etc/fstab | grep media-pool
# GPU not visible → may need VM reboot, or check passthrough on tower → [[gpu-passthrough]]
nvidia-smi
# Container won't start
docker logs <container>; df -h; docker compose up -d --force-recreate <container>
# No internet although Mullvad says Connected → routing rules wiped → [[mullvad]] § Gotcha
ip rule | grep -c 1836018789 || mullvad reconnect -w
```

Also: `yt-dlp` at `~/.local/bin/yt-dlp`. Do **NOT** add VM101 to the router's VPN Client List (Deco-era note; same rule on the Archer) —
it conflicts with the native Mullvad client (Mullvad's firewall rules block Deco's outer
tunnel → `Cannot reach the API`). See [[mullvad]].

## Sources

- `~/.claude/docs/homelab/ubuntu.md`
- `~/.claude/docs/homelab/services.md` (VM101 service details)
- `~/projects/homeLab/CLAUDE.md` "Operational Current State" lines 45–119 (authoritative)
