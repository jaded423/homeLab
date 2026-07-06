# Home Lab Expansion Plans

**Created:** January 13, 2026
**Current State:** [homelab.md](../homelab.md)

---

## Current Infrastructure Summary

### What We Have

| Resource | Details |
|----------|---------|
| **Proxmox Cluster** | 2 nodes + QDevice (3-vote quorum) |
| **Compute** | book5 (16GB) + tower (78GB, Xeon 16c/32t) |
| **GPU** | Quadro M4000 8GB (passthrough to VM 101) |
| **Storage** | 880GB NVMe (book5) + 370GB SSD + 3.5TB HDD (tower) |
| **Networking** | 1GbE management + 2.5GbE inter-node link |
| **Services** | Plex, Jellyfin, Ollama, Frigate NVR, Pi-hole, qBittorrent |
| **Remote Access** | Twingate (3 connectors) + reverse SSH tunnel |
| **Backup** | Pi1 git mirror (15 repos, 4-hourly) |

### What's Working Well

- Proxmox cluster stable with QDevice quorum
- GPU passthrough for Ollama acceleration
- Frigate NVR with 30-day retention on HDD
- Remote access from anywhere via Twingate
- Pixelbook Go as mobile dev machine with reverse tunnel
- Automated git backups on Pi1

---

## Potential Upgrades

### Raspberry Pi 5 AI Node (Under Consideration)

**Status:** Researching | **Budget:** $731.82

| Component | Cost |
|-----------|------|
| Raspberry Pi 5 16GB | $177.99 |
| Hailo-8L M.2 AI Accelerator (26 TOPS) | $210.00 |
| Pironman 5-MAX Case (dual M.2, OLED, RGB, tower cooler) | $94.99 |
| 2TB Crucial NVMe SSD | $191.99 |
| Shipping | $55.85 |
| **Total** | **$731.82** |

**Note:** Pironman 5-MAX required (not standard) for dual M.2 slots - runs both NVMe + Hailo simultaneously via PCIe switch.

**What Hailo-8L is good for:**
- Real-time object detection (YOLO, SSD) at 26 TOPS
- Frigate has native Hailo support - could offload detection from GPU
- Edge AI inference without cloud dependencies
- Low power (~5W for AI workloads)

**Potential roles:**

| Role | Benefit |
|------|---------|
| **Frigate coral replacement** | Dedicated AI detection, free up Quadro for Ollama |
| **Third Proxmox node** | True HA cluster (2TB local storage) |
| **Dedicated AI inference** | Edge detection, home automation triggers |
| **Replace magic-pihole** | Pi-hole + QDevice + AI in one device |

**Comparison to current setup:**

| Task | Current | With Pi 5 + Hailo |
|------|---------|-------------------|
| Frigate detection | Quadro M4000 (shared with Ollama) | Hailo-8L (dedicated) |
| LLM inference | Quadro M4000 | Quadro M4000 (100% available) |
| Object detection speed | ~15-20 FPS | ~30+ FPS (Hailo optimized) |

**Questions to resolve:**
- [ ] Does Pironman 5 case fit AI HAT+ or is it either/or?
- [ ] Can run Proxmox or better as dedicated Frigate/AI device?
- [ ] Power consumption vs benefit for always-on use

**Decision:** Worth it if Frigate detection is bottlenecking Ollama, or want dedicated edge AI.

---

### Storage Expansion

**Current:** 3.5TB usable on tower HDD

| Option | Cost | Benefit |
|--------|------|---------|
| Add 2nd 4TB HDD to tower | ~$80 | ZFS mirror for redundancy |
| Add NVMe to tower | ~$100 | Faster VM storage |
| Dedicated NAS device | $300-500 | Separate storage from compute |

**Triggers:**
- Media library exceeds 2TB
- Need redundancy for critical data
- Frigate retention needs expansion

---

### Third Proxmox Node

**Current:** 2 nodes + QDevice

