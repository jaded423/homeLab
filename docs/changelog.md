# HomeLab Project Changelog

## 2026-06-15 - PC watchdog 3-tier finished (Tier-2 published) + Elevated Twingate HA connector pair

### Outcome
- **Weekend verdict — Brad Tier-1 watchdog ran clean.** `com.elevated.pc-watchdog` (LaunchAgent, StartInterval 60s) polled all weekend: `fail_count=0`, `reboot_count=0`, zero firings, **no false reboots**. Only log entries were Friday's manual test (self-reset at 2/5). The Tier-2 false-reboot failure mode did NOT recur on Tier-1.
- **Tier-2 rebuilt + PUBLISHED** on omarchy n8n (workflow `sq6c3CWdw5AihV4me8PDB`, "PC Health Monitor v3 (Tier-2 gated)") — finishing the 3-tier design.
- **Elevated Twingate connectors restored as an HA pair** — recreated the deleted WSL connector + added a new Brad connector, both in the `Elevated` remote network (`jaded423`).

### Tier-2 (omarchy n8n)
- Published via the **n8n public REST API** (minted an API key), NOT direct DB edits — that's the fix for the snapshot trap that double-rebooted the PC (n8n runs the `activeVersionId` version snapshot, not `workflow_entity.nodes`). API path sets `activeVersionId` correctly.
- Graph: `Schedule(5m) → executeCommand probe PC 100.105.93.121:22 + Brad 100.82.50.89:22 over tailnet → Code "Decide" (gated) → Switch → {IFTTT plug-cycle | ntfy alert}`. Container confirmed able to reach both tailnet IPs on :22.
- Gate: fires ONLY when **PC AND Brad both down ≥6 cycles (~30 min)**; Brad up ⇒ Decide returns 0 items ⇒ silent (won't fight Tier-1). Verified live: PC up → no-op, no downstream nodes ran.
- Rewired the two notify nodes from IFTTT → **ntfy** (private topic — see local TODO / n8n workflow for the value). IFTTT power-key validated live (non-destructive probe). n8n API key stored `omarchy:~/.n8n_api_key` (0600).

### Twingate connectors (Elevated network `jaded423`)
- **`twingate-wsl`** — recreated on WSL (native Docker 29.1.3), replaced the dead `twingate-daffodil-puma` (its admin-side connector had been deleted → invalid token). Deployed via `--env-file` (inline `--env` + long token strings fail to parse over `ssh wsl`).
- **`twingate-brad-mac`** — new connector on Brad. Brad had no brew/Docker/runtime, so installed a **fully-userspace colima (vz) + docker CLI** in `~/.local` (no sudo/brew/GUI; Apple Virtualization, no qemu). Container→`192.168.1.1` LAN reachability verified (connector can serve Elevated LAN resources). Both connectors reached `Online`.
- **Auto-update: Watchtower** (`nickfedor/watchtower`, daily 04:00 UTC) on each host, scoped to the connector + watchtower.
- Brad chosen over Pi1 for redundancy: Pi1's internet routes through `192.168.137.1` (the PC's ICS), so it dies exactly when the PC does. Brad is the only PC-independent always-on Elevated host. WSL's connector is on the PC, so it also dies with the PC — Brad is the real redundancy.

### Brad cold-reboot resilience (tested)
- **FileVault DISABLED on Brad** + **auto-login** = elevatedtrading (policy: FV only on Macs that leave the premises; Brad is stationary + controlled).
- **Cold reboot tested end-to-end:** reboot → auto-login → colima LaunchAgent → connector `Online` + Tier-1 watchdog polling, all unattended (~2 min).
- The reboot caught a latent bug the manual install hid: the `com.elevated.colima` LaunchAgent ran `zsh -lc "colima start"`, but `-lc` (login, non-interactive) does NOT source `~/.zshrc` where the PATH export lived → `limactl` not found → colima silently failed every boot. **Fixed:** plist now sets `PATH` (and `HOME`) via `EnvironmentVariables` instead of relying on shell rc.

### Why
- Tier-2 was the last unfinished piece of the 3-tier PC watchdog; the Elevated Twingate network had drifted to zero working connectors (WSL connector deleted in admin). Both are PC-availability infrastructure for the Elevated office.

### Gotchas banked
- `containrrr/watchtower` is abandoned — its client API 1.25 < Docker 29's min 1.40, crash-loops. Use the maintained `nickfedor/watchtower`.
- WSL `~/.docker/config.json` had `credsStore: desktop` → `docker --pull` invoked `docker-credential-desktop.exe` (not in WSL PATH) and failed. Removed the key.
- `docker run` over `ssh wsl` with long token `--env` values fails to parse — use `--env-file`.

### Files modified (on the boxes, not this repo)
- `omarchy:` n8n workflow `sq6c3CWdw5AihV4me8PDB` (republished via API); `~/.n8n_api_key` (new, 0600).
- `wsl:` `twingate-wsl` + `watchtower` containers; `~/.docker/config.json` (credsStore removed).
- `brad:` `~/.local/{bin,share,state}` (colima/lima/docker userspace install); `twingate-brad-mac` + `watchtower` containers; `~/Library/LaunchAgents/com.elevated.colima.plist` (PATH fix); FileVault off + auto-login.

### This repo
- `TODO.md` — marked PC-watchdog + Twingate-connectors items done; DHCP-reservations demoted to low-prio/blocked.

---

## 2026-06-05 - Containerized Steam (steam-headless) on VM 101 — second game-stream rig

### Outcome
- **Deployed `josh5/steam-headless` on VM 101 (ubuntu, tower)** as a second Moonlight/Sunshine game-streaming rig, complementing omarchy. Full XFCE desktop + Steam + Sunshine in one container, GPU = the passed-through **Quadro M4000 (8GB dedicated VRAM)**. Verified end-to-end: Steam login → Proton → **Torchlight II** runs, streamed to Mac via Moonlight, Steam Big Picture fullscreen works.
- **Why a second rig:** M4000's 8GB *dedicated* VRAM beats omarchy's shared-RAM Lunar Lake iGPU for VRAM-bound older AAA; 35GB RAM, 28 vCPU, 109GB free for games. Trade-off below.

