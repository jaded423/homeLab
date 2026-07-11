---
type: component
title: pihole (Proxmox qDevice, for quorum)
tags:
  - raspberry-pi
  - dns
  - pihole
  - unbound
  - qdevice
  - host
related:
  - dns-adblocking
  - access-model
  - book5
  - tower
host: pihole
ip: 192.168.68.248
---

# pihole (magic-pihole)

Raspberry Pi 2 Model B running the network's DNS/ad-block stack, plus a couple of
cluster/side roles. This page owns the **host** (the Pi hardware + what runs on it).
The DNS/ad-block **policy** (how clients get pointed here, bypass group, sdwan0 pin,
MagicDNS forwarding) is cross-cutting → one-liner below + [[dns-adblocking]] owns the
full detail. Access model → [[access-model]].

- **Device**: Raspberry Pi 2 Model B — ARM Cortex-A7 (900 MHz quad-core), 1 GB RAM,
  16 GB+ SD card, 10/100 Ethernet, HDMI (for MagicMirror).
- **Hostname**: magic-pihole (kernel hostname: `raspberrypi`).
- **OS**: Raspberry Pi OS (NetworkManager).
- **User**: `jaded` (passwordless sudo).

## Network / IP

| Interface | IP | Purpose |
|-----------|-----|---------|
| eth0 | 192.168.68.248/22 | static |
| Gateway | 192.168.68.1 | router |

> NOTE: The deep doc calls `.248` a "DHCP reservation"; the authoritative current-state
> (CLAUDE.md 2026-06-21) is that **pihole `.248` is a static IP that sits inside the
> DHCP pool** (`.50`–`71.250`). Treat it as static. Full DNS-hand-out detail →
> [[dns-adblocking]].

## Access

```bash
# SSH (Tailscale bare alias primary, LAN-direct fallback)
ssh pihole
ssh pihole-local

# Pi-hole Admin UI
http://192.168.68.248/admin      # direct IP — most reliable
http://pihole/admin/             # MagicDNS
```

Admin-slow-from-Mac gotcha: Twingate DNS (utun) can outrank Wi-Fi DNS, so `http://pi.hole/admin`
resolves poorly from the Mac — use the direct IP `http://192.168.68.248/admin`. See
[[access-model]].

SSH config block (Mac `~/.ssh/config`):
```ssh-config
Host 192.168.68.248 pihole pi
  HostName 192.168.68.248
  User jaded
  IdentityFile ~/.ssh/id_ed25519
  ServerAliveInterval 60
  ServerAliveCountMax 3
```

## Services running on this host

### Pi-hole (DNS + ad-block) — v6.3.3

Network-wide ad-blocking DNS. **Policy summary**: network DNS = this box (`.248`),
handed to all clients via Deco DHCP-Server → Primary DNS; upstream is local Unbound
(no third party). Full policy → [[dns-adblocking]].

| Property | Value |
|----------|-------|
| Admin UI | http://192.168.68.248/admin |
| DNS Port | 53 |
| Upstream | local Unbound recursive (`127.0.0.1#5335`) |
| Blocked domains | ~442,000 |

Blocklists:

| List | Domains | URL |
|------|---------|-----|
| StevenBlack hosts | ~79,000 | https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts |
| HaGeZi Multi Pro | ~383,000 | https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/pro.txt |

Ad-block test score ~94% on adblock.turtlecute.org (Feb 2026).

```bash
pihole status              # status
sudo pihole -g             # update gravity (blocklists)
sudo pihole -t             # live query log (needs sudo on v6)
pihole restartdns          # restart DNS
sudo pihole api lists      # list configured blocklists
pihole -c                  # chronometer (live stats)
```

### Unbound (recursive resolver)

Pi-hole's upstream — replaces public DNS so no third party sees queries (Unbound walks
root → TLD → authoritative directly). Swapped in from Google 8.8.8.8/8.8.4.4 on
2026-04-13.

