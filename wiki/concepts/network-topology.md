---
type: concept
title: Network Topology — the physical/logical homelab network
tags: [network, subnet, ip-scheme, deco, router, vmbr1, 2.5gbe, migration]
related: [access-model, dns-adblocking, mullvad, book5, tower, pihole, vm101-ubuntu, vm111-homeassistant, vm100-omarchy]
---

# Network Topology

The physical + logical layout of the homelab: one flat `/22` subnet behind a Deco
router in Spectrum bridge mode, a 2.5 GbE backbone between the two Proxmox nodes, and a
structured IP scheme. Reachability (SSH/Tailscale/Twingate) → [[access-model]]; DNS →
[[dns-adblocking]]; VPN egress → [[mullvad]].

## Subnet + IP scheme

- **Subnet:** `192.168.68.0/22` — a single unified network (one flat L2/L3 domain).
- **IP scheme:** `250s` = Proxmox / infra · `100s` = VMs · `70s` = Cameras / IoT.
- **DHCP pool:** `.50`–`71.250` (handed by the Deco). Infra hosts (`.248`–`.250`) sit
  inside the pool but are pinned via **Address Reservation** so they never drift — pihole
  `.248` especially, or DNS vanishes network-wide.

## Master device / IP table

Authoritative current-state (repo `CLAUDE.md`, 2026-06-18+). SSH/access column is a
one-line pointer — full reachability model is in [[access-model]].

| Resource | IP | Access / notes |
|----------|-----|----------------|
| Deco main router (gateway) | 192.168.68.1 | BE63, unit named "Kitchen", MAC `8C:86:DD:E8:C2:EA`. Gateway + DHCP + NAT |
| [[book5]] (prox-book5) | 192.168.68.250 | `ssh book5`. Proxmox node 1 |
| [[tower]] (prox-tower) | 192.168.68.249 | `ssh tower`. Proxmox node 2 |
| [[pihole]] (magic-pihole) | 192.168.68.248 | `ssh pihole`. Network DNS — [[dns-adblocking]]. Static (in pool) |
| [[vm100-omarchy]] (VM 100) | 192.168.68.100 | `ssh omarchy` (Tailscale direct) |
| [[vm101-ubuntu]] (VM 101) | 192.168.68.101 | `ssh ubuntu` (ProxyJump tower — [[mullvad]] lockdown) |
| [[vm111-homeassistant]] (VM 111) | 192.168.68.111 | HAOS VM on tower. `ha` ProxyJumps tower |
| Homelable (CT 103) | 192.168.68.61 | UI `:3000` (admin/admin), MCP `:8001`. Native on book5/vmbr1, scans `192.168.68.0/22` |
| PetCam (Tapo) | 192.168.68.75 | Camera → Frigate on VM 101 |
| Porch (Tapo) | 192.168.68.76 | Camera → Frigate on VM 101 |
| [[mac]] | 192.168.69.222 | `ssh mac` / `ssh mac-local`. DHCP reservation → hardware MAC `2C:CA:16:05:C8:72` (in-pool .69–.71); roams elsewhere |
| [[go]] (Pixelbook Go) | 192.168.68.247 | `ssh go` / `ssh go-local`. Static 2026-06-28 (client-side NM, `/22`, gw `.1`, DNS→pihole) |
| [[pc]] (Windows PC) | DHCP | `ssh pc` / `ssh pc-local` |
| WSL (Ubuntu on PC) | DHCP | `ssh wsl` / `ssh wsl-local` |
| [[phone]] (S25 Ultra/Termux) | DHCP | `ssh s25` (mDNS) / `s25-{home,work,tunnel}` |
| [[s9-tablet]] (S9 FE) | 192.168.68.50 | `ssh s9` / `ssh s9-local` (on-demand tunnel) |
| [[s10]] (S10+) | 192.168.68.73 | `ssh s10` / `ssh s10-local` (on-demand tunnel) |
| [[pi1]] (@ Elevated, offsite) | 100.98.16.63 | `ssh pi1` (Tailscale). NOT on home LAN |
| Wife laptop | 192.168.68.59 | pihole full-**bypass** client (MAC `74:13:ea:0f:c1:6b`) — see [[dns-adblocking]] |

> Phones/tablets/IoT on `.52 .57 .62 .66 .67 .70 .71 .72` use **MAC randomization** —
> their IP + Deco name drift on reconnect, so they aren't reserved/named. Fixed-MAC infra
> gets stable reservations; full canonical name↔MAC map in `docs/deco-device-naming.md`.

### Historical / destroyed nodes

- **TP-Link AP (mesh node)** `192.168.71.250` — **DESTROYED 2026-06-19** (fried in the
  lightning/power surge; no LED, dead in person). Cameras `.75/.76` rerouted cleanly onto
  the primary AP. Replacement node TBD.
- **CT 102 "trans" (book5)** `192.168.68.65` — **DESTROYED 2026-06-19** (LXC deleted to
  free book5 resources — gone, not down). `trans` work runs ad-hoc now.
- **Samba** — RETIRED 2026-05-27 (smbd disabled on book5).

