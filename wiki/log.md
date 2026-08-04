---
type: log
title: homeLab wiki — log
tags: [log, chronological]
related: [index]
---

# homeLab wiki — log

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
Event/forensics detail → `../docs/changelog.md`.

## [2026-07-31] update | pc ephemeral-port-exhaustion signature

Added a Troubleshooting entry to [[pc]] for the class of failure where the box is **ON but
totally unreachable** — Windows ephemeral TCP port exhaustion (`Tcpip` event 4231), which took
the Live Ref pipeline down for 11h on 2026-07-29. Covers the confirm/recover/cure steps, the
winnat 100-port-block signature, and the honest state of the open question (recurrence is
inferred from the block pattern, not measured — baseline 20 blocks at T+1.5h uptime, tracked in
`TODO.md`).

Event/forensics detail → `../docs/changelog.md`.
