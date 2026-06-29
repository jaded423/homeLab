# Home Network Rebuild — Archer BE550 + 2× Deco (wired backhaul)

**Status:** PLANNED — cabling weekend of 2026-06-27. Pet-room node live first; living-room node when the warranty Deco arrives.
**Spurred by:** 2026-06-19 lightning strike (see changelog 2026-06-19 / global chat history). Strike killed the modem, one Deco BE63, the Pi-hole screen, and a wifi light strip. Pi-hole itself survived. Losses spanned multiple outlets on different circuits → whole-house surge through panel/ground, **not** the coax line.

---

## Goal

1. **Control** — Archer BE550 becomes the router (config-as-code / real DHCP / port-forward / VPN control). Escapes the Deco app's app-only, no-API limitation that drove the BE63 frustration.
2. **Fix the office** — wifi is spotty in the one room being turned into an office. Solve by relocating the ISP entry there + making it a wired island.
3. **House-wide wifi + wired drops** — wifi already proved fine from 2 Decos; add real wired ports to kids' rooms + living room entertainment.

Decos run in **Access Point mode** — Archer is the brain, Decos are wired APs. Two separate apps (Tether for Archer, Deco app for the AP layer); they do **not** integrate despite same brand. Accepted tradeoff: Archer keeps the control, Deco app is set-and-forget once APs are configured.

---

## Topology

```
Office (one end):  coax (relocated here) → modem (bridge) → Archer BE550
                     (Archer = router: 1× 10G WAN in, 4× 2.5G LAN out)
                     ├── 100 ft Cat6 ─► Deco 1  (PET ROOM)
                     └──  50 ft Cat6 ─► Deco 2  (LIVING ROOM)

Deco 1 — PET ROOM (central; wifi covers both kid rooms):
    port 1: in  (backhaul from Archer)
    port 2: out → 25 ft Cat6 → 8×2.5 dumb switch → KID ROOM A (wired devices)
    port 3: out → 25 ft Cat6 → 8×2.5 dumb switch → KID ROOM B (wired devices)
    port 4: spare
    + wifi for kids' phones/streaming

Deco 2 — LIVING ROOM (entertainment center):
    port 1: in  (backhaul from Archer)
    port 2: out → wife's TV
    port 3: out → PS5
    port 4: out → Switch (console)
    + wifi for living/middle of house
```

Everything is **true wired backhaul — no wireless mesh hop.** Every wired device gets full speed. Archer is DHCP/router, so it sees every device (Decos in AP mode + dumb switches are transparent).

---

## Hardware / BOM

| Item | Notes |
|---|---|
| TP-Link Archer BE550 | Router/brain. 1× 10G WAN, 4× 2.5G LAN — all backhauls direct to Archer, no office switch needed for them. 10G WAN is headroom until ISP > 2.5G. |
| 2× Deco BE63 | AP mode, wired backhaul. Has 1 (replacement from warranty — lightning killed one). 4× 2.5G auto WAN/LAN ports each (1 in + 3 out). |
| 2× 8-port 2.5G dumb switch | One per kid room. Already owned. |
| Cat6 — 100 ft, 50 ft, 2× 25 ft | **Premade patch cables** (stranded, ends already crimped). |
| Coupler keystone wall plates | Female-female RJ45 inline coupler inserts. **Correct part for premade cable** — plug the male end in, no punchdown/crimping. |
| Old-work low-voltage mounting brackets (mud rings) | Cleaner than full boxes for low-voltage; open back preserves bend radius. |
| Coax surge protector + whole-house panel surge protector | Post-lightning hardening (see below). |
| J-hook nail clips | Under-house cable support. |

**Termination note:** because the cable is **premade/stranded**, this build uses **couplers**, not punch-down keystone jacks. Punchdown only applies to a bulk spool of **solid-core** cable (the in-wall standard). If a future 10G rebuild uses bulk solid cable, switch to punch-down jacks then.

---

## Cabling plan + phasing

- **This weekend:** drop the two backhaul runs (100 ft → pet room, 50 ft → living room). Pet-room Deco live → whole house has wifi immediately (kids covered) even before kid-room drops.
- **Later:** the two 25 ft pet→kid-room drops + dumb switches, whenever. Living-room Deco when the warranty unit arrives.
- **Service loop:** ~3–4 ft slack coiled at each end. The 100 ft for a 60 ft house leaves excess on purpose — enables future re-route (e.g., cut in a switch as a junction to add a laundry-room drop).
- **Coax relocation to the office is the biggest job** — re-run coax to the office wall, re-ground the entry block outside.

---

## Key decisions & gotchas

- **AP mode ≠ Deco mesh mode.** AP mode = the Deco is a wired access point; it does **not** wirelessly mesh to a non-Deco router. Decos mesh **Deco-to-Deco only**. This whole build wires both Decos, so it's moot — but it's the gotcha that started this whole redesign.
- **Wireless backhaul was the fallback** (1 cable to a central Deco, others mesh) — rejected in favor of full wired backhaul since the crawlspace makes runs easy and every device then gets true wired speed.
- **2.5G backhaul cap** — Deco ports max at 2.5G, so backhaul links are 2.5G, not 10G. Irrelevant for streaming/gaming. 10G only matters Archer↔modem or a future 10G NAS/PC.
- **Keep every backhaul on 2.5G** — confirmed all 4 Archer LAN ports are 2.5G, so direct-to-Archer is fine. (Would've needed the 2.5G office switch if any were 1G.)
- **Switch-junction = daisy-chain dependency.** Cutting a switch into a run (e.g. future laundry drop) means downstream rooms ride through that switch — if it dies, downstream drops. Fine for a planned, powered switch; just a known dependency.
- **EMI:** keep Cat6 ~12 in off parallel Romex, cross power at 90°.
- **Surge (post-lightning):** whole-house **panel surge protector** is the real fix for the multi-circuit losses; point-of-use strips are per-outlet bandaids. Coax surge protector + grounded coax entry as cheap insurance.

---

## Future (5-yr horizon)

When ISP hits 7+ Gbps, rebuild with true 10GbE-ready gear (bulk solid Cat6a, punch-down jacks/patch panel, 10G switching). This year's build is the "practice homelabber" run; the wired backhaul star + room drops carry forward.

Pairs with: [deco-device-naming.md](deco-device-naming.md) for client/AP naming once the nodes are up.
