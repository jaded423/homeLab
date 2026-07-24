---
type: index
title: homeLab wiki — index
tags: [index, catalog, homelab]
related: [network-topology, access-model]
---

# homeLab wiki — index

Catalog of the home-lab knowledge base: a two-node Proxmox cluster (book5 + tower),
their VMs, the roaming device fleet, and the cross-cutting systems (network, access,
DNS, VPN, watchdogs) that tie them together. **Authoritative current-state** — the old
per-node docs in `~/.claude/docs/homelab/` were folded in here (2026-07-06).

> **Start with [[network-topology]]** for the map (subnet, IP scheme, device table),
> then [[access-model]] for how to reach anything, then drill into a host or concept.

> **How to read this wiki:** every page has YAML frontmatter (`type`, `title`, `tags`,
> `related`; host pages add `host`/`ip`). Body links use `[[page-slug]]`. Point Obsidian
> at this `wiki/` dir for the graph view. Conventions in the repo `CLAUDE.md`.

## Components — hosts (one per machine)

### Proxmox nodes + their VMs

| Page | Host | IP | Role |
|---|---|---|---|
| [[book5]] | `book5` | 192.168.68.250 | Proxmox node 1 (laptop). Hosts [[vm100-omarchy]]. Watchdogs, Homelable CT103, Twingate connector. |
| [[tower]] | `tower` | 192.168.68.249 | Proxmox node 2. Hosts [[vm101-ubuntu]] + [[vm111-homeassistant]]. M4000 GPU, crash-instrumented, 2.5G vmbr1. |
| [[vm100-omarchy]] | `omarchy` | 192.168.68.100 | VM 100 — Arch/Omarchy desktop. n8n, Sunshine game-stream. iGPU passthrough. |
| [[vm101-ubuntu]] | `ubuntu` | 192.168.68.101 | VM 101 — media + services box. Plex/Jellyfin/Ollama/Frigate/qBit/steam-headless/whisper. Mullvad. |
| [[vm111-homeassistant]] | `ha` | 192.168.68.111 | VM 111 — Home Assistant OS. Hubspace + Frigate + MQTT. |
| [[pihole]] | `pihole` | 192.168.68.248 | magic-pihole — network DNS + ad-block (Raspberry Pi). |

### Roaming / edge devices

| Page | Host | IP | Role |
|---|---|---|---|
| [[pi1]] | `pi1` | 100.98.16.63 | Git backup mirror @ Elevated office (DietPi + `hub` TFT dashboard). |
| [[mac]] | `mac` | 192.168.69.222 | Joshua's Mac — staging/dev + roaming node. |
| [[go]] | `go` | 192.168.68.247 | Pixelbook Go (CachyOS dual-kernel). |
| [[pc]] | `pc` / `wsl` | n/a | Windows PC + WSL = the Elevated **production** machine. |
| [[phone]] | `s25` | n/a | Samsung S25 Ultra (Termux/proot). |
| [[s9-tablet]] | `s9` | 192.168.68.50 | Samsung Tab S9 FE (on-demand tunnel). |
| [[s10]] | `s10` | 192.168.68.73 | Samsung S10+ (on-demand tunnel). |

## Concepts — cross-cutting systems

| Page | What |
|---|---|
| [[network-topology]] | Subnet 192.168.68.0/22, IP scheme, device table, Deco mesh + bridge mode, 2.5G vmbr1, Feb-2026 migration. |
| [[access-model]] | Tailscale-primary / Twingate-media split, `device` vs `device-local` aliases, ProxyJump map, MagicDNS web UIs, reverse-tunnel roaming. |
| [[dns-adblocking]] | pihole `.248` via Deco DHCP DNS, the "ads returned?" gotcha, sdwan0 pin auto-remediation, bypass group. |
| [[mullvad]] | VM101 hop-swappable exit (STO single-hop ↔ US-Dallas multihop for games), lockdown-always-on. |
| [[watchdogs]] | book5 net-health/cpu watchdogs, tower crash instrumentation + kernel pin, VM101 Frigate autoheal. |
| [[storage]] | VM101 media tiers, 3.2T NFS pool, scan-and-move pipeline, Google Drive integration. |
| [[gpu-passthrough]] | M4000 → VM101, Intel Arc iGPU → VM100; Maxwell-EOL NVENC wall. |
| [[vaultbot]] | Secret-broker design thought-experiment: attestation vs bearer-hash, device binding, LLM-as-approver landmine, floors/ceilings of the Mac-single-point-of-failure threat model. |
| [[troubleshooting]] | Recurring problems + fixes + setup recipes not owned by one host. |
| [[history]] | Origin, pre-migration 192.168.2.x topology (archaeology), hardware/budget, version history. |

## Meta

- [[log]] — chronological wiki-evolution log.
- **Code / current-state paper-trail:** [`../docs/changelog.md`](../docs/changelog.md).
- **Planning / reference docs** (deep, kept as long-form): [`../docs/`](../docs/) —
  `build-plan.md`, `llm-homelab-research-2025.md`, `homelab-planning-guide.md`,
  `proxmox-ceph-cluster-guide.md`, `pihole-setup.md`, `twingate-pihole-setup.md`, etc.
- **Runbook skill:** `homelab-host-recovery` (downed host) · `homelab-net-check` (reachability).
- **Searchable facts:** `brain` MCP (`project=homeLab`) — the cross-session recall layer.