## Router (Deco) + modem bridge mode

- **Router:** TP-Link **Deco BE63** (Wi-Fi 7) in **Wi-Fi Router mode** at `192.168.68.1`.
  Currently a **single unit** — the 2nd AP (mesh satellite) was destroyed in the 2026-06-19
  surge and not yet replaced. Firmware 1.3.2, Deco app v3.10.215 (as of 2026-06-23).
- **Modem:** Spectrum modem is in **bridge mode** → Deco WAN gets the public IP, **no
  double-NAT**.
- **DHCP:** The Deco BE63 **cannot disable its DHCP server while in router mode**
  (firmware product decision, not a hidden toggle — TP-Link: *"no intention to disable
  DHCP under wireless router mode"*). Moving DHCP to pihole/OPNsense would require demoting
  the Deco to **Access Point mode**. Until then, control in router mode = **Address
  Reservation** (stable per-MAC IPs) + **pihole Local DNS Records** (`.lab` names).
- **Client naming:** Deco stores client nicknames in the TP-Link cloud (per-MAC), **not**
  on the AP hardware — a re-onboard (e.g. after the surge) wipes custom names back to
  `Computer_XXXX` defaults (auto-name = last 4 hex of the MAC). Recovery sheet +
  canonical name/MAC map: `docs/deco-device-naming.md`. Cloud Auto Backup now ON (2026-06-23).

> DNS handed to clients via **Deco app → DHCP Server → Primary DNS = `192.168.68.248`**
> (pihole), NOT the WAN/IPv4 DNS field (Deco rejects a LAN IP there). Full DNS chain,
> Mullvad-config edits, and the "ads returned" checklist → [[dns-adblocking]].

## 2.5 GbE `vmbr1` backbone

Both Proxmox nodes run their **primary interfaces on 2.5 GbE (`vmbr1`)**:

- **[[book5]]:** `vmbr1` = 2.5 GbE primary. `vmbr0` exists but is **inactive**.
- **[[tower]]:** `vmbr1` = Realtek RTL8125 (`r8169`, 2.5 G, primary). `vmbr0` = Intel
  I218-LM (`e1000e`, 1 G).

**2026-06-19 VM tap merge:** during the post-outage cable reroute, tower's VM taps got
stranded on the stock 1 G `vmbr0` / no-bridge — VM 101 had silently been on 1 GbE the
whole time. Both **VM 101 + VM 111** were merged onto the 2.5 G `vmbr1`. Side effect:
~25% throughput gain, and [[mullvad]] single-hop rose to ~1.18 Gbps (was ~950 Mbps
capped on 1 G).

> ⚠️ **tap-master gotcha:** the fix (`ip link set tapNi0 master vmbr1`) is **runtime-only**.
> VM `net0` configs already point at `vmbr1`, so a clean boot *should* reattach — but they
> stranded once. **Verify tap masters after any tower reboot / power event:**
> `bridge link show | grep tap`.

## Feb-2026 migration: dual-subnet → `/22`

The **Feb 2026 router migration** consolidated the network from a **dual-subnet layout
(`192.168.2.x` / `192.168.1.x`)** to the single **`192.168.68.0/22`**. As part of it,
both Proxmox nodes moved to their 2.5 GbE primary interfaces (`vmbr1`).

> NOTE: the older `192.168.2.x` "Network Cheat Sheet" in the repo `CLAUDE.md` is
> **pre-migration historical** — ignore it for current state. This `/22` layout is
> authoritative.

## Planned rebuild (Archer BE550 + wired Deco APs)

**Status: PLANNED** (cabling started weekend of 2026-06-27; spurred by the 2026-06-19
lightning strike). Direction: a **TP-Link Archer BE550** becomes the router/brain
(config-as-code, real DHCP, port-forward, VPN control — escaping the Deco app's no-API
limitation), with the **2× Deco BE63 demoted to Access Point mode** on **true wired
backhaul** (no wireless mesh hop). Office becomes a wired island after the coax is
relocated there. Full BOM + cabling plan + phasing: `docs/network-rebuild-2026.md`.

- Archer = 1× 10 G WAN in, 4× 2.5 G LAN out (all confirmed 2.5 G → backhauls go direct,
  no office switch needed). 10 G WAN is headroom until ISP > 2.5 G.
- Decos in **AP mode** = wired access points only (they mesh **Deco-to-Deco**, never to a
  non-Deco router — the gotcha that started the redesign). Two apps, no integration:
  Tether (Archer) + Deco app (AP layer).
- Post-lightning hardening: whole-house **panel surge protector** (the real fix for the
  multi-circuit losses) + coax surge protector / re-grounded entry.

## Sources

- `~/projects/homeLab/CLAUDE.md` (Operational Current State, lines 45–119 — authoritative)
- `~/projects/homeLab/docs/network-rebuild-2026.md`
- `~/.claude/docs/homelab/deco-vpn-setup.md` (topology bits; DNS → [[dns-adblocking]])
- `~/projects/homeLab/docs/deco-device-naming.md`
