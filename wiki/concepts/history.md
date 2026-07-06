---
type: concept
title: History — Origin, Pre-Migration State & Hardware Lineage
tags: [history, origin, planning, hardware, budget, archive, 192.168.2.x]
related: [network-topology, index]
---

> **HISTORICAL / REFERENCE ONLY.** This page preserves the homelab's origin story, the
> original planning/budget, and the **pre-migration 192.168.2.x network** for archaeology.
> None of the IPs, VM IDs, or Twingate config below reflect current state. For the live
> network see [[network-topology]]; for current access see the Operational Current State in
> the repo `CLAUDE.md`.

## Origin & Goals

The project began as research + planning for an affordable-but-powerful home lab to run
local LLMs at medium context sizes (~100k tokens).

**Project Type**: Infrastructure / Hardware Research
**Original Budget**: $2,200 (Budget-Conscious Starter Build)

Original goals:

1. **Server Component** — reliable server infrastructure for hosting services.
2. **LLM Workstation** — a machine capable of running local LLMs with medium context (~100k tokens).
3. **Budget-Friendly** — maximize performance within reasonable cost constraints.
4. **Well-Integrated** — components that work well together with room for growth.

### Milestones (as recorded during buildout)

- Proxmox installed and running on the laptop — `prox-book5`.
- 3 VMs configured (omarchy-desktop, ubuntu-desktop, ubuntu-server).
- Pi-hole DNS running on a Raspberry Pi.
- Twingate zero-trust networking configured, incl. a service account for headless access.
- Git repos cloned to Proxmox (`~/repos/`).
- SSH access to Mac via Twingate (worked from any network).
- Homelable topology visualizer deployed (CT 103).
- Home Assistant OS on tower VM 111 (Hubspace + Frigate + MQTT).
- **Tailscale promoted to primary access layer (2026-05-27)** — bare SSH aliases became
  Tailscale, Twingate scoped down to media/HA. This is the pivot point after which the
  current-state docs take over → [[network-topology]].

## HISTORICAL Network — 192.168.2.0/24 (SUPERSEDED)

> The homelab has since migrated to `192.168.68.0/22`. The tables below are the **old**
> `192.168.2.x` scheme, kept only for archaeology. **Do not use these IPs.** Current
> addressing → [[network-topology]].

### Network: 192.168.2.0/24

| Device | IP | Hostname | Services |
|--------|-----|----------|----------|
| **Router** | 192.168.2.1 | — | Gateway (TP-Link) |
| **Proxmox Node 1** | 192.168.2.250 | prox-book5 | VMs, SSH, Twingate Client |
| **Proxmox Node 2** | 192.168.2.249 | prox-tower | (planned) |
| **Pi-hole Pi** | 192.168.2.131 | pi.hole | DNS :53, Pi-hole :80/443, MagicMirror :8080, Homarr :7575 |

### Proxmox VMs (on prox-book5) — historical IDs/IPs

| VMID | Name | IP | Status |
|------|------|-----|--------|
| 100 | omarchy-desktop | 192.168.2.161 | Running |
| 101 | ubuntu-desktop | — | Stopped |
| 102 | ubuntu-server | 192.168.2.126 | Running (Twingate connector in Docker) |

### Twingate Configuration (historical)

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

Service key location (historical): `/etc/twingate/service_key.json`

#### Key Resources

| Resource | Address | Alias | Network |
|----------|---------|-------|---------|
| mac-ssh | host.docker.internal:22 | mac-ssh.local | Mac-Remote |
| homeLab | 192.168.2.250 | — | Home |

To SSH into Mac from anywhere (historical):
```bash
ssh joshuabrown@mac-ssh.local
```

> **NOTE:** The Twingate access model has since been reworked — Tailscale is now primary and
> Twingate is scoped to media/HA (27→12 resources, 2026-05-27). See [[network-topology]] and
> the current-state access docs; treat everything above as archived.

## Hardware & Budget (as planned)

### Infrastructure at planning time

- **Proxmox Node 1 (prox-book5)**: laptop at 192.168.2.250.
- **Proxmox Node 2 (prox-tower)**: ordered from eBay, arriving (192.168.2.249).
- **Raspberry Pi**: Pi-hole, MagicMirror, Homarr, Twingate connector.

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

### Planned next steps (at the time)

- 🔄 Second Proxmox node `prox-tower` arriving (192.168.2.249)
- 🔄 Cross-backup between Proxmox nodes planned
- ⬜ Proxmox cluster or PBS backup setup
- ⬜ LLM workstation build

## Planning Docs (depth)

The original research and planning live in the repo `docs/` directory:

- `../docs/build-plan.md` — build specifications and purchasing guide
- `../docs/llm-homelab-research-2025.md` — comprehensive hardware research
- `../docs/homelab-planning-guide.md` — infrastructure planning
- `../docs/expansion-plans.md` — expansion planning
  *(may still live under `~/.claude/docs/homelab/` at build time — it is being moved into the repo `docs/`; link the repo path)*

## Version History (v1.x era)

**Version at freeze**: v1.2.0 — Last Updated: 2025-12-01

- **v1.2.0** (2025-12-01): Renamed Proxmox to prox-book5, added service account docs, added prox-tower planning.
- **v1.1.0** (2025-12-01): Added network cheat sheet, Proxmox/Twingate setup docs.
- **v1.0.1** (2025-11-14): Initial documentation structure.

Full ongoing history → `../docs/changelog.md`.

## Sources

- `~/projects/homeLab/CLAUDE.md` (lines 12–43, 122–285) — overview, goals, historical
  192.168.2.x network cheat sheet, original Twingate config, Budget-Conscious Starter build,
  hardware list, version history v1.0–v1.2.
