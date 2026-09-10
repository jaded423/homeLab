---
type: concept
title: Network segmentation (VLANs) — plan + hardware decision
tags: [vlan, segmentation, zero-trust, firewall, router, iot, glinet, openwrt, unifi]
related: [network-topology, dns-adblocking, access-model, pc, vm101-ubuntu, pi1]
---

# Network segmentation (VLANs) — plan + hardware decision

**Status (2026-08-07):** planned, not built. Flint 3 ordered. The house is still one flat
network; everything below is the target state. Practice lab is live on [[tower]].

Goal: stop the house being one flat network where a compromised camera can reach the work
PC. Driver was the LG-TV-microphone/ad-targeting story — Joshua wants untrusted consumer
gear boxed in, kids' TVs on local media only, and work equipment sealed off.

---

## The three layers (in order)

Segmentation is three separate mechanisms, and it's worth keeping them distinct because
each fails differently:

1. **VLAN tag = the wall.** A label on a switch port. Two ports with different labels
   cannot talk — ARP itself fails, so nothing above L2 gets a vote. Not routable around.
2. **`ip_forward` on the gateway = the door.** Off, labels can't reach each other at all.
   On, everything crosses. This is all "inter-VLAN routing" means.
3. **Firewall policy = the lock.** `policy drop` + explicit accepts. Direction-aware and
   port-aware: A→B on one port can be allowed while B→A is denied.

Layer 3 is where zero trust actually lives. Consumer "Guest/IoT isolation" toggles are
layer 1 only — hardcoded, no exceptions, no grants. That's the gap that forced new hardware.

## Why Pi-hole is not part of this

[[dns-adblocking]] owns the Pi-hole detail; the segmentation-relevant fact is **Pi-hole is
not in the traffic path.** It answers name lookups on request and never touches the actual
connection. Devices that use a different resolver (hardcoded `8.8.8.8` in TV firmware,
browser encrypted-DNS, a manually-changed setting) simply never consult it, and it *fails
open* with no signal.

So Pi-hole is an ad reducer, not a control. Blocking the LG TV is a **firewall** job — the
router is in the road and can't be ignored. A gateway can additionally force the issue by
redirecting all DNS to Pi-hole and blocking encrypted-lookup ports, which is what makes
"whole-home DNS" actually true.

---

## Label design

Group by **trust level, not by room** — a kid's bedroom holds a console (family), a laptop
(family), and a smart TV (untrusted).

| Label | Holds | Rules |
|---|---|---|
| `work` | work PC ([[pc]]), spare Mac | internet only; sealed from all other labels |
| `iot` | cameras, smart plugs, TVs | internet **denied** for TVs; may not initiate to anything |
| `family` | personal machines, kids' laptops, game systems | may *view* cameras; internet allowed |
| `guest` | guest wifi | internet only, cannot see any other label |

Game systems live in `family` — they want to see each other and the TVs.

Kids' TVs reach the [[vm101-ubuntu]] media server by an explicit allow on the LAN. Tailscale
is **not** needed for that (same building, same wire) — it's for reaching home from away.

---

## Hardware decision — GL.iNet Flint 3 (GL-BE9300), ~$200

Ordered 2026-08-07, Micro Center Dallas pickup. Chosen over the alternatives considered:

| Option | Verdict |
|---|---|
| **Flint 3 (GL-BE9300)** ✅ | 5× 2.5G (1 WAN, 1 WAN/LAN, 3 LAN), dual-WAN, 1GB RAM, 8GB eMMC, tri-band WiFi 7, OpenWrt-based. Open, and *more* 2.5G ports than the UniFi at $90 less. |
| UniFi UCG-Fiber ($289) | Genuinely capable (3× 10G, 4× 2.5G, 5 Gbps IDS/IPS) but a vendor ecosystem — rejected on the "big-tech-proof" goal. Not a cage though: VLANs/firewall/DHCP stay standard, runs fully local. |
| UniFi USW-Pro-XG-8-PoE ($539) | **Wrong category** — a switch, no firewall. Would have bought rooms with no rules. |
| Beryl 7 travel router ($139) | Real middle ground but 512MB RAM, travel class. Buy later for hotel wifi. |
| OpenWrt on existing TP-Link gear | **Impossible.** Archer BE550 unsupported; OpenWrt has no WiFi 7 support at all; Deco mesh units never get ports. |
| OPNsense on x86 | The endgame — see below. Micro Center stocks no multi-NIC firewall boxes; those are online-order (CWWK/Protectli class, ~$250). |

