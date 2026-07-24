---
type: component
title: book5 (Proxmox Node 1)
tags: [proxmox, host, book5, cluster-node, dns-proxy, reverse-tunnels]
related: [tower, vm100-omarchy, pihole, watchdogs, dns-adblocking, access-model, network-topology]
host: book5
ip: 192.168.68.250
---

# book5 — Proxmox Node 1 (prox-book5)

Samsung Galaxy Book5 Pro 360 laptop running Proxmox VE 8.x as **cluster node 1**.
Hosts [[vm100-omarchy]] and the native Homelable scanner (CT 103). Node sibling =
[[tower]]. QDevice for cluster quorum runs on [[pihole]].

## Quick Access

```bash
# From Mac
ssh book5            # bare alias = Tailscale (primary, anywhere)
ssh book5-local      # LAN direct
ssh root@192.168.68.250

# Web UIs (Tailscale MagicDNS)
https://prox-book5:8006   # Proxmox
https://prox-book5:9090   # Cockpit (SSH-independent)
```

Full access model (Tailscale/Twingate, `-ts` aliases, ProxyJump) → [[access-model]].

## Hardware

| Component | Details |
|-----------|---------|
| Model | Samsung Galaxy Book5 Pro 360 |
| CPU | Intel Core Ultra (Lunar Lake, details TBD) |
| RAM | 15 GB usable (16 GB marketing) |
| Storage | 880 GB NVMe (ZFS) |
| Display | 15.6" AMOLED touchscreen (disabled for server use) |

### Network Interfaces

| Interface | Type | Speed | IP | Bridge | Purpose |
|-----------|------|-------|-----|--------|---------|
| Realtek RTL8156 | USB 3.0 | 2.5 Gbps | 192.168.68.250 | vmbr1 | Primary (mgmt + inter-node) |
| USB-C Dock | Ethernet | 1 Gbps | — | vmbr0 | **Inactive** (post-Feb-2026 migration) |

> NOTE: The deep doc listed vmbr0 (USB-C dock, 1 Gbps) as the `.250` management
> interface and vmbr1 as a separate `10.10.10.1/30` inter-node link. Per the
> authoritative current state (2026-06-18), both nodes now run on their 2.5 GbE
> primary interfaces (vmbr1) and **vmbr0 exists on book5 but is inactive**.

## Proxmox / Cluster

| Property | Value |
|----------|-------|
| Cluster Name | home-cluster |
| Node ID | 1 |
| Quorum | 3 votes (2 nodes + QDevice on [[pihole]]) |
| Storage `local` | ZFS 880 GB — ISOs, templates |
| Storage `local-zfs` | ZFS 880 GB — VM disks |

```bash
pvecm status          # cluster + quorum status
pvecm nodes           # list nodes
pvecm expected 2      # operate on both nodes if QDevice offline
```

## Hosted VMs / Containers

| VMID | Name | IP | Notes |
|------|------|-----|-------|
| 100 | Omarchy | 192.168.68.100 | Auto-start; iGPU passthrough. See [[vm100-omarchy]] |
| CT 103 | Homelable | 192.168.68.61 | Network scanner — see below |

> NOTE: **CT 102 (`trans`)** was DESTROYED 2026-06-19 (LXC deleted to free book5
> resources — gone, not down). `trans` work now runs ad-hoc, no dedicated container.

### Homelable (CT 103)

Network scanner, native install on book5 / vmbr1, scans `192.168.68.0/22`.

| Property | Value |
|----------|-------|
| IP | 192.168.68.61 |
| Web UI | `:3000` (admin/admin) |
| MCP | `:8001` |

## Services

| Service | Type | Port(s) | Purpose |
|---------|------|---------|---------|
| SSH | Native | 22 | Remote management |
| Proxmox Web UI | Native | 8006 | Cluster management |
| Cockpit | Native | 9090 | Web management (SSH-independent) |
| Twingate Client | systemd | — | VPN tunnel (auth.sock) |
| Twingate Connector | systemd | — | jaded423 network access |
| dnsproxy-doh | systemd | 443, 853 | DoH/DoT proxy → Pi-hole |
| Reverse Tunnels | Listener | 2246-2250 | Mac, Phone, S9, S10+ device access |
| net-health-monitor | systemd timer | — | Watchdog (see [[watchdogs]]) |
| cpu-watchdog | script | — | Suspends first VM if CPU pinned (see [[watchdogs]]) |

> NOTE: **Samba (smbd) was RETIRED 2026-05-27** (was unused; `/root` share was a
> security smell). The deep doc's Samba-shares section is obsolete — ignore it.

### DNS proxy (dnsproxy-doh)

DNS-over-TLS/HTTPS proxy so the phone can use Android Private DNS via Twingate; forwards
to Pi-hole ([[pihole]]). Full ad-blocking / DNS story → [[dns-adblocking]].

