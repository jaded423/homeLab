---
type: concept
title: Mullvad VPN Exit (VM101)
tags: [mullvad, vpn, vm101, lockdown, multihop, qbittorrent, steam, rockstar]
related: [vm101-ubuntu, access-model]
---

VM101 is the **only** Mullvad machine in the homelab. Every Mullvad-routed app on that box (qBittorrent, downloads, game-stream rig) exits through a Mullvad tunnel with **lockdown mode ON**. The exit is hop-swappable between two modes; nothing else in the lab touches Mullvad.

## The model

- **VM101 only.** Runs on [[vm101-ubuntu]]. The **tower host is never on Mullvad** — it keeps a full, direct NIC. Only the guest VM tunnels.
- **Lockdown stays ON in both modes.** There is no VPN-off mode. Hard-fail beats leak: if the tunnel drops, traffic is blocked, not leaked.
- **Two exit modes**, swapped via aliases in VM101's `~/.zshrc` (user `jaded`).
- **All Mullvad-routed apps follow the active exit** — qBittorrent and everything else route through whichever mode is set.

> The lockdown blocks the tailnet on this box, so VM101 is walled off Tailscale and reached via ProxyJump tower — see [[access-model]].

## Lockdown: NEVER suggest disabling

Lockdown mode stays **ON at all times**, in both single-hop and multihop. This is a hard rule: **hard-fail > leak**. Do NOT suggest turning lockdown off, even temporarily, for any reason (troubleshooting, speed, convenience). If the tunnel is down, the correct behavior is blocked traffic, not fallback to the bare NIC.

## Two exit modes

| Mode | Exit | Alias | When |
|------|------|-------|------|
| **Single-hop** (default/everyday) | Stockholm `se sto` | `mv-sto` | Everything — incl. downloading games + movies Joshua owns physical copies of |
| **Multihop** | `se sto` → `us dal` (Dallas) | `mv-dal` | **Only when launching a game** |

**Default is single-hop Stockholm.** It handles all normal traffic. Since the 2.5G NIC merge, STO single-hop runs ~1.18 Gbps down (was ~950 Mbps capped on the old 1G).

**Swap to multihop Dallas ONLY to launch a game.** Rockstar/Steam throw *"unusual activity detected, cannot connect"* on a Sweden exit IP — a US (Dallas) exit was the *only* way to log into Steam. This is the sole reason multihop exists; switch back to single-hop STO afterward.

## Swap commands

Multihop (`se sto` entry → `us dal` exit):

```bash
mullvad relay set location us dal
mullvad relay set entry location se sto
mullvad relay set multihop on
```

Single-hop (Stockholm):

```bash
mullvad relay set multihop off
mullvad relay set location se sto
```

## Affected apps

Everything on VM101 that routes through Mullvad follows the active exit:

- **qBittorrent** (and other downloads) — follow whichever mode is set
- **Game-stream / Steam login** — the reason multihop Dallas exists (Sweden-IP block)

## Sources

- `~/projects/homeLab/CLAUDE.md` — "Operational Current State" (2026-06-18+), "VM 101 Mullvad exit — HOP-SWAPPABLE" block
