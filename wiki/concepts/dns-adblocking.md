---
type: concept
title: DNS & Ad-Blocking Policy
tags: [dns, pihole, adblock, twingate, tailscale, flint3, unbound, dns-over-tls]
related: [pihole, watchdogs, access-model, go, network-topology, mullvad]
---

Network-wide DNS = pihole `192.168.68.248`. This page owns the **policy** (where DNS is
configured, the gotchas, the auto-remediation). The pihole host/appliance itself → [[pihole]].

> **⚠ "Whole-home" overstates it — pihole is advisory, and it fails open.** It is *not* in
> the traffic path; it answers lookups only when a device chooses to ask. Devices with a
> hardcoded resolver (smart-TV firmware → `8.8.8.8`), browsers using encrypted DNS, a
> manually-changed setting, or anything on cellular simply never consult it — silently, with
> no alert. It also only ever sees the **domain**, never the page, so it is the wrong tool
> for content monitoring. Making it actually mandatory needs a gateway that redirects all
> DNS and blocks encrypted-lookup ports → [[network-segmentation]].

## Where network DNS is configured (the ONE field that matters)

Network DNS is handed to all clients via **Flint 3 (GL.iNet admin panel → Network → LAN → DHCP, or `uci get dhcp.lan.dhcp_option` = `6,192.168.68.248`)**
(no secondary; IPv6 RA/DHCPv6 disabled). This is **NOT** the router's own upstream-DNS setting. Router =
GL.iNet Flint 3 since 2026-09-23 (history → [[network-topology]]); any "Deco app" / "Archer" wording elsewhere is stale.

