# Twingate SSH Privileged Access — Potential Cutover Plan

**Status:** Maybe / future project. Captured 2026-05-11 after reviewing https://www.twingate.com/docs/ssh-privileged-access-overview. Reassess later — no work scheduled.

## TL;DR

Twingate now offers an SSH Privileged Access mode where a Gateway component proxies SSH connections, authenticates the user via the configured IdP, and issues short-lived SSH certificates per session. It replaces SSH-key distribution and adds session recording.

For this homelab it would mostly:

- Retire `ProxyJump` for VM access from desktops (the Gateway becomes the implicit jump host).
- Retire per-host SSH key management for homelab servers and VMs.
- Add session recording for accountability — nice-to-have, not load-bearing for a solo operator.

It would **not** touch:

- Termux on S25 Ultra / S9 FE / S10+ — no mobile client support.
- Reverse-tunnel architecture for roaming devices (Mac, Go, PC, phones → book5).
- `ssh pi1` via the work PC at Elevated — outside Twingate's reach.

So the realistic outcome is a hybrid: Privileged Access for desktop → homelab servers/VMs, current setup retained everywhere else.

## What Privileged Access actually changes

| Concern | Today | With Privileged Access |
|---|---|---|
| Auth to homelab servers | SSH keys per device | Short-lived certs signed by Twingate CA, IdP-gated per session |
| VM access from Mac | `ProxyJump book5` (workaround for Twingate route interception) | Direct via Gateway — no ProxyJump needed |
| Key rotation | Manual | Automatic, per-session |
| Session audit trail | None | Terminal I/O recorded (not sftp/rsync data, not port-forward payloads) |
| X11 forwarding | Works | Not supported |
| sftp / rsync / TCP port forward | Works | Supported |
| Mobile (Termux) | Works via tunnel pattern | **Not supported** — stays as-is |

## Requirements (per Twingate docs, 2026-05-11)

- Connector ≥ 1.82.0
- Client minimums: macOS 2026.85+, Windows 2026.90+, Linux 2025.342+
- A deployed Gateway component (one in the home network is enough for the existing targets)
- Targets registered as SSH Resources, with the Gateway in line-of-sight

## Targets to migrate (in scope)

Desktop → homelab path only:

- `book5` (192.168.68.250)
- `tower` (192.168.68.249)
- `pihole` (192.168.68.248)
- `omarchy` (VM 100, 192.168.68.100) — drop ProxyJump
- `ubuntu` (VM 101, 192.168.68.101) — drop ProxyJump
- `trans` CT 102 (192.168.68.65)
- `homelable` CT 103 (192.168.68.61)

## Targets explicitly out of scope

- Termux: `s25`, `s9`, `s10` — no Android client, keep tunnel pattern.
- Roaming devices' reverse tunnels back to book5 (Mac, Go, PC, S9 FE, S10+) — orthogonal to this feature.
- `pi1` at Elevated — reached through the work PC, not via Twingate.
- Anything where X11 forwarding is needed (none currently, but worth flagging).

## Cutover sketch (when ready, not now)

1. **Inventory check** — confirm current connector and client versions across Mac, Go, WSL meet minimums.
2. **Deploy a Gateway** in the home network. Most logical placement: VM 101 (already runs the Twingate connector) or a small dedicated CT on book5. Don't co-locate on something that can't tolerate the extra load.
3. **Pilot with one low-risk target.** `pihole` is a good first pick — single-purpose, easy to roll back. Register as an SSH Resource, gate by IdP, connect from Mac, confirm cert-based auth works end-to-end.
4. **Expand to homelab servers** — `book5`, `tower`. Keep the existing key-based auth path alive in parallel until confident.
5. **Migrate VMs and drop ProxyJump.** Once `omarchy` and `ubuntu` are accessible directly through the Gateway, remove the `ProxyJump` lines from `~/.ssh/config` for those hosts. **Verify from a clean shell on Mac, not just inside an existing session.**
6. **Audit `~/.ssh/authorized_keys` on each migrated target.** Once cert-based auth is proven stable, remove the desktop-Mac key entries. Keep emergency-access keys (e.g. a recovery key stored offline) — don't lock yourself out.
7. **Update docs.** `~/.claude/CLAUDE.md` Home Lab Quick Reference still says "VMs use ProxyJump … because Twingate intercepts direct routes from Mac" — that note retires with the cutover.
8. **Leave Termux / reverse tunnels untouched.** They're a separate concern.

## Risks and gotchas

- **Gateway is a new single point of failure** for desktop SSH into the homelab. If it goes down, you lose the new path. Keep the emergency-access key around so you're not bricked.
- **IdP outage = no SSH.** Whatever IdP Twingate is configured against becomes load-bearing for homelab access. Worth thinking about before committing.
- **ProxyJump removal is the kind of change that bites at the worst possible moment.** Test from a fresh terminal on the Mac and from at least one off-network location (e.g. tethered) before declaring success.
- **Session recording storage and retention** — check where Twingate stores recordings and whether that's acceptable for a personal homelab. May be more visibility than you want.
- **The `book5`-as-hub mental model doesn't disappear**, because it's still the entry point for reverse tunnels from roaming devices. Don't expect this to "clean up" the whole SSH topology — only the desktop → server path.

## Decision criteria for revisiting

Re-evaluate if any of these become true:

- A second person needs SSH access (then key distribution actually hurts and identity-gating actually helps).
- Twingate ships an Android client for Privileged Access (Termux paths could collapse into one model).
- A compliance / audit requirement appears that wants session recording.
- Current SSH key sprawl across machines becomes a real maintenance burden.

Until one of those triggers, the current setup is fine and the migration cost isn't justified by the upside.
