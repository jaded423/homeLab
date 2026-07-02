# HomeLab Project Documentation

## Table of Contents
- [Overview](#overview)
- [Project Goals](#project-goals)
- [Current Status](#current-status)
- [Network Cheat Sheet](#network-cheat-sheet)
- [Quick Reference](#quick-reference)
- [Documentation Structure](#documentation-structure)
- [Version History](#version-history)

## Overview

This project documents the research, planning, and setup of an affordable but powerful home laboratory environment designed to run local LLMs with medium context sizes.

**Project Type**: Infrastructure / Hardware Research
**Status**: Proxmox Running - VMs Deployed
**Budget**: $2,200 (Budget-Conscious Starter Build)

## Project Goals

1. **Server Component**: Reliable server infrastructure for hosting services ✅
2. **LLM Workstation**: Computer capable of running local LLMs with medium context sizes (100k tokens)
3. **Budget-Friendly**: Maximize performance within reasonable cost constraints
4. **Well-Integrated**: Components that work well together with room for growth

## Current Status

**Phase**: Infrastructure Deployed ✅

### Completed
- ✅ Proxmox installed and running on laptop - `prox-book5` (192.168.2.250)
- ✅ 3 VMs configured (omarchy-desktop, ubuntu-desktop, ubuntu-server)
- ✅ Pi-hole DNS running on Raspberry Pi
- ✅ Twingate zero-trust networking configured
- ✅ Twingate service account for headless server access (expires Dec 2026)
- ✅ Git repos cloned to Proxmox (`~/repos/`)
- ✅ SSH access to Mac via Twingate (works from any network)
- ✅ Homelable topology visualizer in CT 103 (192.168.68.61:3000) with MCP server on :8001
- ✅ **Home Assistant OS on tower VM 111** (192.168.68.111) — Hubspace + Frigate + MQTT + porch cam watchdog automation. SSH alias `ha` via ProxyJump tower. Token + emergency kit stored on tower + ubuntu. *(Renamed from VM 112 → 111 on 2026-05-27; IP unchanged.)*
- ✅ **Tailscale promoted to primary access layer (2026-05-27).** Bare SSH aliases now = Tailscale; Twingate scoped to media (VM101/Mullvad apps + HA web UI + AMT + remote site), pruned 27→12 resources. Web UIs via MagicDNS (`https://prox-book5:8006`, etc.). Samba on book5 retired. See changelog 2026-05-27.

---

## Operational Current State (AUTHORITATIVE — homelab source of truth, 2026-06-18)

> This section is the single source of truth for homelab **current state**. `~/.claude/CLAUDE.md` carries only a compact quick-ref + pointer here; `~/.claude/docs/homelab.md` + `docs/homelab/` hold deep reference. `/log` routes homelab current-state changes HERE (Step 0 locale routing). The 192.168.2.x "Network Cheat Sheet" further down is **pre-Feb-2026-migration historical** — ignore for current state.

**Network**: 192.168.68.0/22 subnet (single unified network). **IP Scheme**: 250s=Proxmox/infra, 100s=VMs, 70s=Cameras/IoT.

| Resource | IP | Access |
|----------|-----|--------|
| SSH (prox-book5) | 192.168.68.250 | `ssh book5` |
| SSH (prox-tower) | 192.168.68.249 | `ssh tower` |
| SSH (VM 100 Omarchy) | 192.168.68.100 | `ssh omarchy` (Tailscale direct) |
| SSH (VM 101 Ubuntu) | 192.168.68.101 | `ssh ubuntu` (ProxyJump tower — Mullvad) |
| SSH (magic-pihole) | 192.168.68.248 | `ssh pihole` |
| PetCam (Tapo) | 192.168.68.75 | Frigate on VM 101 |
| Porch (Tapo) | 192.168.68.76 | Frigate on VM 101 |
| SSH (Pixelbook Go) | 192.168.68.247 | `ssh go` (Tailscale) / `ssh go-local`. **Static 2026-06-28** — client-side NM (`/22`, gw `.1`, DNS→pihole `.248`). CachyOS rolling (`7.1.2-cachyos`) — wifi works. *(2026-06-29: rolling showed waybar "disconnected" at Elevated; suspected rolling radio bug. Real fix was on LTS — disabled Twingate (`sdwan0` `~.` DNS hijack → resolvers `100.95.0.x` dead off-LAN) + got Elevated profile connected. NM profiles live in `/etc` = kernel-independent, so the fix carried to rolling: Elevated now connects on BOTH kernels. Rolling wifi NOT broken. LTS `6.18.x-cachyos-lts` kept as fallback.)* |
| SSH (Windows PC) | - | `ssh pc` / `ssh pc-local` |
| SSH (WSL Ubuntu) | - | `ssh wsl` / `ssh wsl-local` |
| SSH (S25 Ultra/Termux) | - | `ssh s25` (mDNS) / `ssh s25-{home,work,tunnel}` |
| SSH (Tablet S9 FE) | 192.168.68.50 | `ssh s9` / `ssh s9-local` (on-demand tunnel) |
| SSH (S10+) | 192.168.68.73 | `ssh s10` / `ssh s10-local` (on-demand tunnel) |
| SSH (Mac) | 192.168.69.222 | `ssh mac` / `ssh mac-local`. **Reserved 2026-06-28** — Archer DHCP reservation → **hardware MAC `2C:CA:16:05:C8:72`** (Private Wi-Fi Address OFF for Spaceballs SSID, else the rotating MAC breaks the reservation). In-pool (.69–.71) reservation; roams on DHCP elsewhere. *(was docs'd `.247`; that's Go now.)* |
| SSH (Pi1 @ Elevated) | 100.98.16.63 | `ssh pi1` (Tailscale, stable regardless of which host's ICS) |
| Samba | — | RETIRED 2026-05-27 (smbd disabled on book5; was unused, `/root` share security smell) |
| Homelable (CT 103) | 192.168.68.61 | UI :3000 (admin/admin), MCP :8001. Native install on book5/vmbr1, scans 192.168.68.0/22 |
| TP-Link AP (mesh node) | 192.168.71.250 | **DESTROYED 2026-06-19** — fried in power surge (no LED, dead in person). Was last node on the surge protector. Replacement node TBD. Cameras (.75/.76) reroute cleanly onto primary AP. |
| CT 102 trans (book5) | 192.168.68.65 | **DESTROYED 2026-06-19** — LXC deleted to free book5 resources (not down — gone). `trans` work runs ad-hoc now, no dedicated container. |
| Twingate | - | jaded423 network |

**Unified SSH pattern (INVERTED 2026-05-27):** `ssh device` = **Tailscale** (bare alias, primary, works anywhere on tailnet via MagicDNS), `ssh device-local` = LAN direct (same network only). Twingate SSH path removed — Tailscale reaches every homelab host. The book5 reverse tunnels for pc/wsl/go were dropped (they're on Tailscale now). Backup of pre-inversion config: `~/.ssh/config.bak-2026-05-27`.

**VM ProxyJump:** `omarchy` now reachable **direct** over Tailscale (own tailnet IP — ProxyJump dropped). `ubuntu`/VM101 **still ProxyJumps tower** (Mullvad lockdown blocks the tailnet on this box). `ha` ProxyJumps tower. These jumps now ride Tailscale (tower bare alias = TS). **Tailscale removed from VM101 entirely (2026-06-19)** — daemon purged + node deleted from tailnet; Mullvad lockdown blocked it reaching the coordination server (always showed offline), and access was never via Tailscale anyway. Access path unchanged (`ssh ubuntu` → ProxyJump tower / Twingate). See changelog 2026-06-19.

**Web UIs (Tailscale MagicDNS, no aliases):** `https://prox-book5:8006`/`prox-tower:8006` (Proxmox), `:9090` (Cockpit), `http://pihole/admin/`, `http://omarchy:5678` (n8n), `https://omarchy:47990` (Sunshine). VM101 apps + HA web UI stay on Twingate (Mullvad/LAN-only).

**Services on VM 101**: Plex (32400), Jellyfin (8096), Ollama (11434), Frigate (5000), qBittorrent (8080), Local ALPR (8088), Plate Recognizer (internal), CodeProject.AI (32168, stopped), **steam-headless** (Sunshine game-stream rig, web desktop :8083, Sunshine :47990 — `josh5/steam-headless` Docker, uses passed-through M4000; NVENC walled by Maxwell EOL so software x264. See changelog 2026-06-05 + memory `vm101-steam-headless`), **whisper** (faster-whisper CPU transcription — `local/faster-whisper` image in `~/docker/whisper`, on-demand `docker compose run` profile `manual`; distil-large-v3 int8 24-thread ≈ 4.1× realtime. GPU walled by Maxwell → CPU-only. Feeds the Mac `trans -sermon` tool. See changelog 2026-07-02)

**VM 101 IPv6 disabled (2026-07-02)**: `/etc/sysctl.d/99-disable-ipv6.conf` (`disable_ipv6=1` + `accept_ra=0` on `enp6s18` + default; `::1` kept). Removes the router-RA ULA so outbound is IPv4 — IPv6-through-Mullvad was tarpitting Debian mirrors at ~52 KB/s (v4 = 5.4 MB/s). Also `yt-dlp` at `~/.local/bin/yt-dlp`.

**VM 101 Mullvad exit — HOP-SWAPPABLE (updated 2026-06-19)**: **VM101 is the only Mullvad machine** (tower/host is never on Mullvad — full NIC, direct). Default/everyday state = **single-hop Stockholm** (`mv-sto`) — used for everything incl. downloading games + movies Joshua owns physical copies of. Swap to **multihop `se sto` → `us dal` (Dallas)** (`mv-dal`) **only when launching a game**: Rockstar/Steam throw "unusual activity detected, cannot connect" on a Sweden exit IP — a US (Dallas) exit was the *only* way to log into Steam. Lockdown stays **ON** in both modes (no VPN-off mode). Swap aliases live in VM101's `~/.zshrc` (user `jaded`). Affects ALL VM101 Mullvad-routed apps (qBit etc. follow the active exit). STO single-hop now ~1.18 Gbps down (since the 2.5G NIC merge below — was ~950 Mbps capped on the old 1G). Multihop set: `mullvad relay set location us dal` + `set entry location se sto` + `set multihop on`; single-hop: `set multihop off` + `set location se sto`.

**VM 101 + VM 111 moved to 2.5G `vmbr1` (2026-06-19)**: during the post-outage cable reroute, tower's VM taps were stranded on the stock 1G `vmbr0` (`nic0`, Intel) / no-bridge — VM101 had silently been on 1GbE the whole time. Merged both onto the 2.5G `vmbr1` (`enp2s0`, r8169). **GOTCHA**: the fix (`ip link set tapNi0 master vmbr1`) is **runtime-only**; VM net0 configs already point at `vmbr1`, so a clean boot *should* reattach correctly, but they stranded once — **verify tap masters (`bridge link show | grep tap`) after any tower reboot / power event**. ~25% throughput gain on STO was a side effect. See changelog 2026-06-19.

**VM 101 self-healing (2026-06-03)**: `willfarrell/autoheal` container in the frigate compose stack (`/home/jaded/docker/frigate/docker-compose.yml`) restarts any container labeled `autoheal=true` when Docker marks it unhealthy (poll 15s, 120s start-period grace). Frigate is labeled. On restart it POSTs `WEBHOOK_URL` → HA webhook `autoheal_frigate_restart` → automation `autoheal_frigate_notify` → HA persistent notification (so you see *when* it fires). Frigate's nginx (5000) can serve the page shell while the backend (5001) is wedged → "unhealthy" but UI blank; that's the failure mode autoheal catches. If it fires often, root-cause the `plate_recognizer` → `/api/events/.../clip.mp4` export stall.

**Roaming Devices** (Mac, Go, Phone, PC, S9 FE, S10+): All maintain reverse SSH tunnels to book5 for cross-device access from any network. Persistence via LaunchAgent (Mac), systemd (Go), Termux:Boot (Phone), Scheduled Task (PC). S9 FE and S10+ use **on-demand tunnels** (`s9up`/`s10up` on book5) to save battery.

**Pi1 @ Elevated**: Git backup mirror (15 repos) on **DietPi-Bookworm** (cutover from Raspbian 2026-05-12). On Tailscale at 100.98.16.63. Has a 3.5" SPI TFT with custom `hub` dashboard (Python + rich) at `/usr/local/bin/pi1-hub`. Updated weekly via the `push-all` skill, which pushes to GitHub + Gitea + Pi1 from Mac. Internet still requires PC (or Mac) to be on (Pi1 has no Wi-Fi, runs off the host's ICS), but Tailscale reachability is host-independent.

**Tailnet**: All homelab + roaming devices are on Tailscale **except VM101/ubuntu** (removed 2026-06-19 — Mullvad lockdown walls it off; reach via ProxyJump tower). Use the 100.x IP or hostname (MagicDNS) when ICS/LAN IPs are unstable. See `~/.claude/docs/homelab.md` for the full tailnet roster.

**Network Note**: Router migration (Feb 2026) moved from dual-subnet (192.168.2.x/192.168.1.x) to single 192.168.68.0/22. Both Proxmox nodes now on 2.5 GbE primary interfaces (vmbr1). vmbr0 exists on book5 but is inactive.

**DNS / ad-blocking (current state, 2026-06-21)**: Network DNS = pihole `192.168.68.248`, handed to all clients via **Deco app → DHCP Server → Primary DNS** (Secondary blank; IPv6 OFF). NOT the WAN/IPv4 DNS field — Deco rejects a LAN IP there. Pihole `.248` is static (sits inside DHCP pool `.50`–`71.250`). Spectrum modem is in **bridge mode** (Deco WAN = public IP, no double-NAT). If ads return network-wide, check that DHCP-Server Primary DNS field is still `.248` first — it blanked during the 2026-06-19 outage/modem swap (see changelog 2026-06-21 + brain `deco-dhcp-dns-pihole`). Tailscale MagicDNS (`100.100.100.100`) is transparent, forwards to DHCP DNS = pihole.

### Book5 Watchdog Services (contain hardcoded IPs — update if subnet changes)
- `/usr/local/bin/network-health-monitor.sh` — **v2.1** (2026-05-20): Graduated escalation with rate-limiting. Socket issues restart TW client only (never NM). NM restart only on true isolation (both internet AND peers down, 6+ consecutive failures). Now also probes DNS resolution (`check_dns`) — if DNS fails while inet+peers are OK, logs `action=dns_broken` (no auto-remediation). JSON state file at `/var/lib/network-health-monitor/state.json`. Logs: `journalctl -t net-health`. Backup of pre-2026-05-20 version at `/usr/local/bin/network-health-monitor.sh.bak-2026-05-20`
- **book5 DNS routing (2026-05-20)**: sdwan0 NM connection no longer points at Twingate's 100.95.0.x resolvers — overridden to pihole (`192.168.68.248`) via `nmcli connection modify sdwan0 ipv4.dns 192.168.68.248 ipv4.ignore-auto-dns yes`. Persisted in `/etc/NetworkManager/system-connections/sdwan0.nmconnection`. Reason: TW resolvers stopped answering while client reported `online`; book5 doesn't need TW-internal name resolution. **RECURRED 3x by 2026-05-27** (a TG update deletes+recreates sdwan0 with a fresh UUID and dead `100.95.0.x` resolvers; connector shows DEAD_HEARTBEAT_TOO_OLD while systemd says active because DNS is broken). **AUTO-REMEDIATION 2026-05-27**: NM dispatcher hook `/etc/NetworkManager/dispatcher.d/90-twingate-dns-pin` (root:root 0755) re-pins sdwan0 DNS→pihole + reapplies + restarts twingate-connector on every sdwan0 `up`/`dhcp4-change`, guarded so it no-ops once correct. Logs `journalctl -t twingate-dns-pin`. Manual fallback: `nmcli connection modify sdwan0 ipv4.dns 192.168.68.248 ipv4.ignore-auto-dns yes && nmcli device reapply sdwan0 && systemctl restart twingate-connector`. See changelog 2026-05-20 + 2026-05-27
- `/usr/local/bin/cpu-watchdog.sh` — Suspends first running VM if CPU >99% for 3 min
- `/etc/systemd/system/fix-vm101-route.service` — Overrides Twingate route to VM 101 (via tower on vmbr1)
- `rsyslog` (UDP 514) receives tower's full syslog → `/var/log/tower-remote.log`. Config: `/etc/rsyslog.d/10-receive-from-tower.conf`. Tail after a tower hang to see last messages before crash. Set up 2026-05-06.

### Tower Services (contain iptables rules — update if Docker or subnet changes)
- `/etc/systemd/system/fix-docker-forward.service` — Allows iptables FORWARD between book5 (192.168.68.250) and VM 101 (192.168.68.101). Required because Docker sets FORWARD policy DROP, blocking Twingate-routed cross-host traffic.

### Tower Crash Instrumentation (added 2026-05-06 — tower hanging silently every 1–3 days since the 2026-03-24 kernel upgrade to 6.17.13-2-pve)
- **Kernel pinned to `6.17.4-2-pve`** via `proxmox-boot-tool kernel pin 6.17.4-2-pve`. Hypothesis: 6.17.13 regression (likely VFIO/IOMMU on M4000 passthrough). If tower stays up >5 days, regression confirmed; unpin only after 6.17.14+ ships and is verified.
- `/etc/sysctl.d/99-tower-debug.conf` — `softlockup_panic=1`, `hardlockup_panic=1`, `panic=30` (auto-reboot 30s after panic), `panic_print=13`. Converts silent hangs into loud panics + auto-recovery.
- `/etc/rsyslog.d/30-forward-to-book5.conf` — forwards all syslog (incl. kernel via /dev/kmsg) to book5:514/UDP.
- `pstore` mounted at `/sys/fs/pstore` (in `/etc/fstab`). After a panic+reboot, panic info appears as `dmesg-*` files there.
- `lm-sensors` installed. Tower temps under load: cores ~45°C idle, NIC PHY ~60°C. Thresholds 92/120°C.
- Tower's NICs: vmbr0 = Intel I218-LM (e1000e, 1G), vmbr1 = Realtek RTL8125 (r8169, 2.5G, primary). **netconsole on the bridge does not work** — don't try; rsyslog forward is the working channel.

---

### In Progress
- 🔄 Second Proxmox node `prox-tower` arriving (192.168.2.249)
- 🔄 Cross-backup between Proxmox nodes planned

### Upcoming
- ⬜ Proxmox cluster or PBS backup setup
- ⬜ LLM workstation build

## Network Cheat Sheet

### Network: 192.168.2.0/24

| Device | IP | Hostname | Services |
|--------|-----|----------|----------|
| **Router** | 192.168.2.1 | — | Gateway (TP-Link) |
| **Proxmox Node 1** | 192.168.2.250 | prox-book5 | VMs, SSH, Twingate Client |
| **Proxmox Node 2** | 192.168.2.249 | prox-tower | (planned) |
| **Pi-hole Pi** | 192.168.2.131 | pi.hole | DNS :53, Pi-hole :80/443, MagicMirror :8080, Homarr :7575 |

### Proxmox VMs (on prox-book5)

| VMID | Name | IP | Status |
|------|------|-----|--------|
| 100 | omarchy-desktop | 192.168.2.161 | Running |
| 101 | ubuntu-desktop | — | Stopped |
| 102 | ubuntu-server | 192.168.2.126 | Running (Twingate connector in Docker) |

### Twingate Configuration

#### Remote Networks & Connectors

| Network | Connector Location | Purpose |
|---------|-------------------|---------|
| Home | VM 102 (ubuntu-server) | Primary home access |
| Home | Pi (192.168.2.131) | Redundant home access |
| Mac-Remote | Mac (Docker) | SSH into Mac from anywhere |
| Work | Work PC | Access to work resources |

#### Service Accounts

| Account | Location | Purpose | Expires |
|---------|----------|---------|---------|
| prox-book5-service | Proxmox (192.168.2.250) | Headless access to resources | Dec 1, 2026 |

Service key location: `/etc/twingate/service_key.json`

#### Key Resources

| Resource | Address | Alias | Network |
|----------|---------|-------|---------|
| mac-ssh | host.docker.internal:22 | mac-ssh.local | Mac-Remote |
| homeLab | 192.168.2.250 | — | Home |

**To SSH into Mac from anywhere:**
```bash
ssh joshuabrown@mac-ssh.local
```

## Quick Reference

### Key Commands
```bash
# Proxmox VM management
qm list                          # List all VMs
qm start 100                     # Start VM 100
qm stop 100                      # Stop VM 100
qm snapshot 100 snap-name        # Create snapshot
qm rollback 100 snap-name        # Rollback to snapshot

# Twingate (on Proxmox - headless mode)
twingate status                  # Check connection status
twingate resources               # List available resources

# Check GPU availability (once built)
nvidia-smi

# Monitor system resources
htop

# Check network connectivity
ip addr show
```

### Important Paths

**On Proxmox (prox-book5 @ 192.168.2.250):**
- Git repos: `~/repos/homeLab`, `~/repos/claudeGlobal`
- VM configs: `/etc/pve/qemu-server/`
- Twingate service key: `/etc/twingate/service_key.json`

**On Mac:**
- Projects: `~/projects/homeLab`
- Claude global config: `~/.claude/`

### SSH Access
```bash
# From Mac to Proxmox (via Twingate or local)
ssh root@192.168.2.250

# From Proxmox to Mac (via Twingate - works anywhere)
ssh joshuabrown@mac-ssh.local

# From Proxmox to VMs (local only)
ssh root@192.168.2.161    # omarchy-desktop
ssh root@192.168.2.126    # ubuntu-server
```

## Documentation Structure

**📚 Detailed Documentation**: See the `docs/` directory:

### Core Documents
- **[llm-homelab-research-2025.md](docs/llm-homelab-research-2025.md)** - Comprehensive hardware research
- **[build-plan.md](docs/build-plan.md)** - Build specifications and purchasing guide
- **[homelab-planning-guide.md](docs/homelab-planning-guide.md)** - Infrastructure planning

### Configuration Guides
- **[linux-os-comparison.md](docs/linux-os-comparison.md)** - OS selection analysis
- **[pihole-setup.md](docs/pihole-setup.md)** - Ad blocking DNS setup with DNS-over-TLS
- **[twingate-pihole-setup.md](docs/twingate-pihole-setup.md)** - Secure remote access, service accounts, Mac remote setup

### Meta Documentation
- **[changelog.md](docs/changelog.md)** - Complete version history
- **[Budget homeLab server.md](docs/Budget%20homeLab%20server.md)** - Budget analysis

## Hardware

### Current Infrastructure
- **Proxmox Node 1 (prox-book5)**: Laptop at 192.168.2.250
- **Proxmox Node 2 (prox-tower)**: Ordered from eBay, arriving soon (192.168.2.249)
- **Raspberry Pi**: Pi-hole, MagicMirror, Homarr, Twingate connector

### Planned Build: Budget-Conscious Starter ($2,200 total)

**LLM Workstation** ($1,350):
- GPU: Used RTX 3090 24GB ($650)
- CPU: AMD Ryzen 5 7600 ($200)
- RAM: 32GB DDR5 ($100)
- Storage: 1TB NVMe ($50)

**Server** ($700):
- Beelink SER7 Mini PC
- AMD Ryzen 7 7735HS
- 32GB RAM, 1TB NVMe

**Networking** ($150):
- 2.5GbE managed switch
- CAT6a cabling

## Version History

**Current Version**: v1.2.0
**Last Updated**: 2025-12-01

### Recent Changes
- v1.2.0 (2025-12-01): Renamed Proxmox to prox-book5, added service account docs, added prox-tower planning
- v1.1.0 (2025-12-01): Added network cheat sheet, Proxmox/Twingate setup docs
- v1.0.1 (2025-11-14): Initial documentation structure

**Full changelog**: [docs/changelog.md](docs/changelog.md)

---

*This documentation follows the lean structure pattern with detailed content in `docs/` subdirectory.*