> **GOTCHA — after a WAN outage / router swap, ads still block but Google/Apple names SERVFAIL for up to
> 15 min:** unbound's infra cache marked their authoritative servers down during the outage. `ssh pihole
> 'sudo unbound-control flush_infra all'` clears it instantly (2026-09-23 Flint cutover).

- pihole `.248` is **static**, sitting inside the DHCP pool (`.50`–`71.250`).
- Spectrum modem is in **bridge mode** (router WAN = public IP, no double-NAT).

> **GOTCHA — "ads returned network-wide? check that field FIRST":** if ads come back for
> everyone, verify the **DHCP-Server Primary DNS** field is still `.248` before anything else.
> It blanked during the 2026-06-19 outage / modem swap (see changelog 2026-06-21 + brain
> `deco-dhcp-dns-pihole`). A blank field = clients fall back to ISP DNS = no blocking.

## Tailscale MagicDNS forwarding

Tailscale MagicDNS (`100.100.100.100`) is **transparent** — it forwards to the DHCP-assigned
DNS, which is pihole. So devices on the tailnet still get ad-blocking without extra config.

## `.lab` names — Pi-hole Local DNS Records (since 2026-09-18)

`frig.lab`, `plex.lab`, `odoo.lab`, `ha.lab`, `portainer.lab`, `qbit.lab`, `ollama.lab`,
`jit.lab` (Gitea), `prox.lab` + the infra names (`book5.lab`, `tower.lab`, …) are **Pi-hole
Local DNS Records**. Source of truth = `docs/lab-dns-records.list` (git-tracked); apply with
`pihole-FTL --config dns.hosts '[ "IP name", … ]'` on `.248` (v6 stores them in
`pihole.toml`, NOT `hosts/custom.list`, which FTL regenerates). Before 2026-09-18 these were
**Twingate resource aliases** resolved by the Mac's Twingate client — nothing else on the
LAN could see them. Twingate stays off on the Pocket unless something proves unreachable.

> **GOTCHA — the Archer (gateway `.1`) hands out itself as a second DNS server** (observed on the Pocket
> 2026-09-18 despite "Secondary blank"). systemd-resolved sticks to whichever server last
> answered, and the Archer NXDOMAINs every `.lab` name → "site can't be reached" while pihole
> answers fine. Fix per Linux client: pin the Wi-Fi profile to pihole only —
> `nmcli con mod <ssid> ipv4.dns 192.168.68.248 ipv4.ignore-auto-dns yes && nmcli dev reapply <if>`
> (done on the Pocket, profile `Spaceballs_MLO`). Fleet-wide fix = make the Archer DHCP hand
> out `.248` alone, if its UI allows.

**Remote (`.lab` from anywhere on the tailnet, 2026-09-18):** Tailscale **split DNS** `lab →
192.168.68.248` (set via the API, `PATCH /api/v2/tailnet/-/dns/split-dns`; key file
`~/.secrets/tailscale_api_key`, token "Claude is Everywhere"). MagicDNS hands every `.lab`
query to pihole; the reply IPs are LAN, reached through **pi-gw1's subnet route**
(`192.168.68.0/22`, approved). A client must **accept routes** to use it — Linux defaults
this OFF.

> **GOTCHA — Linux Tailscale prefers the subnet route over the connected LAN** (verified on
> the Pocket: `ip route get 192.168.68.101` → `dev tailscale0 table 52` while sitting on the
> home Wi-Fi). With accept-routes on at home, every LAN packet hairpins through pi-gw1
> (works, ~40 ms, but dies with pi-gw1). Fix = a NetworkManager dispatcher that flips
> accept-routes off on the home SSID and on elsewhere: `pocket/linux/90-tailscale-routes`.

## book5 sdwan0 DNS pin + auto-remediation (Twingate resolver failures)

book5's Twingate interface (`sdwan0`) must **not** use Twingate's `100.95.0.x` resolvers —
they stop answering while the connector still reports `online`, which breaks DNS on book5 and
shows the connector as `DEAD_HEARTBEAT_TOO_OLD` (systemd says active because DNS, not the
process, is broken). Fix = pin sdwan0 DNS → pihole.

**Manual pin (fallback):**
```bash
nmcli connection modify sdwan0 ipv4.dns 192.168.68.248 ipv4.ignore-auto-dns yes
nmcli device reapply sdwan0
systemctl restart twingate-connector
```
Persisted in `/etc/NetworkManager/system-connections/sdwan0.nmconnection`.

**Why it needs auto-remediation:** a Twingate update deletes + recreates `sdwan0` with a fresh
UUID and dead `100.95.0.x` resolvers — **recurred 3× by 2026-05-27**.

**Auto-remediation (2026-05-27):** NM dispatcher hook
`/etc/NetworkManager/dispatcher.d/90-twingate-dns-pin` (root:root 0755) re-pins sdwan0 DNS →
pihole, reapplies, and restarts `twingate-connector` on every sdwan0 `up`/`dhcp4-change`,
guarded to no-op once already correct.
```bash
journalctl -t twingate-dns-pin   # dispatcher logs
```

This ties into the [[watchdogs]] net-health-monitor (which probes DNS via `check_dns` and logs
`action=dns_broken` when DNS fails while internet + peers are up — no auto-fix, just a flag) and
the broader [[access-model]] (Twingate connector on book5).

## pihole `bypass` group recipe (device VPN pre-tunnel DNS blocked)

If a device's VPN won't connect / hangs, pihole may be blocking the DNS lookup it needs
**before** the tunnel comes up. Fix = add the device's MAC to a pihole `bypass` group that has
**0 adlists**, so its queries resolve unfiltered. (Recorded in brain `pihole-bypass-group`.)

## Twingate → pihole for remote ad-blocking (family devices)

pihole is exposed as Twingate resources so remote devices get ad-blocking off-LAN with no port
forwarding / dynamic DNS. Resources: DNS (`:53` TCP+UDP), DNS-over-TLS (`:8853` TCP), web admin
(`:80/:443`). Assign the **DNS resource only** to family members (not admin). On the device, set
Private DNS to the pihole IP while Twingate is connected. Full walkthrough:
`~/projects/homeLab/docs/twingate-pihole-setup.md`.

## DNS-over-TLS (DoT)

pihole runs **dnsdist** as a TLS proxy in front of it for encrypted DNS:
`Internet → :8853 (DoT) → dnsdist → pihole :53 → upstream`. DoT port is **8853** (custom, not
the standard 853); dnsdist config `/etc/dnsdist/dnsdist.conf`; Let's Encrypt cert for
`pihole.jadedviber.com`. Test: `dig @127.0.0.1 -p 8853 +tls google.com`. Setup detail:
`~/projects/homeLab/docs/pihole-setup.md`.

> **NOTE (source discrepancy):** `docs/pihole-setup.md` + `docs/twingate-pihole-setup.md` are
> pre-migration (Nov 2025) and still reference the old **192.168.1.191** pihole IP and
> Raspberry-Pi-1 host. The authoritative current state (CLAUDE.md, 2026-06-21) is pihole =
> **192.168.68.248** (`magic-pihole`). Use `.248`; treat those docs for the DoT/Twingate-resource
> *procedure*, not the IP.

## Client-side Twingate DNS-hijack (per-device gotcha)

Twingate's `sdwan0` sets a `~.` catch-all DNS route that hijacks all lookups to its (often dead,
off-LAN) resolvers `100.95.0.x`. On roaming clients this shows up as "disconnected" / no name
resolution when away from the LAN. On the Pixelbook [[go]] the fix was to **disable Twingate**
(NM profiles live in `/etc`, kernel-independent) so the Elevated wifi profile connects. Same
root cause as the book5 sdwan0 pin above, different remedy per host.

## Sources

- `~/projects/homeLab/CLAUDE.md` "Operational Current State" (2026-06-18+) — DNS/ad-blocking
  block (2026-06-21), book5 watchdog + sdwan0 DNS pin / twingate-dns-pin dispatcher
- `~/projects/homeLab/docs/pihole-setup.md` — pihole + dnsdist DoT setup (pre-migration IPs)
- `~/projects/homeLab/docs/twingate-pihole-setup.md` — Twingate-as-pihole-resource (pre-migration IPs)
- `~/.claude/docs/homelab/deco-vpn-setup.md` — Deco DHCP DNS → pihole, bypass-group / DNS gotchas