| Property | Value |
|----------|-------|
| Binary | `/usr/local/bin/dnsproxy` (v0.78.2, AdGuard) |
| Service | `dnsproxy-doh.service` |
| DoH / DoT | 443 / 853 |
| Upstream | Pi-hole `192.168.68.248:53` |
| Domain | `dns.jadedviber.com` (Let's Encrypt, DNS-01, certbot auto-renew) |
| Cert | `/etc/letsencrypt/live/dns.jadedviber.com/fullchain.pem` |

**Traffic flow:** Phone (cellular) → Android Private DNS (DoT) → `dns.jadedviber.com:853`
→ Twingate tunnel → book5 dnsproxy → Pi-hole `192.168.68.248:53` → ads blocked.

**Note:** Plain DNS port 53 is NOT bound (avoids conflict with Twingate connector). Do
NOT enable Twingate "Secure DNS" / Custom DoH — causes a circular dependency.

```bash
systemctl status dnsproxy-doh
journalctl -u dnsproxy-doh -f
openssl x509 -enddate -noout -in /etc/letsencrypt/live/dns.jadedviber.com/fullchain.pem
```

### Twingate (client + connector) + sdwan0 DNS pin

book5 runs **both** the Twingate client (VPN tunnel) and connector (resource access for
jaded423 network).

```bash
systemctl status twingate twingate-connector
systemctl restart twingate twingate-connector
```

**sdwan0 DNS pin (self-healing):** a TG update periodically deletes+recreates the
`sdwan0` NM connection with dead `100.95.0.x` resolvers (connector shows
`DEAD_HEARTBEAT_TOO_OLD` while systemd says active because DNS is broken). Auto-remediated
2026-05-27 by the NM dispatcher hook `/etc/NetworkManager/dispatcher.d/90-twingate-dns-pin`,
which re-pins `sdwan0` DNS → pihole `192.168.68.248` and restarts the connector on every
`sdwan0` up/dhcp4-change. Full detail → [[dns-adblocking]].

```bash
# Manual fallback if the pin fails
nmcli connection modify sdwan0 ipv4.dns 192.168.68.248 ipv4.ignore-auto-dns yes
nmcli device reapply sdwan0
systemctl restart twingate-connector
journalctl -t twingate-dns-pin
```

**Weekly TG updates:** Sunday 3:00 AM, log `/var/log/twingate-upgrade.log`. Skip before
travel with `OOO` (creates `/var/log/twingate-skip-upgrade`).

### Watchdogs (summary)

book5 runs several watchdogs with hardcoded subnet IPs (update if the subnet changes).
One-line summaries below; full escalation logic + logs → [[watchdogs]].

- **`network-health-monitor.sh`** (v2.1) — graduated escalation: socket issues restart
  the TW client only; NM restart only on true isolation (internet AND peers down, 6+
  consecutive fails); also probes DNS. State `/var/lib/network-health-monitor/state.json`,
  logs `journalctl -t net-health`.
- **`cpu-watchdog.sh`** — suspends the first running VM if CPU > 99% for 3 min.
- **`fix-vm101-route.service`** — overrides the Twingate route to VM 101 (via [[tower]] on
  vmbr1).
- **`rsyslog`** (UDP 514) — receives tower's full syslog → `/var/log/tower-remote.log`
  (`/etc/rsyslog.d/10-receive-from-tower.conf`). Tail after a tower hang to see last
  messages before a crash.
- **`tower-watchdog.timer`** (2026-07-20) — first-line auto-heal for [[tower]]: probes it on
  LAN + Tailscale, and after ~15 min down power-cycles tower's Tapo P105 (`192.168.69.178`) via
  python-kasa (`/opt/tower-watchdog/`, no IFTTT). **tower's PRIMARY recovery** — its iTCO
  hardware watchdog is BIOS-locked. ntfy alerts + 2-cycle cap. Full detail → [[watchdogs]].
- **Tower flight-recorder sink** (2026-07-20) — `/var/log/tower-flightrec.log` receives tower's
  3s state stream (ring-buffered ~1 week); the pre-freeze autopsy channel. → [[watchdogs]].

### Reverse tunnels (roaming devices)

book5 is the endpoint for roaming-device reverse SSH tunnels. **The pc/wsl/go tunnels
were dropped 2026-05-27** (those devices reach book5 over Tailscale now — see
[[access-model]]). Remaining tunnels:

| Port | Device | Persistence |
|------|--------|-------------|
| 2246 | Mac | LaunchAgent |
| 2247 | Phone (S25 Ultra) | Termux:Boot |
| 2249 | Tablet (S9 FE) | On-demand (`s9up` / `s9down`) |
| 2250 | S10+ | On-demand (`s10up` / `s10down`) |

On-demand scripts (`/root/bin/tunnel-up.sh <device>` / `tunnel-down.sh`) SSH to the device
locally, toggle wake-lock + tunnel — saves battery on the Android devices.

```bash
ss -tlnp | grep -E '22[45][0-9]'   # check listening tunnels
ssh -p 2249 localhost              # reach the S9 FE tablet from book5
```

## Troubleshooting (book5-specific)

```bash
# Twingate not connecting after reboot
systemctl restart twingate-connector

# Can't ProxyJump a VM
ssh book5 hostname
ssh book5 "qm status 100"
ssh book5 "qm guest cmd 100 network-get-interfaces"

# Cluster quorum (QDevice offline is OK with both nodes up)
pvecm status
pvecm expected 2
```

Cross-node / recovery runbook → see the `homelab-host-recovery` skill and [[tower]].

## Sources

- `~/.claude/docs/homelab/book5.md` (deep doc — migrated; Samba + vmbr0/inter-node
  layout superseded)
- `~/projects/homeLab/CLAUDE.md` lines 45–119 (Operational Current State, authoritative)
