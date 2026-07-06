---
type: concept
title: Access model — reaching every homelab host
tags: [ssh, tailscale, twingate, proxyjump, magicdns, tunnels, reachability]
related: [network-topology, dns-adblocking, mullvad, book5, tower, vm101-ubuntu]
---

# Access model

How you reach every homelab host. The model is **Tailscale-primary** (bare SSH alias
works anywhere on the tailnet via MagicDNS) with **Twingate scoped to media/LAN-only
resources**, plus ProxyJump for the one VM that Mullvad walls off and reverse tunnels
for roaming devices.

## Unified SSH pattern (INVERTED 2026-05-27)

The whole convention flipped on 2026-05-27 — **bare alias = Tailscale**, not LAN.

| Alias form | Path | Works from |
|---|---|---|
| `ssh device` | **Tailscale** (primary, via MagicDNS) | anywhere on the tailnet |
| `ssh device-local` | LAN direct | same network only |

Twingate's SSH path was removed — Tailscale reaches every homelab host. The book5
reverse tunnels for `pc`/`wsl`/`go` were dropped (they're on Tailscale now).

- Backup of the pre-inversion config: `~/.ssh/config.bak-2026-05-27`.

## Host access map

| Host | IP | Access |
|---|---|---|
| [[book5]] (prox-book5) | 192.168.68.250 | `ssh book5` (TS) / `ssh book5-local` |
| [[tower]] (prox-tower) | 192.168.68.249 | `ssh tower` (TS) / `ssh tower-local` |
| [[vm100-omarchy]] (VM 100) | 192.168.68.100 | `ssh omarchy` — **Tailscale direct** (own tailnet IP) |
| [[vm101-ubuntu]] (VM 101) | 192.168.68.101 | `ssh ubuntu` — **ProxyJump [[tower]]** (Mullvad, see below) |
| [[vm111-homeassistant]] (`ha`) | — | `ssh ha` — **ProxyJump [[tower]]** |
| [[pihole]] (magic-pihole) | 192.168.68.248 | `ssh pihole` (TS) |
| [[pi1]] @ Elevated | 100.98.16.63 | `ssh pi1` (Tailscale, stable regardless of host's ICS) |
| [[mac]] | 192.168.69.222 | `ssh mac` / `ssh mac-local` |
| [[go]] (Pixelbook Go) | 192.168.68.247 | `ssh go` (TS) / `ssh go-local` |
| [[pc]] (Windows) | — | `ssh pc` / `ssh pc-local` |
| WSL Ubuntu | — | `ssh wsl` / `ssh wsl-local` |
| [[phone]] (S25 Ultra/Termux) | — | `ssh s25` (mDNS) / `ssh s25-{home,work,tunnel}` |
| [[s9-tablet]] (S9 FE) | 192.168.68.50 | `ssh s9` / `ssh s9-local` (on-demand tunnel) |
| [[s10]] (S10+) | 192.168.68.73 | `ssh s10` / `ssh s10-local` (on-demand tunnel) |

## VM ProxyJump

Only the Mullvad-locked VM still needs a jump host now; the jumps ride Tailscale
(`tower` bare alias = TS).

- `omarchy` — reachable **direct** over Tailscale (own tailnet IP). ProxyJump **dropped**.
- `ubuntu` / VM 101 — **still ProxyJumps [[tower]]**. Mullvad lockdown blocks the tailnet
  on this box, so there's no direct path. → why: [[mullvad]].
- `ha` (VM 111) — **ProxyJumps [[tower]]**.

> **Tailscale removed from VM 101 entirely (2026-06-19)** — daemon purged + node deleted
> from the tailnet. Mullvad lockdown blocked it reaching the coordination server (always
> showed offline), and access was never via Tailscale anyway. Access path is **unchanged**:
> `ssh ubuntu` → ProxyJump [[tower]] (or Twingate). See changelog 2026-06-19.

## Web UIs (Tailscale MagicDNS, no aliases)

| URL | Service |
|---|---|
| `https://prox-book5:8006` | Proxmox ([[book5]]) |
| `https://prox-tower:8006` | Proxmox ([[tower]]) |
| `:9090` | Cockpit |
| `http://pihole/admin/` | Pi-hole admin ([[pihole]]) |
| `http://omarchy:5678` | n8n ([[vm100-omarchy]]) |
| `https://omarchy:47990` | Sunshine ([[vm100-omarchy]]) |

VM 101 apps + the Home Assistant web UI stay on **Twingate** (Mullvad / LAN-only).

MagicDNS name resolution behavior → [[dns-adblocking]] (Tailscale `100.100.100.100` is
transparent, forwards to DHCP DNS = pihole).

## Twingate (scoped to media / LAN-only)

Twingate is the `jaded423` network. Since the 2026-05-27 SSH inversion it is **no longer
the SSH path** — it now only carries the resources Tailscale can't reach cleanly: the
**VM 101 media/app stack** (Plex, Jellyfin, Frigate, qBittorrent, etc.) and the **HA web
UI**, all of which are Mullvad-locked or LAN-only on [[vm101-ubuntu]]. See [[mullvad]] for
why VM 101 is walled off, and [[network-topology]] for the connector placement.

## Roaming devices — reverse tunnels

Roaming devices ([[mac]], [[go]], [[phone]], [[pc]], [[s9-tablet]], [[s10]]) maintain
**reverse SSH tunnels to [[book5]]** for cross-device access from any network. book5 stays
the hub/entry point for these tunnels even though the desktop→server SSH path moved to
Tailscale.

| Device | Tunnel persistence |
|---|---|
| [[mac]] | LaunchAgent |
| [[go]] | systemd |
| [[phone]] | Termux:Boot |
| [[pc]] | Scheduled Task |
| [[s9-tablet]] / [[s10]] | **on-demand** (`s9up` / `s10up` on book5 — saves battery) |

The S9 FE and S10+ don't hold a tunnel open; you bring it up on demand by running `s9up`
/ `s10up` on book5, then reach the tablet via `ssh s9` / `ssh s10`.

## Pi1 reachability note

[[pi1]] (Git backup mirror at Elevated) is on Tailscale at `100.98.16.63`. Its **internet
still requires the work PC (or Mac) to be on** — Pi1 has no Wi-Fi and runs off the host's
ICS — but **Tailscale reachability is host-independent**: `ssh pi1` works regardless of
which host is providing the ICS.

## Tailnet roster

All homelab + roaming devices are on Tailscale **except VM 101 / ubuntu** (removed
2026-06-19 — Mullvad lockdown walls it off; reach via ProxyJump [[tower]]). Use the 100.x
IP or the MagicDNS hostname when ICS/LAN IPs are unstable. Full tailnet roster:
`~/.claude/docs/homelab.md`.

## Config backup

- Pre-inversion SSH config: `~/.ssh/config.bak-2026-05-27`.

## Future: Twingate SSH Privileged Access (not scheduled)

A captured-but-unscheduled plan (2026-05-11) would move the **desktop → homelab
servers/VMs** SSH path onto a Twingate Gateway issuing short-lived certs, retiring
ProxyJump for `omarchy`/`ubuntu` and per-host key management. It would **not** touch
Termux (`s25`/`s9`/`s10` — no Android client), the roaming reverse-tunnel architecture,
or `ssh pi1` (reached via the work PC, outside Twingate). Realistic outcome = hybrid:
Privileged Access for desktop→server, current setup retained everywhere else. Revisit
triggers: a second SSH user, a Twingate Android client, an audit/session-recording
requirement, or SSH-key sprawl becoming a maintenance burden. Full plan:
`docs/twingate-ssh-privileged-access-cutover.md`.

## Sources

- `~/projects/homeLab/CLAUDE.md` lines 45–119 (Operational Current State, authoritative)
- `~/projects/homeLab/docs/twingate-ssh-privileged-access-cutover.md`
