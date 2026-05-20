<div align="center">

```
██╗  ██╗ ██████╗ ███╗   ███╗███████╗██╗      █████╗ ██████╗
██║  ██║██╔═══██╗████╗ ████║██╔════╝██║     ██╔══██╗██╔══██╗
███████║██║   ██║██╔████╔██║█████╗  ██║     ███████║██████╔╝
██╔══██║██║   ██║██║╚██╔╝██║██╔══╝  ██║     ██╔══██║██╔══██╗
██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗███████╗██║  ██║██████╔╝
╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝
```

# 🐍 homeLab

**Proxmox cluster · 2-node · Twingate zero-trust · Pi-hole DNS · local LLMs · Tailscale mesh**

[jadedviber.com](https://jadedviber.com) · [/homelab](https://jadedviber.com/homelab.html) · [github.com/jaded423](https://github.com/jaded423)

*From "spare laptop" to "cluster running my entire AI stack" — documented.*

![Proxmox](https://img.shields.io/badge/Proxmox-E57000?style=for-the-badge&logo=proxmox&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Twingate](https://img.shields.io/badge/Twingate-zero_trust-bd93f9?style=for-the-badge)
![Tailscale](https://img.shields.io/badge/Tailscale-mesh-cba6f7?style=for-the-badge)

</div>

---

```bash
$ whoami
joshua brown — vibe coder · homelab tinkerer · AI-driven dev

$ cat /goal.md
affordable, well-integrated home lab. proxmox cluster on consumer hardware.
local LLMs for things I don't want to send to cloud. zero-trust access from
anywhere via twingate + tailscale. pi-hole DNS for the household. everything
documented so future-me knows why.

$ uptime
~14 months in. still vibin'. still adding nodes.
```

---

## ✨ What's running

- 🖥️ **2× Proxmox nodes** — `prox-book5` (laptop, primary), `prox-tower` (mini-PC w/ M4000 GPU passthrough)
- 🐧 **VMs**: Omarchy (Arch desktop), Ubuntu Desktop/Server, Pi-hole DNS, LXC containers for `trans` (transcript work) + Homelable (network topology visualizer)
- 🛡️ **Twingate** — zero-trust SSH access from any network, no exposed ports
- 🌐 **Tailscale** — mesh layer over the homelab + every roaming device (Mac, Pixelbook, phone, tablet, second Pi)
- 🤖 **LLM stack** — Ollama on Ubuntu VM (currently 7B–13B range, 100k context with KV-cache budgeting). Frigate ALPR + CodeProject.AI for camera AI
- 📡 **Pi-hole** (192.168.68.248) — household-wide DNS-level ad/tracker blocking
- 🔌 **Pi1 backup mirror** — DietPi on a Raspberry Pi at an off-site location, on Tailscale, pulls git backups weekly + runs a custom 3.5" SPI TFT dashboard
- 📺 **Media** — Plex + Jellyfin
- 🎮 **Frigate + Local ALPR** — license plate recognition off two Tapo cameras

---

## 🌐 Network

Single unified `192.168.68.0/22` subnet (migrated from dual-subnet Feb 2026). IP scheme:

| Range | Purpose |
|---|---|
| `.249-.250` | Proxmox hosts |
| `.248` | magic-pihole DNS |
| `.100-.199` | VMs |
| `.61-.99` | LXC containers + service hosts |
| `.50-.79` | IoT, cameras, mobile devices |

**Access layers:**
- **LAN-direct** (same network) — fastest, no extra layer
- **Tailscale** (`hostname-ts`) — survives DNS hiccups, works from anywhere
- **Twingate tunnel** — fallback when Tailscale or Twingate-only resources are needed

See [`docs/twingate-pihole-setup.md`](docs/twingate-pihole-setup.md) for the zero-trust setup walkthrough.

---

## 📚 Documentation

| Doc | What's in it |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | Source of truth — overview, current status, network cheat sheet |
| [`docs/build-plan.md`](docs/build-plan.md) | Original build plan with budget breakdown |
| [`docs/homelab-planning-guide.md`](docs/homelab-planning-guide.md) | Planning checklist for spinning up a similar lab |
| [`docs/proxmox-ceph-cluster-guide.md`](docs/proxmox-ceph-cluster-guide.md) | Two-node Proxmox + Ceph setup, including pitfalls |
| [`docs/linux-os-comparison.md`](docs/linux-os-comparison.md) | OS selection writeup: Ubuntu, Debian, Arch, Proxmox-as-host, TrueNAS, Unraid |
| [`docs/llm-homelab-research-2025.md`](docs/llm-homelab-research-2025.md) | VRAM math + GPU selection for local LLMs at long context |
| [`docs/pihole-setup.md`](docs/pihole-setup.md) | Pi-hole on a dedicated Pi — config, blocklists, household rollout |
| [`docs/twingate-pihole-setup.md`](docs/twingate-pihole-setup.md) | Twingate zero-trust + Pi-hole resolver integration |
| [`docs/twingate-ssh-privileged-access-cutover.md`](docs/twingate-ssh-privileged-access-cutover.md) | Cutover notes from password-SSH → Twingate privileged-access mode |
| [`docs/gaming-vm-plan.md`](docs/gaming-vm-plan.md) | Windows-VM-on-Proxmox plan (GPU passthrough, RDP, Samba game library) |
| [`docs/changelog.md`](docs/changelog.md) | Full session-by-session changelog (every change documented) |

---

## 💸 Budget

Starter build came in around **$2,200** (used + new mix). Full breakdown in [`docs/build-plan.md`](docs/build-plan.md).

Most expensive single item: the second Proxmox node + M4000 GPU for AI passthrough.
Cheapest: the Raspberry Pi running Pi-hole.

---

## 🏗️ Architecture

```
┌──────────────────────── 192.168.68.0/22 LAN ───────────────────────┐
│                                                                    │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐          │
│  │ prox-book5   │    │ prox-tower   │    │ magic-pihole │          │
│  │ (laptop)     │    │ (mini-PC)    │    │ (RPi)        │          │
│  │ .250         │    │ .249         │    │ .248         │          │
│  └──────┬───────┘    └──────┬───────┘    └──────────────┘          │
│         │                   │                                      │
│  ┌──────┴────────┐    ┌─────┴──────┐                               │
│  │ VM Omarchy    │    │ VM Ubuntu  │   ┌──────────────┐            │
│  │ .100          │    │ .101       │   │ CT trans     │            │
│  │ (Arch desktop)│    │ (Ollama,   │   │ .65 (LXC)    │            │
│  └───────────────┘    │  Plex,     │   └──────────────┘            │
│                       │  Jellyfin, │                               │
│                       │  Frigate)  │                               │
│                       └────────────┘                               │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
                              │
            ┌─────────────────┴─────────────────┐
            │                                   │
       ┌────┴────┐                       ┌──────┴──────┐
       │ Twingate│ (zero-trust SSH)      │  Tailscale  │ (mesh, 100.x)
       └─────────┘                       └─────────────┘
            │                                   │
            └─────────────► Off-site Pi1 ◄──────┘
                       (DietPi, git mirror,
                        SPI TFT dashboard)
```

---

## 🚀 If you want to build similar

1. Start with the [`homelab-planning-guide.md`](docs/homelab-planning-guide.md) — defines the questions before the gear
2. Use [`linux-os-comparison.md`](docs/linux-os-comparison.md) to pick the OS layer (TL;DR: Proxmox if you want VMs, Ubuntu Server if you don't)
3. Budget breakdown in [`build-plan.md`](docs/build-plan.md). Aim cheaper than you think — most of the value is in the layout, not the silicon
4. Set up Tailscale BEFORE Twingate. Tailscale gives you "works from anywhere" instantly; Twingate is the polish layer for finer-grained zero-trust
5. Pi-hole = household pressure relief. Single biggest "quality of life" improvement vs spend ratio

Open issues, ideas, build advice → [Issues tab](https://github.com/jaded423/homeLab/issues) on this repo.

---

## 🤖 AI-assisted, end-to-end

Documentation maintained through dialogue with Claude (Anthropic). Every session's changes flow through `/log` → `docs/changelog.md`. Status block in [`CLAUDE.md`](CLAUDE.md) is the single source of current-state truth.

Same approach behind everything at [jadedviber.com](https://jadedviber.com).

---

## 🔗 Resources

- Lab status page on my site: [jadedviber.com/homelab](https://jadedviber.com/homelab.html)
- Live build log: [jadedviber.com/now](https://jadedviber.com/now.html)
- Paired with [`nvimConfig`](https://github.com/jaded423/nvimConfig) (editor) + [`terminalConfig`](https://github.com/jaded423/terminalConfig) (tmux/sesh) + [`gspace`](https://github.com/jaded423/gspace) (MCP) — full stack lives on these nodes

---

## 📝 License

MIT — see [LICENSE](LICENSE)

---

<div align="center">

```
$ ssh book5
[motd] welcome to the lab
```

*<sub>maintained by [@jaded423](https://github.com/jaded423) · documented end-to-end through dialogue with AI · cyberpunk-styled · monospace everything</sub>*

**[jadedviber.com](https://jadedviber.com)** · *All vibe. No grind.* 🐍

</div>