### Deploy details (`/home/jaded/docker/steam-headless/`)
- `docker-compose.yml` + `.env` adapted from the project's NVIDIA template: nvidia runtime, `network_mode: host`, `/dev/uinput` + `/dev/fuse`, `FORCE_X11_DUMMY_CONFIG=true` (headless dummy display), `ENABLE_SUNSHINE=true`, web desktop on `:8083`, Sunshine on `:47990`. Games → `/mnt/games` (lands at `/mnt/games/GameLibrary`, on the 109GB `/`). Footprint ~8.6GB (image 3.8 + Steam home 4.2 + layer 0.6).
- **Flatpak-installer hang fix:** first boot wedged — `start-desktop.sh` runs `install_firefox.sh`/`install_protonup.sh` (both `flatpak --user`, which deadlocks headless) in a blocking xterm *before* `startxfce4`, so XFCE never starts → Sunshine's "wait for desktop" times out → crash loop. **Fix:** no-op override scripts bind-mounted over both (`overrides/install_*.sh:/usr/bin/install_*.sh:ro`). Durable across recreate. Firefox/ProtonUp non-essential for gaming.
- **CSRF pairing fix:** added `csrf_allowed_origins = https://192.168.68.101:47990` + `origin_web_ui_allowed = wan` to `sunshine.conf` (PIN POST was CSRF-blocked from the non-localhost origin).

### The encoder wall: NVENC blocked by Maxwell EOL
- Current Sunshine (`v2026.516`) needs **nvenc API 13 / driver ≥570**; the M4000 is Maxwell, **permanently capped at the 535 legacy branch** (570+ dropped Maxwell). So **hardware NVENC is impossible with current Sunshine.** VAAPI also fails (no Intel/AMD iGPU on tower). Fell back to **software x264.**
- **x264 verdict (sampled live during Torchlight II):** Sunshine encode ~**1.7 cores**, system 62% busy / 38% idle, M4000 16% util / 624MB, **Frigate cameras unaffected (coexist fine).** Software encode is genuinely viable for older/emulator titles. Set `sw_preset = ultrafast` (bitrate untouched) to cut per-frame CPU spikes.
- **NVENC path (deferred, optional):** to get hardware encode, swap in **Sunshine v2025.122** (Jan 2025, last pre-driver-570 build; ships an AppImage that sidesteps Debian-13 deps). Fragile — breaks on image updates, may force re-pair. Only do it if the audio pulse is confirmed encode-jitter (testing pending).

### Mullvad: single-hop SE → multihop SE-entry / DAL-exit
- VM 101 egresses through Mullvad (Lockdown Mode, was Stockholm exit). Steam flagged the Swedish IP as a suspicious login. **Reconfigured to multihop: entry Stockholm (`se sto`), exit Dallas (`us dal`)** via `mullvad relay set location us dal` + `set entry location se sto` + `set multihop on`. Now `us-dal-wg-* via se-sto-wg-*` — Steam sees a US/Dallas IP (matches account, fast local downloads) while the entry hop stays foreign-jurisdiction. **Affects all VM101 Mullvad-routed apps** (qBit etc. now exit Dallas; still private). Note: the Sweden *entry* hop caps throughput (~264 Mbps vs ~700-900 single-hop vs ~1.9 Gbps bare) — offer-standing to move entry to Canada for speed if wanted.

### Open / pending (user testing tonight)
- **Audio pulsing** (same symptom as omarchy RDR): suspected software-x264 per-frame CPU-spike jitter on the shared Sunshine audio path (VM101 is only ~38% loaded, so not raw load). `sw_preset=ultrafast` applied; if pulse persists it's likely network (omarchy's final verdict was network-jitter), in which case NVENC wouldn't help either.
- **TL2 quirks:** native 2012 Linux build is broken (`ld.so`/LD_PRELOAD) — **force Proton 9.0** (Experimental crashed on Play, 9.0 works). In-game Options menu crashes (Proton quirk, parked). General rule banked: old DX9 → Proton 9.0; new → Experimental/GE; ancient native Linux → force Proton.
- **Big Picture clean-close:** steam-headless's `apps.json` already includes the `steam://close/bigpicture` undo + `xfce4-close-all-windows` + `pkill sunshine` teardown (more thorough than omarchy's) — but only fires when launched via the **"Steam Big Picture" Moonlight app**, not "Desktop."
- Creds are weak LAN defaults (`steam-tower-2026`) — change after testing. Remote access (Twingate/TS) not set up yet.

### Files (on VM 101, not this repo)
- `/home/jaded/docker/steam-headless/{docker-compose.yml,.env,overrides/}` — new.
- `~/.config/sunshine/{sunshine.conf,apps.json}` inside the container (persistent home volume).
- Mullvad daemon settings (multihop) — VM 101 host.

---

## 2026-06-04 - RDR (2024) playable on omarchy via Moonlight/Sunshine (Proton fix chain)

### Outcome
- **Red Dead Redemption (2024 port, Steam appid `2668510`) now runs** on VM 100 (omarchy) streamed to the Mac via Sunshine→Moonlight (Steam Big Picture). Renders the full intro/cutscenes, no crash, no black screen. Audio pulsing fixed by enabling FSR (was iGPU+encoder load contention). Remaining nit: very slight audio crackle on some remote paths only — network jitter on the audio stream, not the box (LAN/good links are clean). Client-side Moonlight audio-buffer bump if ever needed.

