---
type: component
title: VM 123 — multi-verse (second home for the Claude/brain knowledge base)
tags: [vm123, multi-verse, arch, claude, drift, backup, tailscale]
related: [tower, vm101-ubuntu, storage, access-model]
host: multi-verse
ip: 192.168.68.123
---

# VM 123 — multi-verse (`multi-verse`)

A small always-on Arch VM on [[tower]] that holds a working copy of everything the Pocket
holds in git: every `~/projects` repo, the global Claude config, the memory stores. If the
Pocket is off or lost, the same phone → ssh → tmux → Claude flow works here. The Pocket stays
the main machine; this is a peer, not a replacement.

Plan and status: `~/.claude/plans/multi-verse.md` (until it retires).

## Facts (created 2026-10-03)

| | |
|---|---|
| VMID / name | 123 / `multi-verse`, starts on boot |
| OS | Arch Linux (official cloud image, headless) |
| Size | 2 vCPU, 4 GB RAM, ONE 64 GB disk on `media-pool-vm` (HDD pool — space over speed) |
| Network | `vmbr1`, static 192.168.68.123/22, gateway .1, DNS pihole then 1.1.1.1 (set by cloud-init) |
| Login | user `j` (home `/home/j`, zsh), key-only; keys: Pocket, phone proot, phone Termux |
| ssh | `ssh multi-verse-local` (LAN / subnet route). Tailnet name `multi-verse` once logged in |
| Its own key | `j@multi-verse` — registered on Gitea; GitHub pending |

## What runs on it

- **`drift.timer`** (user unit, lingering): every 30 min fetch all repos, fast-forward the clean
  ones, cache the verdicts. The Pocket reads this machine's state over ssh (`~/.config/drift/peer`).
  Tool: `scripts/bin/drift`.
- **Claude Code** (native install) + the dotfiles (`unibrain/install-all.sh`), `~/.claude` →
  `~/projects/.claude`, `~/scripts` → `~/projects/scripts` — same layout as the Pocket.
- `tailscaled`, `qemu-guest-agent`.

## What is deliberately NOT on it

- Secrets: no `~/.secrets`, no MCP credentials. 1Password is their only home.
- Gitignored files from the Pocket's repos (local configs, data): only tracked content was seeded.
- LLM weights (`~/llm`), `archive/`, `graveyard/`.

## Rebuild

`qm destroy 123`, then: Arch cloud image → `qm create` with cloud-init (user `j`, the three keys,
static IP) → `pacman -S` the CLI set → copy each repo's `.git` from the Pocket and check out →
`unibrain/install-all.sh` → install the drift units. About 20 minutes, nothing on it is unique.