| Property | Value |
|----------|-------|
| Listen | 127.0.0.1:5335 |
| DNSSEC | enabled (validates, rejects bogus) |
| Config | `/etc/unbound/unbound.conf.d/pi-hole.conf` |
| Root hints | from `dns-root-data` package |
| RAM | ~14 MB steady |

```bash
sudo systemctl status unbound
sudo systemctl restart unbound
sudo unbound-checkconf                                   # validate config
dig @127.0.0.1 -p 5335 cloudflare.com +short             # direct test (bypasses Pi-hole)
dig @127.0.0.1 -p 5335 dnssec.works +dnssec | grep flags:   # should show 'ad'
dig @127.0.0.1 -p 5335 fail01.dnssec.works | grep status:   # should be SERVFAIL
```

Rollback to a public resolver if Unbound fails:
```bash
sudo pihole-FTL --config dns.upstreams '[ "9.9.9.9", "149.112.112.112" ]'
sudo systemctl restart pihole-FTL
```

Pre-Unbound config backup: `/etc/pihole/pihole.toml.bak-20260413`.

### Corosync QDevice

Third vote (tie-breaker) for the Proxmox cluster quorum — lets the [[book5]]/[[tower]]
cluster survive one node failure. Without it, quorum needs both nodes.

| Property | Value |
|----------|-------|
| Cluster | home-cluster |
| Votes | 1 (tie-breaker) |
| Port | 5403 |

```bash
ssh book5 "pvecm status"     # should show Qdevice; check from Proxmox
ssh book5 "pvecm expected 2" # manually adjust expected votes if Pi is offline
```

### MagicMirror

Smart-mirror display on the attached HDMI screen.

| Property | Value |
|----------|-------|
| Port | 8080 (local) |
| Config | `~/MagicMirror/config/config.js` |

```bash
cd ~/MagicMirror && npm start   # start
pm2 status                      # status (managed by pm2)
pm2 restart MagicMirror         # restart
pm2 logs MagicMirror            # logs
```

### Twingate connector (Docker)

Connector for the jaded423 Twingate network.

```bash
docker ps | grep twingate
docker restart twingate-magic-pihole
```

Weekly auto-update: **Sunday 3:30 AM** (30 min after tower). Log
`/var/log/twingate-upgrade.log`. Skip before travel with `OOO` (creates a skip file).

### Portainer

Docker management UI — http://192.168.68.248:9000 (port 9000).

## DNS / ad-block policy — one-liner

Clients get pointed at `.248` via **Deco app → DHCP Server → Primary DNS** (Secondary
blank, IPv6 off). Tailscale MagicDNS (`100.100.100.100`) transparently forwards to the
DHCP DNS (= pihole). [[book5]]'s `sdwan0` NM connection is pinned to `.248` (auto-remediated).
Phone-away ad-block rides Android Private DNS (DoT) → `dns.jadedviber.com:853` → Twingate
→ book5 dnsproxy → pihole. **All of this lives on [[dns-adblocking]] — don't duplicate here.**

## Quick commands

```bash
pihole status
df -h                    # disk usage
vcgencmd measure_temp    # temperature
sudo reboot
```

## Troubleshooting

**DNS not resolving**
```bash
pihole status
systemctl status pihole-FTL
pihole restartdns
```

**Cluster quorum** — if the Pi goes offline the cluster loses the QDevice vote (still OK
if both Proxmox nodes are up; a single-node failure then causes quorum loss). Check with
`ssh book5 "pvecm status"`; force `ssh book5 "pvecm expected 2"` if needed.

**MagicMirror blank** — `pm2 status` / `pm2 logs MagicMirror` / `pm2 restart MagicMirror`.

**High CPU/temp** — `vcgencmd measure_temp`, `top`. Gravity updates are CPU-intensive on
this old Pi.

## Sources

- `~/.claude/docs/homelab/pihole.md` (deep doc)
- `~/projects/homeLab/CLAUDE.md` lines 45–119 (Operational Current State, DNS/ad-blocking 2026-06-21)