**Upgrade path:** learn OpenWrt on the Flint 3 → if outgrown, self-build a 2×10GbE OPNsense
box. The Flint 3 then retires into AP mode in the office. No e-waste at any step.

**Don't buy a beefy router.** Routing 2 Gbps is near-zero CPU. Also don't co-host services
on it — the router should be the most boring box in the house, and rebooting it for an
unrelated workload drops the family's internet. Services belong on [[book5]]/[[tower]].

---

## Wiring plan

```
rooms ──cat6a (under house)──► office 6-port patch panel
                                      │
                                      ▼
                            managed switch (office)
                                      │
                                      ▼
                                  Flint 3 ──► modem
```

The **office is where every trust level converges**, so that's the one place a *managed*
switch is required. The existing 8-port 2.5G units are **dumb** — they give ports, not
labels, and everything on one lands in whichever single label its uplink port carries.
Fine for a single-trust room; not for the office.

Port math: Archer + 2× Deco + [[book5]] + [[tower]] + [[pc]] + [[pi1]] + office camera = 8
before a printer. The gateway's own ports don't cover it; the switch does the fanout.

## AP situation

Neither the Archer BE550 nor the Decos can tag SSIDs to VLANs. They **do** support AP mode —
the limitation is only tagging. So:

- **The workable trick:** the AP needn't know about VLANs if the *switch port* does. Set a
  Deco's port untagged on one label and every device on that Deco lands there. Two Decos =
  two wireless labels, using owned hardware.
- **⚠ The trap that undoes it:** paired Decos bridge into one network and would weld those
  labels together. They must be separate single-unit networks — meaning no roaming.
- Living room is mixed-trust on one Archer (TVs + consoles + laptop), so one-label-per-AP
  doesn't cover it. Wire the TVs, or swap the AP.
- Sell the Archer once the Flint 3 lands; it funds a VLAN-aware AP.

**SSID ≠ VLAN.** The SSID is the door, the VLAN is the room. Proper gear *binds* them. The
existing Deco "IoT SSID" is Deco's own client-isolation black box, not a VLAN — on the
Flint 3 the same SSID name gets bound to the real IoT label. Don't run both on one AP.

---

## Practice lab (live on tower)

Built 2026-08-07 to prove the three layers before buying. **Zero production risk** — the
bridge has no physical uplink, so it cannot reach the real LAN.

- `vmbr9` — VLAN-aware bridge, `bridge-ports none`, in `/etc/network/interfaces`
  (backup `interfaces.bak-*`). Brought up with `ifup vmbr9`, never `ifreload -a`, so
  `vmbr1` was never touched.
- CT **910** `lab-work` (tag 10) · CT **920** `lab-iot` (tag 20) · CT **900** `lab-router`
  (tags 10+20, WAN leg on vmbr1 for apt). All `onboot=0`.

Results that made it click: work↔iot on the **same subnet** but different tags → ARP
`FAILED`, 100% loss, while same-tag → 0% loss. Then `nft` `policy drop` + a single accept
proved direction- and port-specificity (work→iot :8123 allowed; :22, ping, and the reverse
direction all blocked).

```bash
ssh tower
bridge vlan show                        # the switch port map
pct exec 900 -- nft list table inet zt  # the policy
pct destroy 900 910 920                 # teardown when done
```

Gotcha found: `nohup … &` inside `pct exec` dies when the exec session ends — use
`systemd-run --unit=… --collect` for a listener that survives.