| Option | Cost | Benefit |
|--------|------|---------|
| Raspberry Pi 5 (8GB) | ~$100 | Lightweight third node, true HA |
| Mini PC (N100) | ~$150 | Better compute, low power |
| Used workstation | ~$200 | Full compute node |

**Triggers:**
- Need true HA (survive node failure with VMs running)
- Want to experiment with CEPH
- QDevice Pi becomes unreliable

**Note:** Current setup works fine for home use. Third node is "nice to have" not "need to have."

---

### Networking Upgrade (Under Consideration)

**Status:** Researching | **Budget:** ~$300-350

**Current pain points:**
- Spectrum ISP router/modem combo
- Not enough ethernet ports
- Cannot configure (locked down)
- No VLANs, no port forwarding control, no QoS

**Proposed:** TP-Link Deco BE63 (Deco 7 Pro) - 2 Pack

| Feature | Details |
|---------|---------|
| WiFi Standard | WiFi 7 (BE10000) Tri-Band |
| Ports | 4x 2.5GbE per unit (8 total) |
| Backhaul | Wired 2.5GbE or wireless |
| Security | HomeShield, VPN server/client |
| Coverage | ~5,500 sq ft (2-pack) |
| Price | ~$300-350 |

**What this enables:**

| Capability | Current | With Deco 7 Pro |
|------------|---------|-----------------|
| Ethernet ports | ~4 (shared with ISP) | 8x 2.5GbE |
| WiFi speed | WiFi 5/6 (ISP) | WiFi 7 |
| Port forwarding | None (locked) | Full control |
| VPN | Twingate only | Native + Twingate |
| QoS | None | Full control |
| Guest network | Maybe | Yes, isolated |
| Device grouping | No | Yes |

**Network architecture with Deco:**

```
Internet → Spectrum Modem (bridge mode) → Deco 7 Pro (router)
                                              │
                    ┌─────────────┬───────────┼───────────┬─────────────┐
                    │             │           │           │             │
                 book5        tower       pihole        Mac          Go
              (2.5GbE)      (2.5GbE)     (1GbE)      (WiFi 7)    (WiFi 7)
```

**Questions to resolve:**
- [ ] Can Spectrum modem be put in bridge mode? (most can)
- [ ] 2-pack enough or need 3 for coverage?
- [ ] Keep 2.5GbE inter-node direct link or route through Deco?

**Verdict:** High priority - network control is foundational for homelab. 2.5GbE ports match existing inter-node speed.

---

### Home Network Privacy — Whole-Home VPN

**Status:** Phase 1 ready to execute (Deco built-in WireGuard) | Phase 2 = future hardware upgrade | **ISP plan:** Spectrum 2 Gbps

**Project phases:**
1. ✅ **DNS layer** — Pi-hole → Unbound recursive resolver (completed 2026-04-13)
2. 🟡 **Whole-home VPN** — Deco BE63 built-in WireGuard client → Mullvad. **Zero hardware cost.** Runbook: [deco-vpn-setup.md](deco-vpn-setup.md)
3. ⚪ **Full firewall + VLANs** (future) — OPNsense mini-PC when budget allows. Enables IoT isolation, Suricata/Zenarmor, line-rate 2 Gbps VPN. Hardware research below.

**What user is blocking against:**
1. ISP surveillance — Spectrum sees every site connection via SNI/IP even over HTTPS
2. IoT phoning home — TVs, cameras, smart devices reporting to manufacturers (Phase 3 / OPNsense territory — DNS blocking at Pi-hole partially mitigates today)

**Important correction (2026-04-14):** Earlier planning assumed Deco could not do VPN client. TP-Link added native WireGuard client to Deco firmware in late 2024. BE63 V1.60 / V2.60+ supports manual `.conf` import (Mullvad-compatible) and per-device routing via "Client List." This unlocks Phase 2 with **zero new hardware** — full runbook in [deco-vpn-setup.md](deco-vpn-setup.md).

---

#### Phase 2 (active): Deco WireGuard → Mullvad

**Status:** Runbook ready, user can execute when home | **Cost:** $5/mo Mullvad, $0 hardware

