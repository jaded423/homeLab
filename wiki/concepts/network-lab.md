---
type: concept
title: Network lab — repeatable, tiered experiments on the home network (career practice)
tags: [network, lab, vlan, dhcp, dns, stp, firewall, openwrt, glinet, flint3, deco, ap-mode, switch, blast-radius, runbook]
related: [network-segmentation, network-topology, dns-adblocking, tower, pihole, access-model]
---

# Network lab — repeatable, tiered experiments

**Why (2026-09-10):** Joshua backed into networking jobs, likes it, and wants it as a career. The house is about to
change shape anyway (Flint 3 replaces the Archer as gateway, the Archer + Decos become APs, VLANs arrive), so every
step of that rebuild doubles as a lesson. The rule that makes this safe: **every experiment is assigned a tier
before it runs, and the tier fixes the blast radius.** Destructive is fine. Destructive *on the family's internet*
is not.

Target design (labels, wiring, hardware decision) is owned by [[network-segmentation]]; the current flat network by
[[network-topology]]. This page owns the **method** and the **exercise list**. The Pi appliances (piGate) are the
instruments, not the subject — `~/projects/piGate/networks/home-dryrun.md` has the inventory + Uptime Kuma pattern.

**Sibling lab:** [[terminal-lab]] — TERM / terminfo / ncurses / escape sequences, same exercise shape, all tier 0.

## The three tiers

