# Deco Device Naming — Recovery Sheet

**Why this file exists:** TP-Link Deco stores client nicknames in the TP-Link
cloud account (per-MAC), **not** on the AP hardware. A re-onboard (e.g. after the
2026-06-19 power outage that bricked one of the two APs) wiped all custom names
back to `Computer_XXXX` defaults — likely because cloud **Auto Backup was OFF**
at the time. This git-tracked sheet is the belt-and-suspenders backup; re-apply
names from here if the cloud restore ever falls short.

## Deco hardware (as of 2026-06-23)

- **Model:** Deco **BE63** (Wi-Fi 7). Main unit named **"Kitchen"**.
- **Main MAC / gateway:** `8C:86:DD:E8:C2:EA` = `192.168.68.1`.
- **Firmware:** 1.3.2 Build 26040912 Rel.40631. **Deco app:** v3.10.215.
- **Topology:** currently **single unit** — the 2nd AP (mesh satellite) was
  destroyed in the 2026-06-19 surge; not yet replaced.

## Native config backup (cloud)

BE63 has **System → Backup → Configuration Backup** — backs up network config to
the TP-Link cloud (tied to your TP-Link ID) to restore on new Decos or a reset.
- **Auto Backup = ON** (enabled 2026-06-23). "Backup Now" available for manual.
- Caveat: it's **cloud-only** (no downloadable `.bin`, not git-able) and it is
  **unproven** that it captures client nicknames — names were lost last time. So
  keep this sheet too. Restore happens during Deco setup ("restore from backup").

## How to rename a client (app-only)

The web UI at `http://192.168.68.1` is a locked SPA with no client management.
Use the **Deco phone app**:

1. Network tab → tap the client → pencil/edit name → Save.
2. Optionally set the device type/icon.

Names sync to your TP-Link ID. There is **no config-file export** that captures
them — this doc is the backup of record.

## Decoder rule

Deco auto-name `Computer_XXXX` = **last 4 hex of the device MAC**.
MAC OUI (first 3 bytes) gives the type: `bc:24:11` = Proxmox VM,
`b8:27:eb` = Raspberry Pi.

## Canonical name map (fixed-MAC infrastructure)

| Set this name | IP | MAC | Default Deco name | Device |
|---|---|---|---|---|
| book5 (Proxmox) | 192.168.68.250 | 6c:1f:f7:6b:30:96 | Computer_3096 | prox-book5 hypervisor |
| tower (Proxmox) | 192.168.68.249 | 78:20:51:3c:fc:59 | Computer_fc59 | prox-tower hypervisor |
| pihole | 192.168.68.248 | b8:27:eb:40:55:50 | Computer_5550 / raspberrypi | magic-pihole DNS |
| omarchy (VM100) | 192.168.68.100 | bc:24:11:59:fb:56 | Computer_fb56 | desktop VM |
| ubuntu (VM101) | 192.168.68.101 | bc:24:11:16:64:74 | Computer_6474 | media/Mullvad VM |
| home-assistant (VM111) | 192.168.68.111 | bc:24:11:94:b8:9a | Computer_b89a | HAOS VM |
| homelable (CT103) | 192.168.68.61 / .54 | 26:22:cd:82:dd:d3 | Computer_ddd3 | topology visualizer |
| Wife laptop | 192.168.68.59 | 74:13:ea:0f:c1:6b | Computer_c16b | **pihole full-bypass client** |
| (Deco main router) | 192.168.68.1 | 8c:86:dd:e8:c2:ea | — | gateway itself |

Phones / tablets / IoT (.52 .57 .62 .66 .67 .70 .71 .72, first octet `5e`/`26`/
`82`/`ae`) use **MAC randomization** — their MAC and Deco name drift on reconnect,
so fixed names don't stick. Don't bother naming those.

## DHCP-server limitation in router mode (researched 2026-06-24)

**The Deco BE63 CANNOT disable its DHCP server while in Wi-Fi Router mode.** This
is a firmware-level product decision, not a hidden toggle. The Operation Mode
screen even states NAT + DHCP "are enabled by default" in router mode, and the
**More → Advanced → DHCP Server** page only exposes the IP pool/range +
**Address Reservation** — there is **no on/off switch** and (typically) no
lease-time field. TP-Link's own response: *"There is no intention to disable DHCP
under wireless router mode."* Years-old, repeatedly-requested, never shipped.

**Implication for the homelab:** moving DHCP onto pihole (or Kea HA) requires
demoting the Deco to **Access Point mode** — which also disables Parental
Controls, QoS, Device Isolation, and Connection Alerts (those move to whatever
routes: OPNsense/pihole). Tracked in `TODO.md` EPIC Phase 2. Until then, the most
control available in router mode = **Address Reservation** (stable per-MAC IPs) +
**pihole Local DNS Records** (real `.lab` names).

Sources:
- https://community.tp-link.com/en/home/forum/topic/162072 (Ability to disable DHCP in router mode)
- https://community.tp-link.com/en/home/forum/topic/270766 (Need to disable DHCP server in router mode)
- https://community.tp-link.com/us/home/forum/topic/748846 (Is there any DHCP server in Deco BE63)

## Related

- Wife laptop `74:13:ea:0f:c1:6b` = pihole client group **"bypass"** (zero
  blocklists) → unfiltered DNS so her employer VPN works. Real hardware MAC
  (won't rotate). If ads/filtering ever hit her machine, confirm this client is
  still in the bypass group: `pihole-FTL sqlite3 /etc/pihole/gravity.db
  "SELECT c.ip,c.comment,g.name FROM client c JOIN client_by_group cbg ON
  c.id=cbg.client_id JOIN 'group' g ON g.id=cbg.group_id;"`
- pihole `.248` is **inside** the DHCP pool — keep it on a static/reservation or
  DNS vanishes network-wide. See homeLab CLAUDE.md DNS section.