- Selective per-device routing via Deco "Client List" (allow-list mode):
  - **On VPN**: workstations (Mac, user's PC, phones, tablets) + **VM 101 Ubuntu** (qBittorrent P2P + Frigate cloud ALPR + Plex/Jellyfin server outbound)
  - **Off VPN**: wife's work PC (corporate VPN conflict), homelab infra (book5/tower/pihole — Twingate connectors), VM 100 (Tower Guardian), cameras, family streaming/IoT devices
- DNS stays on Pi-hole (override Mullvad's `DNS = 10.64.0.1` to `192.168.68.248` in config)
- Twingate coexistence: book5/tower/pihole excluded so connectors reach Twingate relays directly. Remote Plex/Jellyfin via Twingate stays low-latency because tower's connector isn't VPN'd
- LAN streaming bypass: local clients → VM 101 Plex/Jellyfin stays at full LAN speed (LAN traffic doesn't traverse the WireGuard tunnel)
- Throughput expectation: ~300–600 Mbps on Deco hardware (caps 2 Gbps line — acceptable for Phase 2, triggers Phase 3 if painful)

See [deco-vpn-setup.md](deco-vpn-setup.md) for pregame checklist, step-by-step setup, verification, and rollback.

---

#### Phase 3 (future): OPNsense Mini-PC Router

**Trigger conditions (any one):**
- VPN throughput on Deco is unacceptable for actual usage
- Want real 802.1Q VLAN isolation for IoT (cameras can only reach Frigate, nothing else)
- Want Suricata/Zenarmor, deep flow logging, or open-source firmware purity
- Budget allows $350–550

**What OPNsense enables beyond Deco:**
- Real VLANs (IoT isolated from LAN, cameras restricted to Frigate only)
- Policy-based routing at the firewall level, not per-device permissions
- Per-device/per-VLAN firewall rules with full packet visibility
- Suricata IDS/IPS, Zenarmor app-layer filtering
- Line-rate 2 Gbps WireGuard throughput (N305 CPU)
- Open-source firmware (auditable, indefinite support lifetime)

#### Target topology (reuses existing 2x Deco BE63)

```
Spectrum modem ──► [NEW router] ──► Deco1 (AP mode) ──► Deco2 (AP mode, wired backhaul)
                    (WAN 2.5G)        4x 2.5GbE               4x 2.5GbE
                                      = 1 in + 1 uplink       = 1 in
                                        + 2 free                + 3 free
```

**Port map after cutover:**

| Port | Speed | Best use |
|---|---|---|
| Deco1 × 2 available | 2.5G | book5, tower |
| Deco2 × 3 available | 2.5G | pihole, future nodes, misc |
| Router LAN leftovers | 1G–2.5G | slow devices / management |

Decos demoted to AP mode via Deco app (disables NAT/DHCP/routing, keeps WiFi + switching). Wired backhaul between Deco1 and Deco2 via 2.5GbE — must be enabled in Deco app before physical cabling.

#### Hardware options being compared

**WireGuard throughput matters** — Spectrum 2 Gbps line means every option below caps VPN speed below line rate. Only N305+ hits full 2 Gbps.

| Option | Landed cost | WG throughput | Firmware | Pros | Cons |
|---|---|---|---|---|---|
| **GL.iNet Flint 2 (GL-MT6000)** | $170 + $40 switch* = ~$210 | ~900 Mbps (~45% of line) | OpenWrt (open) | Plug-and-play, low fiddling, open firmware | Only 1x 2.5GbE LAN, rest 1GbE (*needs 2.5GbE switch if preserving inter-node speeds*) |
| **OPNsense N100 DIY** | ~$390 | ~900 Mbps – 1.2 Gbps | OPNsense (open) | Full flex, cheapest open-source path, 4x 2.5GbE | Hunt parts, DRAM shortage hurts |
| **OPNsense N100 pre-built** (Glovary N150, 6x 2.5GbE, 8GB/128GB) | $479 | ~900 Mbps – 1.2 Gbps | OPNsense (open) | Ready out of box | $90 premium for convenience, same VPN cap |
| **OPNsense N305 barebone** (CWWK/Glovary/MOGINSOK) | ~$360–420 w/ 8GB + 256GB | ~1.5–2 Gbps (full line) | OPNsense (open) | Matches 2Gbps internet for VPN, 8-core future-proof | More expensive, still DIY |
| **OPNsense N305 pre-built** (Glovary, HUNSN RJ35) | $450–550 | ~1.5–2 Gbps (full line) | OPNsense (open) | Zero assembly, line-rate VPN | Priciest option |
| **ASUS ExpertWiFi EBG19P** | $180 | ~300–500 Mbps (~20%) | Closed ASUS | Commercial support, PoE+ ports | Closed firmware = privacy tension; 3.0★ reviews; throttles VPN badly at 2Gbps |

**Candidate product links** (check pricing at time of purchase — DRAM shortage affects RAM-included models most):

- N305 barebones on Amazon: [Glovary N305 4x 2.5GbE barebone](https://www.amazon.com/Glovary-Firewall-OPNsense-Hardware-Appliance/dp/B0D3P8F211) · [MOGINSOK N305 4x 2.5GbE barebone](https://www.amazon.com/MOGINSOK-Firewall-Appliance-Computer-Barebone/dp/B0CB87179J) · [CWWK N305 4x 2.5GbE barebone](https://www.amazon.com/CWWK-PC-N305-Fanless-Barebone/dp/B0C274PGW1)
- N305 pre-built on Amazon: [Glovary N305 4x 2.5GbE 8GB/512GB](https://www.amazon.com/Glovary-Firewall-N305-Ethernet-Appliance/dp/B0CJ5MT8J6) · [CWWK N305 4x 2.5GbE 8GB/1TB](https://www.amazon.com/CWWK-PC-8-core-N305-Fanless/dp/B0C274TQZH)
- N305 on Newegg: [HUNSN RJ35 N305 16GB/512GB](https://www.newegg.com/p/22Z-007C-00HG6)
- Direct from manufacturer: [CWWK mini-PC collection](https://cwwkpc.com/collections/mini-pc) (F1/F5/F7/F11 variants vary by port count)

#### Key spec requirements (non-negotiable)

- CPU with **AES-NI** (hardware crypto — any N100/N150/N305/N355 qualifies)
- **Intel I226-V** NICs only — NOT I225 (firmware bugs cause link drops)
- 4+ Ethernet ports (or 2 + managed switch for VLANs later)
- 8GB RAM minimum, 16GB ideal (needed if Suricata/Zenarmor added later)
- 120GB+ NVMe, **M.2 2280 form factor** (2230 won't fit)
- For 2 Gbps line-rate VPN: **N305 or better** (N100 caps at ~half)

#### Twingate coexistence plan

- Twingate connectors (book5, tower, pihole) must bypass VPN — need direct outbound to Twingate relays
- Firewall rule: source IPs of the 3 connectors route around the VPN gateway
- Per-workstation VPN clients (Mac/PC/phones) use split tunneling to exclude Twingate app

#### VPN provider selected

**Mullvad** (anonymous 16-digit account, flat $5/mo, WireGuard-native)
- Runner-up: Proton VPN (better for streaming, bundles with Mail/Drive) — not chosen because user self-hosts media via Plex/Jellyfin

#### Scope decision

Workstations through VPN, IoT + cameras direct (Phase 1). VLAN isolation for IoT deferred to Phase 2 when more comfortable with OPNsense rules.

#### Install gotchas (capture now so we don't relearn at 11pm on cutover night)

1. Configure new router **first**, then flip Decos to AP mode in Deco app. Otherwise DHCP vanishes mid-swap.
2. Enable **Wired Backhaul** in Deco app before physically cabling Deco1 → Deco2 (else wireless backhaul loop risk).
3. Recreate **all DHCP reservations** on new router before cutover: book5 .250, tower .249, pihole .248, omarchy .100, ubuntu .101, cameras .75/.76, S9 .50, S10 .73, Mac .247, phone .200. Broken reservations cascade — Twingate resources, Corosync QDevice, NFS exports, Frigate camera URLs all depend on these IPs.
4. Confirm **Spectrum modem bridge mode** capability *before* ordering hardware. If unavailable, accept double-NAT (works, some fuss).

#### Decision pending (Phase 3 — when triggered)

- [ ] Execute Phase 2 (Deco VPN) first and measure real-world throughput before buying hardware
- [ ] Micro Center trip (opportunistic) — check RAM + NVMe pricing, ask if they stock N305 boxes or Flint 2
- [ ] Confirm Spectrum modem bridge mode
- [ ] Decide router class (when ready):
  - Flint 2 ($170+switch) = simplicity, VPN caps at 45% of line
  - N100 OPNsense (~$390–480) = flex + open source, same VPN cap
  - **N305 OPNsense (~$360–550) = best fit for 2 Gbps internet** (full line-rate VPN)

---

### Tower-as-Router (Parked — Future Consideration)

**Status:** Not being pursued. Kept here as a "maybe someday" note.

**The idea:** Run OPNsense as a VM on prox-tower (already has 2 NICs — onboard Intel I218-LM 1GbE + PCIe TP-Link 2.5GbE) instead of buying dedicated hardware. Would use PCI passthrough for WAN NIC.

**Why not doing it now:**

| Concern | Detail |
|---|--------|
| Single point of failure | Tower reboot = whole-house internet outage. Currently tower reboot only affects Plex/Frigate. |
| Intel I218-LM TSO bug | Tower Guardian exists *because* this NIC occasionally needs physical reboots. Router on a flaky NIC is a bad foundation. |
| Bootstrap race | Proxmox host needs network up to start cleanly; if router is a VM on that host, chicken-and-egg on every reboot. |
| Update windows | Proxmox kernel updates become scheduled household outages. |
| GPU + NIC passthrough | M4000 already passed to VM 101. Adding NIC passthrough compounds fragility on kernel updates. |
| Twingate connector | Tower is a Twingate connector — router+connector on same host invites routing loops. |

**Conditions under which to revisit:**
- Tower I218-LM NIC is replaced with a stable PCIe card
- Dedicated mini-PC router is retired/unavailable and no budget to replace
- Want to run OPNsense as a non-production *learning/staging* VM (safe — just don't point the network at it)

**Staging VM path is still useful anytime:** Run OPNsense as a VM on tower with internet access but *not* as the network router. Use it to learn the UI, build firewall rules, test WireGuard-to-Mullvad configs. Export config → import on real hardware when that arrives. This is zero-risk and worth doing even if dedicated hardware is coming.

---

### GPU Upgrade for Ollama (Under Consideration)

**Status:** Researching | **Current:** Quadro M4000 (8GB VRAM)

**Goal:** Run larger LLMs (30B+ parameters) fully in VRAM

| Option | VRAM | Cost | Pros | Cons |
|--------|------|------|------|------|
| **Tesla P40** | 24GB | ~$200-250 + $30 cooling | Best VRAM/dollar, runs 30B+ | Datacenter card, needs cooling |
| **RTX A4000** | 16GB | ~$350-400 | Pro card, quiet, single slot | Less VRAM, pricier |

**Recommended: Tesla P40 + Cooling Kit**

| Component | Cost |
|-----------|------|
| Tesla P40 24GB (used) | ~$200-250 |
| Cooling kit (shroud + fan) | ~$30-40 |
| **Total** | **~$230-290** |

**P40 Cooling Options:**
- **Commercial kit** (Amazon/eBay): 3D printed shroud + 40mm server fan (~$30-40)
- **DIY**: 3D print shroud + Noctua fans (~$30-50, quieter)
- **Simple**: 120mm case fan pointed at heatsink (~$15)

Users report temps dropping from 85°C → 51°C with cooling kits.

**Alternative: RTX A4000**

| Component | Cost |
|-----------|------|
| RTX A4000 16GB (used) | ~$350-400 |
| **Total** | **~$350-400** |

Pros: Quiet, single-slot, no cooling mods needed. Cons: 16GB vs 24GB, ~$100-150 more.

**Combined AI Strategy:**

```
Object Detection  → Pi 5 + Hailo-8L (26 TOPS, dedicated)
LLM Inference     → Tower + Tesla P40 (24GB) or A4000 (16GB)
```

This separates concerns: Frigate detection no longer competes with Ollama for GPU.

---

### Services to Consider

| Service | Purpose | Complexity |
|---------|---------|------------|
| **Uptime Kuma** | Service monitoring | Easy |
| **Grafana + Prometheus** | Metrics/dashboards | Medium |
| **Vaultwarden** | Self-hosted passwords | Easy |
| **Immich** | Photo management | Medium |
| **Paperless-ngx** | Document management | Medium |
| **Home Assistant** | Home automation | Medium |
| **Nextcloud** | Private cloud storage | Medium |
| **Gitea** | Self-hosted git | Easy |

---

### Remote Site Considerations

**Current remote devices:**
- Windows PC (etintake) - WSL + Twingate connector
- Pi1 - Git backup mirror via ICS

**Potential:**
- Second Proxmox node at remote site for DR
- Automated backup replication (ZFS send/receive)
- Cross-site VM failover

**Triggers:**
- Critical services need offsite backup
- Want disaster recovery capability

---

## Not Planned (And Why)

| Item | Reason |
|------|--------|
| **Rack mount** | Overkill for 2 nodes, noise concerns |
| **Dell R630/R730** | Too loud, power hungry for home |
| **Full CEPH cluster** | ZFS + NFS working fine, CEPH needs 3+ nodes |
| **Kubernetes** | Docker Compose sufficient for current needs |
| **Multiple VLANs** | Current flat network works, added complexity |

---

## Decision Framework

**Before buying anything, ask:**

1. **What problem does this solve?** (Not "what could it do")
2. **Is current setup actually limiting me?** (Measure, don't assume)
3. **What's the total cost?** (Hardware + power + time)
4. **Does it add complexity?** (More to maintain/break)

**Guiding principles:**
- Grow based on actual bottlenecks, not hypothetical ones
- Used enterprise hardware offers best value
- Keep total power consumption reasonable (<300W)
- Prefer simple solutions over "proper" complex ones
- Document everything before and after changes

---

## Budget Guidelines

### Active Consideration

| Item | Cost | Priority | Status |
|------|------|----------|--------|
| Mullvad VPN subscription (Phase 2) | $5/mo | **High** | Runbook ready; execute when home — [deco-vpn-setup.md](../homelab/deco-vpn-setup.md) |
| OPNsense router hardware (Phase 3) | $170–550 | Deferred | Triggered if Deco VPN throughput inadequate; N305 best for 2Gbps Spectrum |
| TP-Link Deco 7 Pro (2-pack) | ~$320 | High | Researching |
| Raspberry Pi 5 + Hailo + Pironman 5-MAX + 2TB NVMe | $731.82 | Medium | Researching |
| Tesla P40 24GB + Cooling Kit | ~$250-290 | Medium | Researching |
| *(or)* RTX A4000 16GB | ~$350-400 | Medium | Alternative |
| **Total (Deco + Pi5 + P40)** | **~$1,300** | | |
| **Total (Deco + Pi5 + A4000)** | **~$1,450** | | |

### General Guidelines

| Priority | Budget | Examples |
|----------|--------|----------|
| **High** | $0-100 | Software changes, minor upgrades |
| **Medium** | $100-300 | Storage expansion, GPU upgrade |
| **Low** | $300+ | Major hardware, networking overhaul |

**Current monthly costs:**
- Power: ~$15-25 (estimated)
- Twingate: Free tier
- Domain/services: ~$0

---

## Archive

Previous expansion plans (historical reference):
- [archive/homelab-expansion-2025-11.md](archive/homelab-expansion-2025-11.md)
- [archive/homelab-multi-site-expansion-2025-11.md](archive/homelab-multi-site-expansion-2025-11.md)