| Tier | Where | Can break | Cannot break | Reset |
|---|---|---|---|---|
| **0 — sandbox** | [[tower]] `vmbr9` (VLAN-aware bridge, no physical uplink) + CTs 900/910/920 · optionally containerlab/FRR on a VM for pure L2/L3 topology drills | itself | anything real — no wire leaves the host | `pct stop` / restore the CT snapshot |
| **1 — island** | the Flint 3 + a dumb switch + one Deco in AP mode + pi-gw2 (piGate kit #2) as the resident client/probe. Flint **WAN → a house LAN port** (double-NAT). **Flint LAN on its own scheme `10.68.0.0/16`**, VLANs `10.68.10/20/30/40.0/24` — never `192.168.68.x` while the house still uses it | everything on the island, all day | the house: nothing on `192.168.68.0/22` depends on the island, and the island's WAN zone blocks RFC1918 outbound (exercise 1) | factory-reset + `sysupgrade -r <backup>`; or just unplug the WAN |
| **2 — production** | the real cutover and any later change to the house network | the family's internet | — | the previous gateway, powered off but **config untouched**, plugs back in |

Tier promotion rule: a change reaches tier 2 only after it has been done and *undone* at tier 1 with the restore
timed. Tier 0 is for anything whose physics you don't yet understand (run the packet capture there first).

## Instruments (know your readings before you break anything)

- **pi-gw2 on the island**: `nmap -sn` inventory before/after, Uptime Kuma monitors (`piGate/fleet/kuma-seed.py`, an
  island `monitors.csv`), `tcpdump -i eth0 -n` for ARP/DHCP/STP frames. The same box, the same way, at a client site.
- **Mac**: `scripts/netwatch.sh` (30 s gateway-loss baseline, already running), Wireshark, `arp -a`, `route -n get`,
  `dig @<server>`, `traceroute`.
- **Flint 3 (OpenWrt)**: `logread -f`, `ip -br addr`, `bridge vlan show`, `swconfig`/`bridge` for ports,
  `cat /tmp/dhcp.leases`, `nft list ruleset`, `uci show network|firewall|dhcp`, `sysupgrade -b /tmp/cfg.tgz`.
- **Is that switch managed? (remote check, proven 2026-09-10)**: a managed switch has a management IP (look in
  `ip neigh` on hosts behind it) and originates LLDP/STP frames — listen on any port behind it with
  `tcpdump -i <iface> -nn -e 'ether proto 0x88cc or ether dst 01:80:c2:00:00:00'` for 40 s. An unmanaged
  switch has no IP and sends nothing except chipset chatter (Realtek-chip units broadcast RRCP `0x8899` once a
  second from the switch's own MAC — OUI lookup names the brand). The office switch behind the Archer came back
  unmanaged TP-Link, 2.5G (MAC `10:5a:95:39:11:6f`, no IP, no LLDP/STP, links negotiated 2500 Mb/s).
- **Notebook**: one entry per run — date · tier · hypothesis · exact commands · what was observed · restore verified
  (yes/no, time). Append to `docs/network-lab-log.md` (create on first run). Config snapshots to book5
  `/root/network-lab/<date>-<exercise>.tgz`. Repeatable = someone else could rerun it from the entry.

## Exercises

Each has the same shape: **setup → measure → break → observe → restore → lesson.** Numbers are a suggested order;
1–4 are the foundations everything else assumes.

| # | Tier | Exercise | Break it | Expect / learn |
|---|---|---|---|---|
| 1 | 1 | **Island bring-up.** Flint LAN `10.68.0.1/24`, DHCP pool `.100–.199`, WAN into a house port. pi-gw2 + the Mac as clients. Add WAN-zone rule: drop outbound to `192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12`. | From the island, `nc -vz 192.168.68.250 22`. | Internet works, house unreachable ⇒ the island is a **guest network** by construction. This rule *is* what "guest isolation" means. |
| 2 | 1 | **DHCP as a system.** Pool vs static-outside-pool (the house pattern), reservation by MAC, lease time 2 min for visibility, option 6 (DNS) + option 3 (gateway). Watch `tcpdump port 67 or 68` for DORA. | Plug the **Archer, still in router mode**, into the island switch = a rogue DHCP server. | Clients randomly get the wrong gateway; only some devices break; `tcpdump` shows two OFFERs racing. The classic "someone plugged a home router into the office" fault — and why a managed switch's DHCP snooping exists. |
| 3 | 1 | **Duplicate IP / gateway collision.** Two boxes claim `10.68.0.1`. | Set pi-gw2's IP to the Flint's. | ARP flaps (`arp -a` alternates MACs), sessions half-work. This is *exactly* what plugging the `.68.*`-configured Flint into the live house would have done — the reason tier 1 uses its own scheme. |
| 4 | 1 | **Broadcast storm / loop.** | Patch a dumb switch port to another port on the same switch. | Everything on the island dies within seconds; Kuma goes red; LEDs solid. Unplug ⇒ instant recovery. Managed switches run **STP** so this can't happen — and what STP costs (30 s port-up delay, root-bridge election). |
| 5 | 0 → 1 | **The three layers, physically.** Repeat the tower lab on wire: `work` (10), `iot` (20), `family` (30), `guest` (40) as bridge-VLANs on the Flint; each Flint LAN port untagged into one label. Client per label (Mac, pi-gw2, a phone on the Deco). | Turn `ip_forward` off, then on with `policy drop`, then add one allow. | Wall (ARP fails across labels) / door (all cross) / lock (only the allowed direction+port). Same test matrix as [[network-segmentation]] "three layers" — now with real ports. |
| 6 | 1 | **Trunk to a switch.** Tag all four VLANs on one Flint port → a managed switch (buy a used 8-port 802.1Q 1G unit, ~$30; 2.5G later). Access ports per label on the switch. | Set a port's PVID wrong; tag where the client expects untagged. | Native VLAN, PVID, tagged-vs-untagged — the thing every "why can't this port see the printer" ticket is. |
| 7 | 1 | **Deco as an AP into a VLAN.** Deco in AP mode, its uplink on an access port for `family`. Then a second Deco, **paired**, on an `iot` port. | Let them pair. | Wireless clients land in the port's label (works). Paired Decos bridge the two labels together — the trap in [[network-segmentation]] § AP situation, seen live. Un-pair ⇒ separate networks, no roaming. |
| 8 | 1 | **DNS as a control.** DHCP hands pi-gw2's (or a lab pihole's) address; add a firewall redirect of all `:53` to it and drop `:853`/DoH IPs. | `dig @8.8.8.8 ads.example` from a client. | Redirected queries still answer from the local resolver; the TV's hard-coded DNS can't escape. Why [[dns-adblocking]] alone "fails open". |
| 9 | 1 | **Where does the gateway Pi live in a VLAN'd site?** pi-gw2 in `family` advertising `10.68.30.0/24`; try to reach an `iot` camera through it from the phone on cellular. | Move the Pi to `iot`; then to a trunk port with a tagged interface per VLAN. | The subnet router only sees what its own label + the lock let it see. Decides the piGate rule for client sites with VLANs (one Pi on a trunk with `--advertise-routes` per VLAN, or one Pi per label). |
| 10 | 1 | **Restore drill.** `sysupgrade -b` the working island, factory-reset the Flint, restore from the backup. Time it. Then rebuild from the notebook *without* the backup. | — | Two restore paths, both timed. The second number is the honest one. Nothing goes to tier 2 without it. |
| 11 | 1 | **Failure drills.** Pull the WAN mid-transfer; reboot the Flint; kill the DHCP server only; unplug the AP's uplink. | each in turn | What clients do while the gateway is gone (lease keeps working, ARP cache, DNS cache), how long each takes to notice, what Kuma shows. Builds the "is it the router or the ISP" instinct. |
| 12 | **2** | **The cutover** (`TODO.md` Flint 3 item). Re-address the island config to the house scheme (`192.168.68.1/22`, pool `.69.0–.71.254`, DNS → pihole `.248`), swap Archer → Flint at the modem, Archer + Decos to AP mode, netwatch before/after, Kuma from pi-gw1 the whole time. | Rollback = Archer back on the modem, config untouched. | The move itself is boring because every piece was done at tier 1. Time budget: 30 min swap, 15 min rollback. |

After 12, the house *is* the lab's tier 1 topology and later changes (a new label, a new AP) run 5–11 in place with
the rollback being "restore last night's backup".

## What not to do in the real world (grows with the log)

- Never bring a pre-configured router onto a live network on the *same* subnet (exercise 3). Stage it on its own.
- Never let a client's "spare router" stay in router mode on the LAN (exercise 2).
- Never trust a consumer AP's "isolation" toggle as segmentation (exercise 7, and [[network-segmentation]]).
- Never change the gateway without a timed, rehearsed restore (exercise 10) and the old box powered off but intact.

## Sources

- [[network-segmentation]] (labels, hardware, tower lab) · [[network-topology]] (current house) ·
  `~/projects/piGate/networks/home-dryrun.md` (inventory + Kuma method) · `TODO.md` § Flint 3 router cutover.
