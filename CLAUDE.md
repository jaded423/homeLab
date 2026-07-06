# CLAUDE.md — homeLab

Two-node Proxmox cluster (book5 + tower) + VMs + a roaming device fleet, on the
`192.168.68.0/22` LAN. Runs local LLMs, media/services, home automation, and doubles as
the family's zero-trust network hub (Tailscale + Twingate + pihole). This repo is the
**authoritative documentation** for all of it.

---

## The knowledge lives in `wiki/` (read this first)

Homelab knowledge is an **LLM-Wiki** under [`wiki/`](wiki/) — one page per host + concept
pages, typed frontmatter, `[[links]]`. **Start at [`wiki/index.md`](wiki/index.md)**, then
[`wiki/concepts/network-topology.md`](wiki/concepts/network-topology.md) for the device/IP
map and [`wiki/concepts/access-model.md`](wiki/concepts/access-model.md) for how to reach
anything.

Quick map:

- **Hosts:** [book5](wiki/components/book5.md) · [tower](wiki/components/tower.md) ·
  [vm100-omarchy](wiki/components/vm100-omarchy.md) · [vm101-ubuntu](wiki/components/vm101-ubuntu.md) ·
  [vm111-homeassistant](wiki/components/vm111-homeassistant.md) · [pihole](wiki/components/pihole.md) ·
  [pi1](wiki/components/pi1.md) · [mac](wiki/components/mac.md) · [go](wiki/components/go.md) ·
  [pc](wiki/components/pc.md) · [phone](wiki/components/phone.md) ·
  [s9-tablet](wiki/components/s9-tablet.md) · [s10](wiki/components/s10.md)
- **Concepts:** [network-topology](wiki/concepts/network-topology.md) ·
  [access-model](wiki/concepts/access-model.md) · [dns-adblocking](wiki/concepts/dns-adblocking.md) ·
  [mullvad](wiki/concepts/mullvad.md) · [watchdogs](wiki/concepts/watchdogs.md) ·
  [storage](wiki/concepts/storage.md) · [gpu-passthrough](wiki/concepts/gpu-passthrough.md) ·
  [troubleshooting](wiki/concepts/troubleshooting.md) · [history](wiki/concepts/history.md)

---

## Wiki conventions (the schema)

- **One fact-home per page.** Component pages = one host each; concept pages = cross-cutting
  systems (network, access, DNS, VPN, watchdogs, storage, GPU). Don't duplicate — keep a
  1-line summary on the host page and `[[link]]` to the concept page that owns the detail.
- **Frontmatter** on every page: `type` (component | concept | index | log — the one required
  field), `title`, `tags`, `related`. Host pages also carry `host:` + `ip:`.
- **Links** in body use `[[page-slug]]` (slug = filename without `.md`). Point Obsidian at
  `wiki/` for the graph view.
- **Preserve exact commands / paths / IPs / config** — for homelab the exact command IS the
  reference value (there's no external script to link to, unlike a code repo). Don't paraphrase
  a fix into uselessness.
- **This wiki is the current-state source of truth.** `~/.claude/CLAUDE.md` carries only a
  compact quick-ref + pointer here; `brain` MCP (`project=homeLab`) is the searchable layer.

## Current-state routing (for `/log`)

`/log` Step 0 routes homelab **current-state** changes into the owning **wiki page** (the host
or concept it belongs to) + the wiki [`log.md`](wiki/log.md), and the code/event paper-trail
into [`docs/changelog.md`](docs/changelog.md). (Previously this doc's "Operational Current
State" section was the target; that content moved into `wiki/` on 2026-07-06 — see
[`wiki/log.md`](wiki/log.md).)

## Other files

- **Task list:** [`TODO.md`](TODO.md) · **wiki-evolution log:** [`wiki/log.md`](wiki/log.md)
- **Current-state / event paper-trail:** [`docs/changelog.md`](docs/changelog.md)
- **Deep planning / reference** (long-form, kept as-is): [`docs/`](docs/) — build-plan,
  llm-homelab-research, homelab-planning-guide, proxmox-ceph-cluster-guide, pihole-setup,
  twingate-pihole-setup, gaming-vm-plan, linux-os-comparison, network-rebuild, expansion-plans.
- **Runbook skills:** `homelab-host-recovery` (downed host) · `homelab-net-check` (reachability).
