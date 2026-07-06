---
type: component
title: vm100-omarchy
tags: [vm, omarchy, arch, hyprland, n8n, sunshine, game-stream, tower-guardian]
related: [book5, gpu-passthrough, access-model, tower]
host: omarchy
ip: 192.168.68.100
---

# vm100-omarchy (VM 100)

Arch Linux / Hyprland desktop VM. Hosted on [[book5]] (VMID 100). Doubles as a
game-stream rig (Sunshine) and the home of the n8n / Tower-Guardian automation stack.

- **Access:** `ssh omarchy` — **Tailscale direct** (own tailnet IP, no ProxyJump). `ssh omarchy-local` for LAN. Full model → [[access-model]].
- **iGPU:** book5's Intel Arc (Lunar Lake) is passed through for Sunshine hardware encode → [[gpu-passthrough]].

## VM Config

| Property | Value |
|----------|-------|
| VMID | 100 |
| Host | [[book5]] (prox-book5) |
| RAM | 12 GB (fixed 11264 MB, balloon DISABLED) |
| vCPU | 4 cores |
| Disk | 32 GB (book5 local-zfs) |
| Network | vmbr1, `ens18` 192.168.68.100/22, gw 192.168.68.1 |
| iGPU | Intel Arc 130V/140V (Lunar Lake) passthrough → [[gpu-passthrough]] |

> NOTE: deep doc says RAM 12GB w/ VirtIO GPU + `linux-lts`; CLAUDE.md/brain (authoritative) pin RAM to **fixed 11264 MB, balloon disabled** (ballooning crushed the guest under game load), and the iGPU is **passed through** (not VirtIO). qemu-guest-agent installed (`qm agent 100 ping` OK). `sudo reboot` inside the guest wedges (dead CIFS mount + GPU warm-reset) → cold-cycle from book5 for config changes.

## System

| Component | Value |
|-----------|-------|
| OS | Arch Linux (rolling) |
| DE / WM | Hyprland |
| Shell | zsh (oh-my-zsh + powerlevel10k) |
| Terminal | kitty |
| Editor | neovim |
| Bar / launcher | waybar / walker |
| User | `jaded` (passwordless sudo) |

### Config files

| File | Purpose |
|------|---------|
| `~/.config/hypr/hyprland.conf` | Hyprland config |
| `~/.config/kitty/kitty.conf` | Terminal config |
| `~/.config/nvim/` | Neovim config |
| `~/.zshrc` | Shell config |
| `~/.local/share/omarchy/default/hypr/` | Omarchy default Hypr configs (windowrules) |

## Services

| Service | Port | Web UI (MagicDNS) | Notes |
|---------|------|-------------------|-------|
| n8n | 5678 | `http://omarchy:5678` | Workflow engine (Tower-Guardian stack) |
| Sunshine | 47990 | `https://omarchy:47990` | Game-stream host (uses passed-through iGPU) |
| Ollama | 11434 | `http://192.168.68.100:11434` | Local LLM (Llama 3.1 8B, 4.9 GB) — Tower-Guardian stack |

Web UIs reachable over Tailscale MagicDNS (see [[access-model]]).

### Sunshine / game-stream
Sunshine game-stream host on `:47990`, encoding via the passed-through Intel Arc iGPU.
Hardware VAAPI encode is RESTORED (`encoder = vaapi`; the 0000300C import bug is gone on
kernel 7.0.3 / mesa26 / iHD26.1.5; HuC running; `CAP_SYS_NICE` made permanent via a pacman
hook). Any remaining stutter is client-side (hotspot/fps/bitrate), not the host.
Full iGPU detail → [[gpu-passthrough]].

### Tower Guardian (n8n + Ollama)
AI-assisted health-monitor stack in `~/docker/tower-guardian/` (docker-compose: n8n +
ollama). Monitors the Windows PC heartbeat and can power-cycle it via IFTTT → Tapo P105
smart plug.

```bash
cd ~/docker/tower-guardian
docker compose up -d          # start stack
docker compose down           # stop stack
docker ps                     # status
docker logs n8n               # n8n logs
docker logs ollama            # ollama logs
docker exec -it ollama ollama run llama3.1:8b   # chat with local LLM
```

**PC Health Monitor workflow (v2.1)** — active; checks every 5 min (warn 10–30 min stale,
critical >30 min), max 2 reboots, 15-min cooldown, power via IFTTT → Tapo plug. State files
in the n8n container `/home/node/.n8n/`: `pc_heartbeat.txt`, `pc_reboot_count.txt`,
`pc_last_reboot.txt`.

PC sends heartbeat via:
```bash
ssh book5 "curl -s -X POST http://192.168.68.100:5678/webhook/pc-heartbeat"
```

**Gotcha:** IFTTT returns HTTP 200 even for *disconnected* applets — if monitoring silently
stops, check https://ifttt.com/my_applets (applets can disconnect with no API-visible
indication). Docker volumes: `tower-guardian_n8n_data` (workflows/creds),
`tower-guardian_ollama_data` (models).

## Package management

```bash
sudo pacman -Syu          # update system
sudo pacman -S <package>  # install
pacman -Ss <query>        # search
sudo pacman -Sc           # clean cache
```

## Troubleshooting

### Can't SSH in
```bash
ssh book5 "qm status 100"                              # is VM running?
ssh book5 "qm start 100"                               # start it
ssh book5 "qm guest cmd 100 network-get-interfaces"    # check network
```
No display after boot → console via Proxmox web UI: `https://prox-book5:8006` → VM 100 → Console.

### Hyprland windowrule syntax errors (deprecated)
**Symptom:** waybar shows `windowrulev2 is deprecated` / `invalid field class:^(...)$`.
**Cause:** Hyprland 0.53+ replaced inline `windowrule = effect, class:regex` with a `windowrule { }` block format; Omarchy's default configs lag behind.

New (v3) block syntax:
```
windowrule {
    name = steam-float
    match:class = steam
    match:title = Steam
    float = yes
}
```
Key changes: `windowrulev2` keyword removed; inline form dead; blocks use `name =`,
`match:<field> =` (class/title/tag/float/initial_title/xwayland/fullscreen/pin), snake_case
effects (`stay_focused`, `keep_aspect_ratio`, `idle_inhibit`, `no_dim`, `border_size`, …),
booleans as `= yes`.
**Files affected:** `~/.local/share/omarchy/default/hypr/windows.conf` + all `.conf` under
`~/.local/share/omarchy/default/hypr/apps/`. A Python conversion script was written/run
(cached `/tmp/convert_windowrules.py`, lost on reboot).
**Reload:** `HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/*/hypr/) hyprctl reload`.
Last applied 2026-03-16 (Hyprland 0.54.1).

### Hyprland not starting
```bash
journalctl --user -u hyprland
cat ~/.local/share/hyprland/hyprland.log
```

> NOTE: the deep doc lists a `~/.ssh/config` `ProxyJump book5` block for omarchy — this is
> **stale**. Per the authoritative current state (2026-05-27 SSH inversion), omarchy is now
> reached **direct over Tailscale**; ProxyJump was dropped. See [[access-model]].

## Sources
- `~/.claude/docs/homelab/omarchy.md` (deep doc)
- `~/projects/homeLab/CLAUDE.md` "Operational Current State" (authoritative, lines 45–119)
