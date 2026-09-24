---
type: concept
title: Network Topology — the physical/logical homelab network
tags: [network, subnet, ip-scheme, archer, deco, router, vmbr1, 2.5gbe, migration]
related: [access-model, dns-adblocking, mullvad, book5, tower, pihole, vm101-ubuntu, vm111-homeassistant, vm100-omarchy]
---

# Network Topology

The physical + logical layout of the homelab: one flat `/22` subnet behind a GL.iNet
Flint 3 router (since 2026-09-23; Archer BE550 Pro v2 retired, the Deco BE63 is the Wi-Fi AP layer) in Spectrum bridge mode, a 2.5 GbE backbone between the two Proxmox nodes, and a
structured IP scheme. Reachability (SSH/Tailscale/Twingate) → [[access-model]]; DNS →
[[dns-adblocking]]; VPN egress → [[mullvad]].

> **This page describes the CURRENT flat network.** The plan to split it into trust-level
> VLANs (`work`/`iot`/`family`/`guest`), the GL.iNet Flint 3 gateway that replaces the Deco
> as router, and the wiring/AP constraints → [[network-segmentation]] (planned 2026-08-07,
> not yet built).

## Subnet + IP scheme

- **Subnet:** `192.168.68.0/22` — a single unified network (one flat L2/L3 domain).
- **IP scheme:** `250s` = Proxmox / infra · `100s` = VMs · `70s` = Cameras / IoT.
- **DHCP pool:** `192.168.69.0`–`192.168.71.254` (handed by the Flint 3).
- **Static space = `192.168.68.x`** — *outside* the DHCP pool. The router can never hand out a
  `.68.x` address, so **statics cannot collide with DHCP** and need no Address Reservation.
- **Statics are set PER-MACHINE (client-side), not at the router.** Each host pins its own
  `.68.x` in its own network stack (NM/nmcli, `ha network update`, ONVIF for the Tapo cams).
  There is no router-side reservation to check — if a `.68.x` host drifts, the fix is on the
  *host*, not the router.
- **Corollary — the drift signature:** any host left on DHCP (`ipv4.method: auto`) gets pulled
  into `.69`–`.71` and vanishes from its expected `.68.x`. That is a *host misconfig*, not a
  network fault. Seen on [[vm111-homeassistant]] 2026-07-16 (`.68.111` → `.71.49`).
- **Reservations** are only meaningful for hosts that intentionally live *in* the pool
  (e.g. [[mac]] at `.69.222`).

## Master device / IP table

Authoritative current-state (repo `CLAUDE.md`, 2026-06-18+). SSH/access column is a
one-line pointer — full reachability model is in [[access-model]].

