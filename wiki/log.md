---
type: log
title: homeLab wiki — log
tags: [log, chronological]
related: [index]
---

# homeLab wiki — log

- **2026-09-13** — [[book5]] § piGate USB host: a piGate Pi on the dock's USB-C becomes `pigw0` (192.168.7.1/24, NAT via vmbr1, dnsmasq bound to that address, NM unmanaged) — book5 is the reference USB host after the Mac stopped enumerating the gadget (rule + cure in piGate `fleet/FLASH.md`).
- **2026-09-11** — new [[terminal-lab]]: sibling of [[network-lab]] — the TERM → terminfo → ncurses → escape-sequence stack as a study page with 10 tier-0 exercises, born from the `xterm-ghostty: unknown terminal type` fault on pi-gw1.
- **2026-09-10** — new [[network-lab]]: the home-network rebuild (Flint 3 gateway, Archer + Decos → APs, VLANs) framed as a tiered, repeatable career-practice lab — tier 0 tower sandbox, tier 1 Flint island on its own `10.68/16` scheme (double-NAT, RFC1918 blocked), tier 2 production; 12 exercises with break/restore/lesson; pi-gw2 (piGate) is the island's probe. [[network-segmentation]] keeps the target design.
- **2026-09-09** — [[pi1]] § TFT: the 3.5" SPI TFT is leaving pi1 (it is the Pi 400's screen; back to mom's). No fit on the Pi 5 gateway's case. Overlay notes stay as reference.
- **2026-09-09** — personal tailnet ACL gained `tag:gateway` + RFC1918 `autoApprovers`; **pi-gw1**
  (piGate Pi 5 tester) advertises `192.168.68.0/22` as a subnet route from the home LAN →
  [[access-model]]. Not homelab infra — leaves for the church.
- **2026-08-21** — [[pc]] (`etintake`) **retired from production**. The Elevated pipeline moved
  to m3lv; its pipeline crontab was removed (backup in place at `~/crontab.bak-cutover-2026-08-21`),
  leaving only the pc-heartbeat. ⚠️ The box must stay **POWERED** — its only Ethernet port is
  [[pi1]]'s ICS gateway, so powering it off takes pi1 offline. Moving pi1 to a LAN switch port is
  the gate on decommissioning; the Twingate connector inside WSL also still needs a new home.

Append-only record of wiki changes (ingests, restructures, lint passes). Consistent
prefix `## [YYYY-MM-DD] <op> | <what>` so it's grep-able:
`grep "^## \[" log.md | tail -5`.

For the **current-state / code** paper-trail (network changes, service changes, crash
forensics), see [`../docs/changelog.md`](../docs/changelog.md) — this log is for the wiki itself.

## [2026-07-06] restructure | CLAUDE.md + ~/.claude/docs/homelab/ → wiki/

Rolled the LLM-Wiki pattern (pilot: `elevatedWeb/wiki/`) onto homeLab, with a **full
collapse of the two homelab doc locations into this repo**:

- Built `wiki/` = **13 host component pages** (book5, tower, vm100-omarchy, vm101-ubuntu,
  vm111-homeassistant, pihole, pi1, mac, go, pc, phone, s9-tablet, s10) + **9 concept
  pages** (network-topology, access-model, dns-adblocking, mullvad, watchdogs, storage,
  gpu-passthrough, troubleshooting, history) + [[index]] + this log. Typed frontmatter
  (`type`/`title`/`tags`/`related`; hosts add `host`/`ip`), `[[links]]`.
- **Migrated** the per-node deep docs that lived OUTSIDE the repo in
  `~/.claude/docs/homelab/*.md` into the matching component/concept pages (exact commands,
  paths, IPs preserved — homelab reference value is the exact command). Old global files
  graveyarded, not deleted.
- **Synthesized** current-state from the repo `CLAUDE.md` "Operational Current State"
  (the authoritative section) into the host + concept pages. `CLAUDE.md` slimmed to schema
  + pointer; stale pre-migration 192.168.2.x content moved to [[history]].
- Repointed `~/.claude/CLAUDE.md` + `~/.claude/docs/homelab.md` at this repo wiki so global
  (non-repo-cwd) sessions still find the homelab map. Added a `brain` fact for cross-session
  recall.

Zero facts invented — reorganization + relocation of existing content. Deep planning docs
(build-plan, ceph guide, research, etc.) left as long-form under `../docs/` (Tier-2).

## [2026-07-20] add | tower silent-hang recovery stack + iTCO dead-end → [[watchdogs]], [[tower]], [[book5]]

Documented the new self-heal/forensics mechanisms into [[watchdogs]] (+ host pages): tower
**flight recorder** (state → book5, ring-buffered), **`hung_task_panic=1`**, and the book5
**`tower-watchdog.timer`** that power-cycles tower's Tapo P105 at `192.168.69.178` locally via
python-kasa (no IFTTT). Recorded the **iTCO dead-end** — the chipset hardware watchdog is
BIOS-locked (`NO_REBOOT`) on the Lenovo P510, no BMC — so book5→Tapo is tower's primary recovery.
- **2026-09-15** — Tower: `media-pool/backups/pocket` dataset (GPD Pocket 4 factory-Windows image, 71 GB, snapshotted); `j@pocket` key on tower root for direct backup streams; tailnet nodes renamed `pocket` (Linux) / `pocket-win` (Windows). → [[tower]], `../docs/changelog.md`.
Event/forensics detail → `../docs/changelog.md`.

## [2026-07-31] update | pc ephemeral-port-exhaustion signature

Added a Troubleshooting entry to [[pc]] for the class of failure where the box is **ON but
totally unreachable** — Windows ephemeral TCP port exhaustion (`Tcpip` event 4231), which took
the Live Ref pipeline down for 11h on 2026-07-29. Covers the confirm/recover/cure steps, the
winnat 100-port-block signature, and the honest state of the open question (recurrence is
inferred from the block pattern, not measured — baseline 20 blocks at T+1.5h uptime, tracked in
`TODO.md`).

Event/forensics detail → `../docs/changelog.md`.