### The three real problems (and what actually fixed each)
1. **Crash `ACCESS_VIOLATION (0xC0000005)`** at world-load. Crash dump: fault in `libvkd3d-shader` / `D3D12PixelShader`, `rip 0x600000000005` (garbage jump) — a vkd3d-proton shader-translation bug in **stock Proton Experimental**. *Not* VRAM (lowering render res 2880→1280 didn't move the crash point). **Fix: installed GE-Proton10-34** (`~/.steam/root/compatibilitytools.d/`) and forced it for RDR via `CompatToolMapping` in `config.vdf`.
2. **Black 3D scene** (UI + audio fine). Cause: a leftover launch option **`PROTON_USE_WINED3D=1`** forcing the OpenGL-based wined3d path on a D3D12 game → broken/black render. **Fix: cleared RDR's `LaunchOptions`** in `localconfig.vdf`.
3. **Black/tiny window on Xwayland.** RDR "fullscreen" at a non-desktop res becomes a small black window on the 2880×1800 virtual display (Xwayland can't modeset it). **Fix: set game resolution = desktop (2880×1800)** so fullscreen fills with no mode-switch. Also set `bFocusPaused=false`.

### Hardware reality
- omarchy GPU = **Intel Arc 130V/140V (Lunar Lake iGPU)**, shared system RAM; VM 100 has **~11GB** of book5's **15GB** host (no room to grow — book5 is the OOM-prone laptop). Sunshine's encoder hits the *same* iGPU as the game. RDR 2024 is marginal here; expect to lean on FSR upscaling for playable fps + to keep the audio stream from underrunning.
- Mesa/vulkan-intel `26.0.6`, Proton Experimental `11.0-20260529` — both fresh, so this was a genuine vkd3d↔RDR incompat, not stale drivers. `gamescope 3.16.23` installed as a fallback render-surface lever (not currently in use; the wined3d-flag removal made it unnecessary).

### Files modified (on omarchy / VM 100, not this repo)
- `~/.steam/steam/config/config.vdf` — added `CompatToolMapping` 2668510→GE-Proton10-34. Backup `config.vdf.bak-pre-ge`.
- `~/.steam/steam/userdata/79228882/config/localconfig.vdf` — cleared RDR `LaunchOptions`. Backup `localconfig.vdf.bak-gamescope`.
- `.../Rockstar Games/Red Dead Redemption/graphicsOptions.xml` — res 2880×1800, FSR off (disabled to isolate the black screen), `bFocusPaused=false`. Backups `.bak-pre-vramfix`, `.bak-blackscreen`.

### Known-good rollback config (this entry)
- GE-Proton10-34, empty LaunchOptions, Fullscreen=true, 2880×1800, **FSR3UpscalingQuality=0**, bFocusPaused=false. Crash-free + renders. (Next step: re-enable FSR Performance for fps + to fix the audio pulse — load-induced, iGPU+encoder contention.)
- NOTE: `docs/gaming-vm-plan.md` is **stale** — it describes an abandoned Windows-VM-on-tower-with-M4000-passthrough plan. The actual rig is omarchy Steam/Proton + Sunshine.

---

## 2026-06-03 - HA porch-cam fix, HA 2026.5.4, Frigate self-healing (autoheal + notifier)

### What changed
- **Fixed porch cam watchdog automation.** Repair error `Porch cam offline → power cycle plug ... has an unknown action: tts.google_translate_say`. That TTS service was removed in HA 2026.x. Replaced with modern `tts.speak` (target `tts.google_translate_en_com`, `media_player_entity_id: media_player.family_room_speaker`) — announcement preserved. Cameras were never down; only the automation failed validation.
- **HA core updated 2026.5.3 → 2026.5.4.** Pre-update backup slug `58ba1362` on HA.
- **Frigate self-healing deployed on VM101.** Frigate had wedged: nginx (5000) served the page shell but the backend app (5001) hung — every `/auth`+`/api/*` call 504'd, health check went red (`Up 7 days (unhealthy)`), UI blank. Logs also showed a stuck 60s `clip.mp4` export from `plate_recognizer` (python-requests) piling on `/api/events`. Restarted container to clear the wedge (back to healthy, API 0.17.1), then added `willfarrell/autoheal` to the frigate compose stack + labeled frigate `autoheal=true`. Autoheal polls Docker health every 15s and restarts any unhealthy container, 120s start-period grace to avoid restart loops.
- **Wired autoheal → HA notification.** autoheal `WEBHOOK_URL` → HA webhook `autoheal_frigate_restart` (local_only) → new automation `autoheal_frigate_notify` → `persistent_notification.create`. A Frigate auto-restart now surfaces in the HA bell. Tested end-to-end (webhook 200, automation triggered).

### Why
- Self-healing requested after the manual restart. Autoheal acts on Frigate's existing healthcheck locally on VM101 (no HA dependency — HA itself was the fragile piece earlier this session). Notifier gives visibility into *how often* it fires, so a recurring wedge (suspect: the plate_recognizer events-export loop) surfaces instead of silently looping.

### Files modified (on the boxes, not this repo)
- `ha:/config/automations.yaml` — porch action fix + new `autoheal_frigate_notify` automation. Backup `automations.yaml.bak-2026-06-03`.
- `ubuntu(VM101):/home/jaded/docker/frigate/docker-compose.yml` — added `autoheal` service, `autoheal=true` label on frigate, `WEBHOOK_URL` env. Backup `docker-compose.yml.bak-2026-06-03`.

### Going forward
- If autoheal starts firing often, root-cause the `plate_recognizer` → `/api/events/.../clip.mp4` export stall rather than relying on restarts.

---

## 2026-05-27 - Tailscale-vs-Twingate consolidation: TS now primary, Twingate scoped to media

### Outcome
- **Tailscale is now the primary access layer** for all admin/SSH + homelab web UIs + RustDesk. **Twingate kept only** for what TS structurally can't reach: VM101/Mullvad-locked apps, Home Assistant web UI, AMT break-glass, and the remote (mom's) site.
- Twingate resources pruned **27 → 12**. SSH alias convention **inverted** (bare = Tailscale). Web UIs reachable by **MagicDNS name** (no aliases needed).

### Root cause that kicked this off: TG/TS CGNAT collision
- RustDesk direct-IP to PC failed while `tailscale ping` worked. Cause: Twingate installs a `100.96.0.0/12` route to its tunnel; Tailscale uses `100.64.0.0/10`. The `/12` is more specific → longest-prefix match steals any Tailscale peer numbered `100.96–100.111.x` (PC `100.99`, pi1 `100.98`) into Twingate's tunnel → TCP filtered. `tailscale ping` works because it uses userspace WireGuard, bypassing the OS routing table.
- **Fix deployed:** root LaunchDaemon `com.jaded.ts-pin-routes` + `/usr/local/sbin/ts-pin-routes.sh` on the Mac. Pins PC + pi1 with `/32` host routes via Tailscale's interface (a `/32` beats TG's `/12`). Re-asserts on `RunAtLoad` + network-change events. Verified: TG on → 100.96/12 back on utun5, but PC/pi1 stay on utun4, `nc 100.99.217.17 22` OPEN.

