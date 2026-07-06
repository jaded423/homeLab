---
type: component
title: mac (Joshua's MacBook Air)
tags: [mac, roaming, staging, control-point]
related: [access-model, go, pc, phone, s9-tablet, s10, network-topology]
host: mac
ip: 192.168.69.222
---

# mac

Joshua's MacBook Air M2 — the **homelab control point** and **staging/dev machine**
(Mac = STAGING; WSL/[[pc]] = PRODUCTION). Also a **roaming device**: reachable from any
network via Tailscale + a reverse SSH tunnel to [[book5]].

**Access:** `ssh mac` (Tailscale, anywhere) / `ssh mac-local` (LAN direct). Older docs
had this on `.247` — that's [[go]] now.

## As a homelab node

| Property | Value |
|----------|-------|
| Device | MacBook Air M2 (2022), 16 GB, 512 GB |
| Primary IP | 192.168.69.222 (Archer DHCP reservation) |
| SSH | `ssh mac` (Tailscale) / `ssh mac-local` (LAN) |
| Role | Homelab control point; Mac=staging for the Mac↔WSL deploy split |

Mac is where homelab docs and automation are authored (source of truth for the docs);
other machines carry read-only pointers. It rides the tailnet like every other homelab
node — reach any host by bare alias (`ssh book5`, `ssh tower`, `ssh ubuntu`…). Full SSH
topology in [[access-model]].

## DHCP reservation + MAC caveat

IP `192.168.69.222` is **reserved 2026-06-28** via an Archer DHCP reservation bound to
the Mac's **hardware MAC `2C:CA:16:05:C8:72`**. It's an in-pool reservation (the `.69`–`.71`
range); the Mac roams on plain DHCP on any other network.

> ⚠️ **Private Wi-Fi Address must stay OFF for the Spaceballs SSID.** macOS's rotating
> per-network MAC ("Private Wi-Fi Address") would present a MAC other than
> `2C:CA:16:05:C8:72`, breaking the reservation and bouncing the Mac to a random
> in-pool IP. Toggle: Wi-Fi → Spaceballs → Details → Private Wi-Fi Address = Off.

## Reverse SSH tunnel (roaming)

As a **roaming device**, the Mac maintains a persistent reverse SSH tunnel back to
[[book5]] so it's reachable from any network even when Tailscale/LAN IPs are unstable.

- **Persistence mechanism:** a macOS **LaunchAgent** (Mac's equivalent of [[go]]'s
  systemd unit, [[phone]]'s Termux:Boot, [[pc]]'s Scheduled Task).
- Peer roaming devices with their own tunnels/on-demand tunnels: [[go]], [[pc]],
  [[phone]], [[s9-tablet]], [[s10]].
- The reverse-tunnel roaming pattern (who tunnels how, on-demand vs. always-on) is
  owned by [[access-model]].

## Sources

- `~/.claude/docs/homelab/mac.md` (deep doc — hardware, dev-env, SSH config)
- `~/projects/homeLab/CLAUDE.md` "Operational Current State" (line 66 Mac row, Roaming Devices) — authoritative for IP/MAC/reservation