| Resource | IP | Access / notes |
|----------|-----|----------------|
| **GL.iNet Flint 3 (GL-BE9300) router (gateway)** | 192.168.68.1 | Router + DHCP + NAT since **2026-09-23** (LAN MAC `94:83:C4:BE:39:02`, WAN `94:83:C4:BE:39:00`; admin panel http://192.168.68.1, ssh root — password file `~/.secrets/flint_admin` on the Pocket, 600, read with `sshpass -f`, never exported). The Deco BE63 ("Kitchen", MAC `8C:86:DD:E8:C2:EA`) is the Wi-Fi AP layer, not the gateway |
| Office switch (behind the router → book5, tower, pihole) | *(none)* | **Unmanaged** TP-Link 2.5G unit, MAC `10:5a:95:39:11:6f` — no IP, no LLDP/STP, only Realtek RRCP loop-detect broadcasts (checked from book5 2026-09-10, method in [[network-lab]]). Model to read off the label at the Flint cutover |
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
| [[pc]] (Windows PC) | 192.168.68.246 | `ssh pc` / `ssh pc-local`. Static 2026-08-06 (client-side netsh on `Wi-Fi 2`, `/22`, gw `.1`, DNS→pihole) — relocated to homeLab |
| WSL (Ubuntu on PC) | *(none — NAT)* | `ssh wsl` / `ssh wsl-local`. No LAN IP of its own; reached via [[pc]]'s host portproxy on `2222`, so it tracks `.246` |
| [[phone]] (S25 Ultra/Termux) | DHCP | `ssh s25` (mDNS) / `s25-{home,work,tunnel}` |
| [[s9-tablet]] (S9 FE) | 192.168.68.50 | `ssh s9` / `ssh s9-local` (on-demand tunnel) |
| [[s10]] (S10+) | 192.168.68.73 | `ssh s10` / `ssh s10-local` (on-demand tunnel) |
| [[pi1]] | 100.98.16.63 | `ssh pi1` (Tailscale). NOT on the LAN — sits on [[pc]]'s ICS subnet `192.168.137.77`. Moved to homeLab with [[pc]] 2026-08-06, so **no longer offsite** |
| Wife laptop | 192.168.68.59 | pihole full-**bypass** client (MAC `74:13:ea:0f:c1:6b`) — see [[dns-adblocking]] |

> Phones/tablets/IoT on `.52 .57 .62 .66 .67 .70 .71 .72` use **MAC randomization** —
> their IP + client name drift on reconnect, so they aren't reserved/named. Fixed-MAC infra
> gets stable reservations; full canonical name↔MAC map in `docs/deco-device-naming.md`.

### Historical / destroyed nodes

- **TP-Link AP (mesh node)** `192.168.71.250` — **DESTROYED 2026-06-19** (fried in the
  lightning/power surge; no LED, dead in person). Cameras `.75/.76` rerouted cleanly onto
  the primary AP. Replacement node TBD.
- **CT 102 "trans" (book5)** `192.168.68.65` — **DESTROYED 2026-06-19** (LXC deleted to
  free book5 resources — gone, not down). `trans` work runs ad-hoc now.
- **Samba** — RETIRED 2026-05-27 (smbd disabled on book5).

## Router (Flint 3) + modem bridge mode

**Router history:** Deco BE63 (router mode) until **2026-06-26** → **TP-Link Archer BE550 Pro v2**
(2026-06-26 → 2026-09-23; now retired/off, AP-mode candidate) → **GL.iNet Flint 3 (GL-BE9300), current since
2026-09-23** (cutover notes: `TODO.md` § Flint 3 router cutover; lab + VLAN plan: [[network-lab]]). When a doc
says "Deco app" or "Archer web UI" for a router setting, it is stale: the setting lives on the Flint (GL admin
panel at `http://192.168.68.1`, LuCI underneath, `uci` over ssh as root).

- **Router:** **GL.iNet Flint 3** (GL-BE9300, OpenWrt-based GL firmware 4.9.0, Wi-Fi 7) at `192.168.68.1`,
  LAN `/22`, DHCP pool `.69.1`–`.71.254` (12 h leases), DHCP option 6 = pihole `.248`, rebind protection OFF
  (so pihole's `.lab` answers pass), UPnP off, remote admin off, WAN input DROP, no DNS override. Static
  leases: macAir, PetCam/Porch/DoorCam `.68.75/.76/.77`, tower plug `.69.178`, plug2 `.71.103`, pi-gw1
  `.71.85`, Windows box `.70.239`. SSIDs **Spaceballs** (2.4/5/6 GHz) + **Spaceballs_MLO** (MLO, all bands),
  house key. Config backups: Pocket `~/backups/flint/` + book5 `/root/network-lab/`.
- **Gotcha — working on the Flint from a cable while Tailscale accepts routes:** pi-gw1 advertises
  `192.168.68.0/22`, and Tailscale's table 52 beats the cable, so `.68.1` silently lands on whatever router
  is live in the house. `sudo tailscale set --accept-routes=false` first (found 2026-09-23).
- **Gotcha — after any WAN outage, pihole SERVFAILs the busy names** (google, apple push) for up to 15 min:
  unbound's infra cache marked their nameservers down while the WAN was gone. Fix: `sudo unbound-control
  flush_infra all` on pihole (or wait). Also in [[dns-adblocking]].
- **Modem:** Spectrum modem is in **bridge mode** → the Flint's WAN (`eth0`, DHCP) gets the public IP,
  **no double-NAT**. Power-cycle the modem when the router changes (it binds to the first MAC it sees).
- **Deco BE63 (AP layer):** the surviving unit (the 2nd was destroyed in the 2026-06-19 surge)
  provides Wi-Fi under the Archer; Deco-app settings are cosmetic/AP-only now.

<details><summary>Deco-era notes (router until 2026-06-26)</summary>

- **DHCP:** The Deco BE63 **cannot disable its DHCP server while in router mode**
  (firmware product decision, not a hidden toggle — TP-Link: *"no intention to disable
  DHCP under wireless router mode"*). Moving DHCP to pihole/OPNsense would require demoting
  the Deco to **Access Point mode**. Until then, control in router mode = **Address
  Reservation** (stable per-MAC IPs) + **pihole Local DNS Records** (`.lab` names).
- **Client naming:** Deco stores client nicknames in the TP-Link cloud (per-MAC), **not**
  on the AP hardware — a re-onboard (e.g. after the surge) wipes custom names back to
  `Computer_XXXX` defaults (auto-name = last 4 hex of the MAC). Recovery sheet +
  canonical name/MAC map: `docs/deco-device-naming.md`. Cloud Auto Backup now ON (2026-06-23).

</details>

> DNS handed to clients via **Flint 3 (GL.iNet admin panel → Network → LAN → DHCP, or `uci get dhcp.lan.dhcp_option` = `6,192.168.68.248`)**
> (pihole), NOT the router's own upstream-DNS setting. Full DNS chain,
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

## Rebuild 2026 (Archer BE550 + wired Deco APs)

**Status: Archer swap DONE 2026-06-26; Flint 3 swap DONE 2026-09-23** (Archer retired). Cabling, AP
demotion of the Deco/Archer, and VLANs still open in `TODO.md`; the lab track is [[network-lab]]. Spurred by
the 2026-06-19 lightning strike. Direction: a **TP-Link Archer BE550** becomes the router/brain
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