### Twingate resource cleanup (admin GraphQL API)
- Generated an API token (Settings → API, "Claude", Read/Write/Provision), stored in the Mac Keychain (`security find-generic-password -a twingate -s twingate-api -w`). No MCP — curl against `jaded423.twingate.com/api/graphql/`.
- **Deleted 15 redundant resources** (TS covers them, or junk): proxmox-web, Cockpit Book5, Cockpit Tower, prox-tower ssh, zMagic, Omarchy, n8n, mac-ssh, zWindows-SSH, RustDesk, zWindows (127.0.0.1), go-linux (172.17.0.1), homeLab Shared, Homelabel, Go-Elevated.
- **Kept 12:** VM101 apps (Plex, qBit, Frigate, Odoo, Portainer, Open Webui, Jit, Minecraft — Mullvad lockdown blocks direct tailnet), homeassistant (.111 web UI), AMT (.249 out-of-band break-glass — works when tower OS is down, so TS-via-tower can't replace it), mom-lan + Mom-pi (remote site).

### home-assistant VMID 112 → 111
- Renamed back to VM 111 now that the old book5 VM 111 is gone (VMID matches its IP `.111` per original plan). ZFS path: stopped VM, `zfs rename` the 3 zvols (`media-pool/vm-disks/vm-112-disk-{0,1,2}` → `vm-111-*`), `sed` the disk refs + `mv` the config, started as 111. Pre-rename safety backup at `local:/var/lib/vz/dump/vzdump-qemu-112-2026_05_27-11_37_00.vma.zst` (3.3G, delete once stable). IP stays `.111`, HA healthy (`:8123` up, agent OK).

### homeLab Shared retired
- The old Samba share on book5 was stale (no clients; omarchy's client mount was already commented; only a hand-added `[root]` share exposing `/root` rw remained — security smell). Removed the `[root]` share, **disabled + stopped `smbd`/`nmbd`** on book5 (backup `smb.conf.bak-2026-05-27`), deleted the TG resource, removed omarchy's dead CIFS fstab line.

### book5 Twingate connector recovered (recurring DNS bug)
- `prox-book5-systemd` showed DEAD in admin since 2026-05-23 while `systemctl` reported active. Cause: a TG client update reverted book5's `sdwan0` NM DNS back to the dead `100.95.0.x` resolvers (with `dns-priority=-1`, `dns-search=~.` = authoritative for all domains) → all book5 DNS failed → connector couldn't resolve the control plane. Re-applied the pihole override (`nmcli connection modify sdwan0 ipv4.dns 192.168.68.248 ipv4.ignore-auto-dns yes` + `device reapply`) + restarted connector → ALIVE in 10s. **2nd occurrence — every TG update may revert it** (auto-remediation TODO logged in `network-cleanup-todo.md`).

### Pixelbook Go onto Tailscale (CachyOS)
- Replaces the deleted `go-linux` TG resource. Tailscale installed via pacman, authed as `go` (`100.114.126.32`). Flagged a MagicDNS systemd-resolved/NM conflict on Go (cosmetic — IP alias works; TODO logged).

### SSH alias convention inverted (Mac `~/.ssh/config`)
- **bare alias = Tailscale** (primary, works anywhere on tailnet, via MagicDNS), `*-local` = home-LAN direct. Removed the Twingate SSH path entirely (TS reaches every homelab host). Backup `~/.ssh/config.bak-2026-05-27`.
- `omarchy` ProxyJump **dropped** (tested: direct TS works). `ubuntu` **keeps** ProxyJump tower (Mullvad blocks direct tailnet ingress — confirmed by test). pc/wsl/go reverse tunnels through book5 **dropped** (flaky + redundant). Added `pc-ts`/`wsl-ts`/`go-ts` (folded into bare). `trans`/`Homelabel` removed (CT `.61` scrubbed).

### Web UI access via MagicDNS (no aliases)
- MagicDNS works on the Mac (suffix `tail950cc2.ts.net`). Bookmarks: `https://prox-book5:8006` / `prox-tower:8006` (Proxmox), `:9090` (Cockpit), `http://pihole/admin/`, `http://omarchy:5678` (n8n), `https://omarchy:47990` (Sunshine, user `jaded423`).
- **n8n secure-cookie fix:** `http://omarchy:5678` was rejected by n8n's default `N8N_SECURE_COOKIE=true`. Added `N8N_SECURE_COOKIE=false` to `~/docker/tower-guardian/docker-compose.yml` on omarchy + recreated (safe — access is over encrypted TS/LAN). Backup `docker-compose.yml.bak-2026-05-27`.

### Files / artifacts
- `docs/network-cleanup-todo.md` - new follow-up list (book5 DNS auto-reapply, Go MagicDNS, delete HA backup, n8n URL polish, Tailscale Serve option)
- Mac: `~/.ssh/config` (inverted), `/usr/local/sbin/ts-pin-routes.sh` + `/Library/LaunchDaemons/com.jaded.ts-pin-routes.plist` (new)
- book5: `smbd` disabled, `sdwan0` DNS → pihole; omarchy: n8n env + fstab; tower: VM 111 rename + backup

### Addendum (same day): mom-pi onto Tailscale
- mom-pi (Pi 400 @ mom's, Debian 13 aarch64) joined tailnet `100.89.98.66`; `pi-mom` alias now = Tailscale. Disabled the failing `ssh-tunnel.service` (book5 reverse tunnel) — it was always redundant since mom-pi runs its own Twingate connector. Brought up `--accept-dns=false`, Tailscale SSH disabled (key-based like the fleet).

---

## 2026-05-20 → 2026-05-21 - Home Assistant deployed on tower (VM 112) with porch cam watchdog

### Outcome
- HA OS 17.3 running on tower as **VM 112** at **192.168.68.111** (DHCP reservation for MAC `bc:24:11:94:b8:9a`)
- Replaces the IFTTT-based porch cam watchdog (Hubspace plug control was the gap — IFTTT has no Hubspace service, only Tapo)
- Tower watchdog migration is deferred (HA on tower can't watch tower; see Follow-up)

### Why on tower instead of book5
- First attempt was on book5 as VM 111. Book5 hung mid-deploy from userspace OOM (VM 100 omarchy still at 10GB, HAOS first-boot I/O storm pushed it over). ICMP answered, sshd/pveproxy wedged, required physical power-cycle (no remote access).
- Moved to tower. Used VMID 112 because the partial book5 VM 111 record is cluster-wide locked until book5 is recovered and `qm destroy 111` runs.
- Saved memories: `book5-oom-during-vm-deploy.md`, `tower-hang-kernel-pin-not-root-cause.md`, `ha-book5-watchdog-plan.md`.

### Infrastructure changes on tower
- New ZFS dataset `media-pool/vm-disks` → registered as Proxmox storage `media-pool-vm` (zfspool, images+rootdir). Chose this over `local-zfs-tower` (82% full → would push to 91% with HA disk). media-pool already has precedent for non-media datasets (`media-pool/ollama`).
- VM 101 ubuntu-server **trimmed from 64GB → 36GB RAM** via virtio_balloon. Module wasn't loaded in the guest (Proxmox set ballooning target but guest ignored it); loaded with `modprobe virtio_balloon` + persisted via `/etc/modules-load.d/virtio_balloon.conf`. Actual working set in VM 101 was ~7.6GB so 36GB is still 4x headroom.
- VM 112 spec: 4GB RAM, 32GB disk on `media-pool-vm`, q35 machine type, OVMF UEFI **without** pre-enrolled MS keys (`pre-enrolled-keys=0`). Tried SeaBIOS first to skip OVMF debugging — HAOS image is UEFI-only, doesn't boot under SeaBIOS. SB-disabled OVMF works.

### Integrations deployed inside HA
- **HACS** (community store) via SSH addon (Advanced SSH & Web Terminal). Addon required `username: root` because we enabled SFTP — that's a hard requirement of the addon, not a choice.
- **Hubspace** (`jdeath/Hubspace-Homeassistant`, in HACS default repos now). Discovered 6 devices including the dual-outlet outdoor plug HPPA52CWBA023 ("Lights" device, Outside area). Outlet 2 = porch camera = `switch.lights_outlet_2` (friendly name "Porch Camera"). Note: entity_id is generated from device+outlet number, not the friendly name — renaming via UI doesn't change the entity_id, integration regenerates it on reload.
- **Frigate** (blakeblackshear, in HACS default repos). Created 4 devices (Frigate server + 3 cams: Tapo Porch, Tapo 360 Living Room, Plate Zone) but ZERO entities until MQTT was wired up.
- **MQTT**. The non-obvious gotcha: Frigate's HA integration is a discovery/topic listener — without MQTT pointing at Frigate's broker (mosquitto on VM 101 at 192.168.68.101:1883, anonymous), the Frigate devices stay empty. First attempt accidentally picked the "Mosquitto Mqtt Broker app" option which would install HAOS's own bundled broker (separate from VM 101's, would not see Frigate's topics). Removed that, re-added MQTT with "Manually enter broker details" → 192.168.68.101:1883, blank user/pass. Entity count jumped from ~20 (Hubspace + a few HA core) to 118 within seconds.

### Porch cam watchdog automation
- ID `porch_cam_watchdog`, friendly name "Porch cam offline → power cycle plug"
- Trigger: `camera.tapo_porch` state = `unavailable` for 2 minutes
- Action: `switch.lights_outlet_2` off → 10s delay → on → TTS to `media_player.family_room_speaker` (Google Nest Mini, auto-discovered by Google Cast integration)
- Mode: single
- Created via REST API POST to `/api/config/automation/config/porch_cam_watchdog`, then `services/automation/reload`. Verified plug toggles cleanly (off→on tested live during creation — actually power-cycled the cam, came back in ~30s).

### Access plumbing
- Long-lived access token created in HA → stored at `tower:/root/ha-emergency-kit/ha-token-claude.txt` (perms 600)
- HA emergency-kit backup file (the encryption key for HA backups) copied to `tower:/root/ha-emergency-kit/` and `ubuntu:~/ha-emergency-kit/` (perms 600 each). Mac copy deleted by user. 1Password also has it.
- Mac SSH config: added `Host ha` block with `ProxyJump tower` (Twingate intercepts 192.168.68.0/22 from Mac, same workaround as `ssh ubuntu`). `ssh ha` → root@HAOS SSH addon container.
- Twingate resource `homeassistant` (alias `ha.lab`) created pointing at 192.168.68.65, needs updating to 192.168.68.111 (IP moved when we set the DHCP reservation).

### Issues hit and resolved
- **DNS dead on book5** at start of the deploy: `/etc/resolv.conf` listed only Twingate's 100.95.0.x resolvers, which were unresponsive. Fixed in a parallel session by repointing sdwan0's NM connection at pihole (see 2026-05-20 sister entry). `network-health-monitor.sh` patched to also probe DNS — previously logged "green" through the outage because it only checked ICMP+socket+systemctl.
- **VM 112 boot looked black-screen at first**. Screen dumps showed `\0`-only pixels which I mistook for OVMF hanging. Actually HAOS was booting normally; first-boot Supervisor container pulls take 5-15min and the screen sits on "Waiting for the Home Assistant CLI to be ready" for most of it. Got fooled twice (book5 + tower) before checking the screen content properly.
- **VM 112 IP drifted from .65 → .67 → .111** as we added DHCP reservation. HAOS internal "reboot" only restarts containers, not the OS — had to `qm shutdown 112 && qm start 112` to force a fresh DHCP lease grab.

### Follow-up
- **HA-book5 watchdog still pending.** Need a second small HA (2GB/32GB, Tapo integration only) on book5 to watch tower. Plan saved at `~/.claude/projects/-Users-j-projects-homeLab/memory/ha-book5-watchdog-plan.md`. Blocked on book5 being healthy (currently hung from this incident) + VM 100 trim to 6GB.
- **Retire IFTTT applets** (`tower_plug_off`, `pc_plug_off`, etc.) once HA-book5 is up — Tapo integration in HA replaces them all natively.
- **Pi1 off-site watcher** (~50 lines of Python) as belt-and-suspenders for "both home nodes down" scenarios. Defer until HA-book5 done.
- **MQTT auth.** Currently anonymous on mosquitto. Fine on LAN but worth locking down with a user/pass. Need to update Frigate + HA MQTT integration in sync.
- **Hubspace entity_id stability.** Renames via UI don't stick — integration regenerates on reload. If we depend on these in automations, document the entity_ids that exist post-regeneration rather than relying on friendly-name-derived ids.

## 2026-05-20 - book5 DNS broken / sdwan0 swapped to pihole

### Incident
- `ping github.com` on book5 failed with "Temporary failure in name resolution"
- Direct queries to public resolvers (8.8.8.8) worked; only the configured resolvers failed
- `/etc/resolv.conf` listed `100.95.0.251-254` — Twingate's internal DNS, supplied via NM connection `sdwan0` (ipv4.method=manual, ipv4.dns-search=`~.` so it's catch-all)
- `twingate status` reported "online" and `/run/twingate/auth.sock` existed, but `dig @100.95.0.251 github.com` timed out — tunnel up, resolvers themselves not answering

### Investigation
- Confirmed 100.95.0.x are Twingate-owned (route via `sdwan0`, not Tailscale — Tailscale's `dns status` just reads `/etc/resolv.conf` and reports the same IPs as "system DNS")
- `systemctl restart twingate.service` did NOT bring the resolvers back; CLI `twingate stop && twingate start` blocked on an interactive "another VPN active" prompt (Tailscale also up — both use CGNAT, hence the false detection)
- Watchdog `network-health-monitor.sh` had logged every 10-minute check as fully healthy throughout the outage — it never probes DNS resolution, only ICMP to public IPs + systemctl + socket existence

### Fix
1. Started TW client back up via systemctl (left in `online` state)
2. Moved sdwan0 DNS off Twingate's broken resolvers and onto pihole:
   ```
   nmcli connection modify sdwan0 ipv4.dns 192.168.68.248
   nmcli connection modify sdwan0 ipv4.ignore-auto-dns yes
   nmcli device reapply sdwan0
   ```
   Persisted to `/etc/NetworkManager/system-connections/sdwan0.nmconnection`. resolv.conf now has only `nameserver 192.168.68.248`. pihole resolves both LAN and public — book5 does not need Twingate-internal name resolution.
3. DNS verified: `getent hosts github.com` → 140.82.114.4, `ping github.com` succeeds. Twingate still `online`, connector untouched.

### Watchdog Patch
- `/usr/local/bin/network-health-monitor.sh` patched (backup at `network-health-monitor.sh.bak-2026-05-20`)
- Added `check_dns()` — probes `getent ahostsv4` against cloudflare/google/github with 4s timeout
- Added new state branch "Case 4.5: DNS broken but everything else OK" — logs `action=dns_broken` and a hint to check resolv.conf/pihole/sdwan0. **Does not auto-remediate** — the 2026-05-20 incident showed TW client restart didn't fix it, and blind restart loops are worse than a clear log line
- "Case 5: Everything OK" now also requires `dns_ok=OK` so the watchdog doesn't report green during a future DNS outage
- log_check format unchanged (callers compatible); DNS state shows up via a separate `INFO dns_broken: ...` line

### Risk / Follow-up
- If Twingate client install/update overwrites the NM connection, sdwan0 DNS will revert to 100.95.0.x. Backup of original kept; re-apply nmcli commands if observed
- Root cause of TW resolver outage not determined (likely Twingate backend / sdwan0 tunnel state) — if it recurs, capture `twingate logs` + `ip -s link show sdwan0` before re-applying the workaround

## 2025-11-07 - Project Inception

### Initial Setup
- Created homeLab project directory structure
- Initialized git repository
- Created GitHub repository (private): github.com/jaded423/homeLab
- Set up multi-AI documentation (CLAUDE.md, GEMINI.md, AGENTS.md symlinks)

### Research Completed
- Launched gemini-researcher agent for comprehensive market research
- Researched GPU options for local LLM inference (RTX 3090, 4090, L40S)
- Researched server hardware (enterprise servers vs mini PCs)
- Researched complete system configurations
- Researched networking equipment and software stack
- Researched budget optimization and purchasing strategies

**Key Finding:** 100k token context requires ~25GB VRAM for KV Cache alone, making 24GB GPUs (RTX 3090/4090) tight but workable for 7B models. 48GB GPUs (L40S/A6000) remove all constraints.

### Documentation Created
- **llm-homelab-research-2025.md** (884 lines) - Comprehensive research document with:
  - VRAM requirement analysis for different model sizes and context lengths
  - GPU comparison with prices and performance metrics
  - Complete system configurations for three budget tiers
  - Server hardware options (enterprise and mini PC)
  - Networking equipment recommendations
  - Software stack guidance (Proxmox, Ollama, OpenWebUI)
  - Purchase links and vendor recommendations
  - Operating cost estimates
  - Upgrade path strategy

- **build-plan.md** (810 lines) - Actionable implementation guide with:
  - Recommended build specification: Budget-conscious starter ($2,200)
  - Complete component list with purchase links
  - Step-by-step assembly and setup instructions
  - 4-week implementation timeline
  - Software installation procedures
  - Testing and optimization guide
  - Upgrade path strategy
  - Risk assessment and mitigation
  - Alternative configurations for different budgets

### Recommendations Established

**Primary Recommendation:** Budget-Conscious Starter Build ($2,200 total)
- **LLM Workstation** ($1,350):
  - GPU: Used RTX 3090 24GB ($650) - best VRAM-per-dollar
  - CPU: AMD Ryzen 5 7600 ($200)
  - Motherboard: Gigabyte B650M DS3H ($130)
  - RAM: 32GB DDR5-6000 ($100)
  - Storage: 1TB NVMe SSD ($60)
  - PSU: Corsair RM750e 750W ($100)
  - Case: Phanteks Eclipse G300A ($60)
  - Cooler: Thermalright Phantom Spirit ($50)

- **Server Component** ($700):
  - Beelink SER7 (Ryzen 7 7840HS, 32GB RAM, 500GB SSD)
  - Quiet, power-efficient, perfect for home use

- **Networking** ($150):
  - TP-Link DS108-M2 (8-port 2.5GbE switch)

**Capabilities:**
- Run 7B models with ~60k context smoothly (30-40 tokens/sec)
- 100k context possible with offloading (15-20 tokens/sec)
- Annual operating cost: ~$600/year electricity

**Upgrade Path:**
- Short-term (3-6 months): Add storage, upgrade to 64GB RAM ($250-500)
- Long-term (12-18 months): Upgrade to L40S 48GB for true 100k context freedom ($3,000 net after selling RTX 3090)

### Next Steps
1. Set eBay alerts for RTX 3090 under $700
2. Create PCPartPicker list with all components
3. Join communities (r/LocalLLaMA, r/homelab, Ollama Discord)
4. Review research document thoroughly
5. Begin purchasing components

### Resources Compiled
- Purchase links to Amazon, Newegg, eBay, and specialized retailers
- Community resources (Reddit, Discord)
- Learning resources (documentation, benchmarks)
- Price tracking tools
- Software installation guides

---

**Project Status:** Ready for hardware purchasing phase
**Total Documentation:** ~1,700 lines across 3 files
**Next Review:** After component purchases or in 30 days
## 2025-11-12 - Remote Desktop Access (wayvnc) Setup

### Overview
Successfully configured remote desktop access to the CachyOS server using wayvnc, enabling full GUI access via VNC over SSH tunnel. This allows viewing and controlling the Hyprland desktop environment from anywhere with SSH access.

### What Was Implemented

#### 1. wayvnc VNC Server Installation
- **Package:** wayvnc (Wayland-native VNC server)
- **Configuration:** Listens on `127.0.0.1:5900` (localhost only for security)
- **GPU Acceleration:** Enabled with `--gpu` flag for better performance
- **Auto-start:** Added to Hyprland config (`~/.config/hypr/hyprland.conf`)
- **Command:** `wayvnc 127.0.0.1 5900 --max-fps=30 --gpu`

#### 2. SSH Tunnel Configuration
- **Security Model:** VNC not exposed to network, only accessible via SSH tunnel
- **No firewall changes needed:** Port 5900 remains blocked externally
- **Connection method:** SSH port forwarding (`-L 5900:localhost:5900`)

**From Mac:**
```bash
# Create SSH tunnel (keep running)
ssh -L 5900:localhost:5900 jaded@192.168.1.228

# Connect VNC to localhost
open vnc://localhost:5900
# OR
open -a "VNC Viewer" localhost:5900
```

#### 3. VNC-Friendly Keybindings
Added Ctrl-based keybindings that work through VNC (SUPER key doesn't pass through VNC clients):

**Launching Applications:**
- `Ctrl + Enter` → Open terminal (kitty)
- `Ctrl + Space` → Open application launcher (wofi)

**Workspace Navigation:**
- `Ctrl + 1-9` → Switch to workspace 1-9
- `Ctrl + Shift + 1-9` → Move current window to workspace 1-9

**Legacy Bindings (still work):**
- `Ctrl + Alt + T` → Open terminal
- `Ctrl + Alt + Space` → Open app menu
- `Ctrl + Alt + W` → Close active window

**Original SUPER keybindings still work locally** (on physical machine):
- `SUPER + Return` → Terminal
- `SUPER + Space` → App launcher
- `SUPER + 1-9` → Switch workspaces
- `SUPER + Shift + 1-9` → Move window to workspace

#### 4. Waybar Status Bar Configuration
- **Issue:** Waybar couldn't detect Hyprland when started from SSH
- **Solution:** Start Waybar with `HYPRLAND_INSTANCE_SIGNATURE` environment variable
- **Location:** `~/.config/waybar/config`
- **Modules:** Power menu, workspaces, window title, clock, system stats, battery

**Removed:** Temporary [T] and [A] text shortcuts (replaced by keyboard shortcuts)

#### 5. Auto-login Configuration
- **Display Manager:** SDDM
- **Configuration:** `/etc/sddm.conf`
- **User:** jaded
- **Session:** Hyprland
- **Behavior:** Automatically logs in on boot, starts Hyprland and all services

### Files Modified

**Server Configuration Files:**
1. `~/.config/hypr/hyprland.conf`
   - Added wayvnc auto-start command
   - Added VNC-friendly keybindings (Ctrl + Enter, Ctrl + Space, etc.)
   - Added workspace switching and window movement keybindings

2. `~/.config/waybar/config`
   - Restored original configuration (power menu + workspaces)
   - Removed temporary text shortcuts

3. `/etc/sddm.conf`
   - Configured auto-login for user jaded
   - Set session to Hyprland

4. `~/.config/wayvnc/config.bak`
   - Backed up problematic config file (not used, command-line args used instead)

### Usage Instructions

#### Connecting to Desktop Remotely

**Step 1: Create SSH Tunnel**
```bash
# On Mac - open terminal and run:
ssh -L 5900:localhost:5900 jaded@192.168.1.228
# Keep this terminal open
```

**Step 2: Connect VNC Client**
```bash
# In another terminal or Finder (Cmd+K):
open vnc://localhost:5900

# OR use VNC Viewer app:
open -a "VNC Viewer" localhost:5900
```

**Step 3: Use the Desktop**
- Click to interact with windows and menus
- Use VNC-friendly keybindings (Ctrl+Enter, Ctrl+Space, etc.)
- No password required (secured by SSH tunnel)

#### Managing wayvnc Service

**Check if running:**
```bash
pgrep -a wayvnc
```

**View logs:**
```bash
tail -f /tmp/wayvnc.log
```

**Manually start (if needed):**
```bash
WAYLAND_DISPLAY=wayland-1 wayvnc 127.0.0.1 5900 --max-fps=30 --gpu &
```

**Restart Waybar (if workspace numbers missing):**
```bash
killall waybar
HYPRLAND_INSTANCE_SIGNATURE=$(ls -1 /run/user/1000/hypr/ | head -1) \
WAYLAND_DISPLAY=wayland-1 waybar &
```

### Technical Details

**Why SSH Tunnel?**
- **Security:** VNC traffic encrypted via SSH, no plaintext over network
- **No firewall changes:** Port 5900 never exposed to network
- **No VNC password needed:** SSH authentication provides security
- **Works remotely:** Same method works from anywhere (home or via Twingate)

**Why Ctrl Keybindings?**
- **VNC limitation:** SUPER (Windows/Command) key intercepted by VNC clients and host OS
- **Workaround:** Use Ctrl-based shortcuts that pass through VNC protocol
- **Dual support:** Both SUPER and Ctrl bindings coexist (SUPER for local, Ctrl for VNC)

**Performance Settings:**
- **FPS limit:** 30 FPS (good balance of responsiveness and bandwidth)
- **GPU acceleration:** Enabled for smoother rendering
- **Resolution:** Native 2880x1800 (Samsung eDP-1 display)

### Verification

**Connection verified working:**
- ✅ SSH tunnel establishes successfully
- ✅ VNC Viewer connects to localhost:5900
- ✅ Hyprland desktop visible and responsive
- ✅ Mouse input works
- ✅ Keyboard input works
- ✅ Ctrl+Enter opens terminal
- ✅ Ctrl+Space opens app launcher
- ✅ Workspace switching with Ctrl+1-9
- ✅ Window movement with Ctrl+Shift+1-9
- ✅ Waybar displays correctly with workspace numbers
- ✅ Auto-start works after reboot

### Troubleshooting Reference

**Issue: VNC connection refused**
```bash
# Check wayvnc is running
pgrep wayvnc

# Start if needed
WAYLAND_DISPLAY=wayland-1 wayvnc 127.0.0.1 5900 --max-fps=30 --gpu &
```

**Issue: Workspace numbers not showing in Waybar**
```bash
# Restart Waybar with Hyprland signature
killall waybar
HYPRLAND_INSTANCE_SIGNATURE=$(ls -1 /run/user/1000/hypr/ | head -1) \
WAYLAND_DISPLAY=wayland-1 waybar &
```

**Issue: Keybindings not working**
```bash
# Reload Hyprland config (from VNC or SSH)
hyprctl reload

# Or verify keybindings in config
grep -E "bind.*CTRL" ~/.config/hypr/hyprland.conf
```

**Issue: SSH tunnel drops**
```bash
# Keep SSH tunnel persistent with autossh
brew install autossh  # On Mac
autossh -M 0 -L 5900:localhost:5900 jaded@192.168.1.228
```

### Benefits

**Remote Access:**
- Full GUI access to server from anywhere
- No need to be physically at the machine
- Works over Twingate for remote access
- Can manage desktop applications remotely

**Development Workflow:**
- Can use graphical applications remotely
- Test GUI applications without being at server
- Access file managers, browsers, IDEs visually
- Debug desktop environment issues remotely

**Convenience:**
- VNC-friendly keyboard shortcuts for common tasks
- Auto-login on boot (no manual intervention needed)
- Persistent setup survives reboots
- Low bandwidth usage (30 FPS limit)

### Security Considerations

**Good Security Practices:**
- ✅ VNC only on localhost (not exposed to network)
- ✅ SSH tunnel provides encryption
- ✅ No VNC password needed (SSH auth is stronger)
- ✅ Firewall unchanged (port 5900 still blocked)
- ✅ Works with existing SSH key authentication

**Potential Concerns:**
- Auto-login means physical access = full access
  - Acceptable for home lab environment
  - Server is in secure location (home)
- VNC has no additional authentication
  - Mitigated by SSH tunnel requirement
  - Cannot connect without SSH access first

### Future Enhancements

**Possible Improvements:**
- Set up autossh for persistent SSH tunnel on Mac
- Configure VNC Viewer with saved connection
- Add additional Ctrl keybindings for more functions
- Optimize FPS based on network conditions
- Consider X11 forwarding for individual apps as alternative

### Documentation Updates

**Server Documentation (`~/README.md`):**
- Added wayvnc remote desktop access section
- Documented connection procedure
- Added keybinding reference
- Included troubleshooting steps

**Work Mac (`~/.claude/docs/homelab.md`):**
- Remote desktop access section added
- SSH tunnel configuration documented
- VNC client setup instructions
- Security model explanation

---

**Status:** ✅ Fully operational and tested
**Auto-start:** ✅ Configured (survives reboots)
**Security:** ✅ SSH tunnel only (no network exposure)
**Performance:** ✅ Smooth at 30 FPS with GPU acceleration
**Last Tested:** 2025-11-12

## 2026-05-06 - Added Homelable Visualizer LXC (CT 103) on book5

**What changed:**
- Created LXC 103 `homelable` on prox-book5 via community-scripts ProxmoxVE installer
  - Debian 13 unprivileged, 2 vCPU / 2 GB RAM / 8 GB disk on `local-zfs-book5`
  - Bridge `vmbr1`, IP `192.168.68.61` (DHCP)
  - Native install (Python 3.13 + uv venv + Node 20 + Caddy frontend), no Docker
- Configured `SCANNER_RANGES=["192.168.68.0/22"]` in `/opt/homelable/backend/.env`
- Added `homelable-mcp.service` (uvicorn on 0.0.0.0:8001) for AI integration
  - Generated `MCP_API_KEY` and `MCP_SERVICE_KEY`, stored in `/opt/homelable/mcp/.env` and backend `.env`
  - Wired into `~/.claude.json` as MCP server `homelable` (transport: `http`)
- User added Twingate resource for 192.168.68.61 (all ports) so it's reachable from Mac via tunnel

**Why:**
- Wanted a visual topology + live status overview of the homelab
- MCP integration lets Claude Code read topology, trigger scans, add/edit nodes during sessions

**Files modified:**
- `/etc/pve/lxc/103.conf` (book5) — new container
- `/etc/systemd/system/homelable.service` (CT 103) — backend systemd unit (created by installer)
- `/etc/systemd/system/homelable-mcp.service` (CT 103) — MCP server systemd unit (created manually)
- `/opt/homelable/backend/.env` (CT 103) — `SCANNER_RANGES` and `MCP_SERVICE_KEY`
- `/opt/homelable/mcp/.env` (CT 103) — MCP keys + `BACKEND_URL=http://localhost:8000`
- `~/.claude.json` (Mac) — added `homelable` MCP server entry
- `~/projects/homeLab/CLAUDE.md` — added CT 103 to current state
- `~/.claude/CLAUDE.md` — added CT 103 to Home Lab Quick Reference
- `~/.claude/docs/projects.md` — bumped Home Lab Last Updated, added Homelable to services

**Technical notes:**
- **Bridge gotcha:** community-scripts default is `vmbr0`. On book5 vmbr0 is inactive (post Feb-2026 router migration; vmbr1 is the 2.5GbE primary, already documented in global CLAUDE.md). First install attempt failed with "No IP assigned to CT 103 after 60 attempts". Fix: destroy + re-run with `var_brg=vmbr1` env var. Also pin CT ID with `var_ctid=103` (default would have picked 101 since 100/102 are used).
- **MCP transport:** Homelable's README says `--transport sse`, but the server uses `StreamableHTTPSessionManager`. Claude Code needs `type: "http"` (streamable-http), not `type: "sse"`. README is stale — verified via `claude mcp list` showing "Failed to connect" with `sse` and "Connected" with `http`.
- **Skipped host apt upgrade:** installer prompts to run `apt upgrade` on the Proxmox host — declined ([2] Ignore). Out of scope for one LXC install.
- **MCP server is native (not Docker):** community-scripts installer skips MCP entirely. Set up a venv at `/opt/homelable/mcp/.venv` and a separate systemd unit, mirroring the existing `homelable.service` pattern.

---

## 2026-05-06 - Populated Homelable Canvas via MCP

**What changed:**
- Seeded the Homelable canvas with 17 nodes / 13 edges / 4 parent links via MCP from a fresh Claude Code session
- Triggered first nmap scan (192.168.68.0/22) — discovered 26 devices
  - 10 hidden as duplicates of nodes already created
  - 4 approved with confident labels: TP-Link AP (192.168.71.250), PlayStation (.51), Nintendo Switch (.68), Google device (.56)
  - 2 hidden as randomized/transient MACs (visiting phones)
  - 10 left pending for user triage (mostly Espressif ESP32 + TP-Link smart-home gear)
- Created topology: gateway (192.168.68.1) at root → both Proxmox hosts, Pi-hole, Mac, IoT, mobile devices
- Set parent_id on VM/LXC nodes so they nest visually under their Proxmox host

**Why:**
- User wanted to see Homelable in action with their actual network — a fresh install ships with a demo canvas (Freebox Ultra / OpnSense / NAS-01 / etc.) which had been cleared
- Combined manual node creation from documented infrastructure with nmap-driven discovery for unknown devices

**Files modified:**
- (None on Mac — all changes via MCP to `/opt/homelable/data/homelab.db` on CT 103)

**Technical notes:**
- **Gateway and second AP same OUI:** gateway MAC `XX:XX:XX:XX:XX:XX` (.68.1) and `XX:XX:XX:XX:XX:XX` (.71.250) — adjacent MACs, both with the same TP-Link OUI prefix → almost certainly a mesh setup, primary router + AP/satellite. The .71.250 lives in the same /22 broadcast domain.
- **CT 102 trans IP:** 192.168.68.65 (was previously undocumented in network sheets).
- **OUI patterns on the network:** 6× Espressif (ESP32-based custom IoT — Tasmota/ESPHome/Shelly territory), 4× TP-Link (Tapo/Kasa devices), 1× Earda (smart switch/dimmer brand), plus consoles + Chromecast/Nest.
- **Approval payload format:** `approve_device` only takes `id`, `label`, `type`. To set `hostname`/`ip`/`status` afterward, use `update_node`. (We didn't need to since the discovered IP is auto-applied by approve.)
- **Edge defaults:** modeled wifi devices as connecting directly to the gateway (logical topology), not through the AP — Homelable canvas is meant to be a logical map, not a physical L2 trace.

---
