---
type: component
title: go
tags: [pixelbook, cachyos, arch, hyprland, roaming, static-ip, networkmanager, twingate]
related: [dns-adblocking, access-model, mac, pc, phone, s9-tablet, s10, network-topology]
host: go
ip: 192.168.68.247
---

# go (Pixelbook Go)

Google Pixelbook Go (Intel Core m3, 8 GB) running **CachyOS** (Arch-based) with Hyprland.
A roaming laptop — reachable on the tailnet from any network, sibling of [[mac]] [[pc]]
[[phone]] [[s9-tablet]] [[s10]].

- **Access:** `ssh go` — **Tailscale** (bare alias, works anywhere via MagicDNS). `ssh go-local`
  = LAN direct. Full model → [[access-model]].
- **IP:** static **192.168.68.247** (client-side NetworkManager, since 2026-06-28).
- **Booting:** dev-mode SeaBIOS — at the white "OS verification is OFF" screen press **Ctrl+L**
  (legacy boot), then **1** at the blank white screen. Waiting / Ctrl+D boots ChromeOS instead.
- **Keyboard (Kinesis Adv360 Pro):** Mode 1 = [[mac]], Mode 2 = Go.

> NOTE: the deep doc's access model (Twingate Client + reverse SSH tunnel on book5 port 2244)
> is **superseded**. Per the authoritative current state (2026-05-27 SSH inversion), the book5
> reverse tunnels for pc/wsl/go were dropped — Go is reached **direct over Tailscale** now.
> The reverse-tunnel systemd service history is kept under [[access-model]].

## Kernel — dual CachyOS (rolling + LTS)

CachyOS **rolling** is the daily driver; **LTS is kept as a fallback**. NM profiles live in
`/etc` so they are **kernel-independent** — a network fix applied under one kernel carries to
the other.

| Kernel | Role |
|--------|------|
| `7.1.2-cachyos` (rolling) | Primary — wifi works |
| `6.18.x-cachyos-lts` | Fallback |

> NOTE: the deep doc lists kernels `6.18.13-2-cachyos-lts` / `6.19.3-2-cachyos` (Jan 2026
> setup). Authoritative current state (2026-06-28+): rolling `7.1.2-cachyos` + LTS
> `6.18.x-cachyos-lts` fallback.
>
> 2026-06-29: rolling showed a waybar "disconnected" state at Elevated (suspected rolling
> radio bug). The **real fix was on LTS** — disabling Twingate (see below) + getting the
> Elevated wifi profile connected. Because NM profiles live in `/etc`, the fix carried to
> rolling: Elevated now connects on **both** kernels. Rolling wifi is **not** broken.

## Network — static IP (client-side NM)

Static IP is set **client-side in NetworkManager** on Go itself (not a router DHCP
reservation).

| Setting | Value |
|---------|-------|
| IP / prefix | `192.168.68.247/22` |
| Gateway | `192.168.68.1` |
| DNS | pihole `192.168.68.248` |

Network-wide DNS / ad-blocking detail → [[dns-adblocking]]. Topology → [[network-topology]].

### Twingate-off fix (off-LAN wifi hang)

When Twingate is running, its `sdwan0` NM connection installs a `~.` (catch-all) DNS domain
routing **all** lookups to Twingate's internal resolvers `100.95.0.x`. Those resolvers are
**dead when off-LAN**, so DNS breaks and wifi appears "disconnected" (e.g. at the Elevated
office). **Fix: disable Twingate on Go.** After disabling TW + connecting the Elevated wifi
profile, Go connects reliably on both kernels.

This is the same `sdwan0` DNS-hijack pattern seen on [[book5]] — full explanation and the
book5 auto-remediation hook live in [[dns-adblocking]].

### WiFi profiles

NM connection profiles are stored in `/etc/NetworkManager/system-connections/` (root-owned,
kernel-independent). Notable profile: **Elevated** (office wifi) — connects on both rolling
and LTS after the Twingate-off fix.

```bash
nmcli connection show                 # list profiles
nmcli connection up <profile>         # connect a wifi profile
nmcli device wifi list                # scan
ip addr show wlan0                    # confirm static 192.168.68.247/22
```

## SSH config

### On Go (`~/.ssh/config`) — reaching the homelab
```ssh-config
# Proxmox Node 1 - prox-book5
Host book5 prox-book5
  HostName 192.168.68.250
  User root

# Proxmox Node 2 - prox-tower
Host tower prox-tower
  HostName 192.168.68.249
  User root

# VM 101 - Ubuntu Server (via tower)
Host ubuntu ubuntu-server vm101
  HostName 192.168.68.101
  User jaded
  ProxyJump tower

# Mac (direct - mDNS)
Host mac macbook
  HostName macAir.local
  User j
```

### On [[mac]] — reaching Go
`ssh go` resolves over Tailscale MagicDNS (primary, anywhere); `ssh go-local` = `go.local`
mDNS on LAN. See [[access-model]] for the full roster.

## Power management

### Lid behavior
`/etc/systemd/logind.conf.d/lid-switch.conf`:
```ini
[Login]
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=ignore
```

| Condition | Behavior |
|-----------|----------|
| AC + lid closed | Stays awake |
| Battery + lid closed | Sleeps (saves battery) |

### WiFi power save (auto-toggle by AC state)
Script `/usr/local/bin/wifi-power-manager`:
```bash
#!/bin/bash
AC_ONLINE=$(cat /sys/class/power_supply/AC/online 2>/dev/null)
if [ "$AC_ONLINE" = "1" ]; then
    iw dev wlan0 set power_save off
else
    iw dev wlan0 set power_save on
fi
```
Udev rule `/etc/udev/rules.d/99-wifi-power.rules`:
```
ACTION=="change", SUBSYSTEM=="power_supply", RUN+="/usr/local/bin/wifi-power-manager"
```

| Condition | WiFi Power Save |
|-----------|-----------------|
| On AC | OFF (stable connection) |
| On Battery | ON (saves power) |

Check / force: `iw dev wlan0 get power_save` · `sudo iw dev wlan0 set power_save off`.

## Desktop / software

CachyOS + **Hyprland 0.53.3**. Config at `~/.config/hypr/hyprland.conf`.

| Component | Value |
|-----------|-------|
| DE / WM | Hyprland |
| Shell | zsh + oh-my-zsh + powerlevel10k (Arch-adapted, standalone — NOT symlinked from zshConfig) |
| Terminal | ghostty (default) — Catppuccin Mocha, opacity 0.90, MesloLGS Nerd Font 12, decorations off |
| Editor | neovim (`~/.config/nvim`, cloned from nvimConfig repo) |
| Bar / launcher | waybar / hyprlauncher |
| Multiplexer | tmux + sesh (`t` alias); configs copied from [[mac]], Linux-adapted (`ping -W2`) |
| VPN | twingate (**disabled** — see Twingate-off fix) |

### Hyprland keybindings
| Keys | Action |
|------|--------|
| SUPER + Q | Terminal (ghostty) |
| SUPER + R | Launcher (hyprlauncher) |
| SUPER + C | Close window |
| SUPER + E | File manager (thunar) |
| SUPER + 1-9 | Switch workspace |
| SUPER + SHIFT + 1-9 | Move window to workspace |
| 3-finger swipe | Switch workspaces |

**Fixes applied:** phantom `Unknown-1` monitor disabled in config; gesture syntax updated to
Hyprland 0.53+ format; default shell changed fish → zsh for SSH sessions.

### tmux / sesh
Prefix = `Ctrl+Space`. `prefix + S` = sesh picker (fzf popup), `prefix + s` = tmux tree
chooser, `t` = `sesh connect "$(pwd)"`. Configs: `~/.config/tmux/tmux.conf`,
`~/.config/sesh/sesh.toml`. Plugins via TPM (catppuccin, vim-tmux-navigator, battery, yank,
online-status, resurrect, continuum, sensible).

## Troubleshooting

### Can't reach homelab from Go
```bash
tailscale status                # Go reaches homelab over Tailscale (primary)
# if the Elevated wifi hangs / DNS broken, disable Twingate (sdwan0 DNS hijack — see above)
```

### mDNS not resolving (`macAir.local`)
```bash
systemctl status avahi-daemon
avahi-resolve -n macAir.local
```

### WiFi drops when lid closed
Power save should be OFF on AC: `iw dev wlan0 get power_save` → `sudo iw dev wlan0 set power_save off`.

## Sources
- `~/.claude/docs/homelab/go.md` (deep doc)
- `~/projects/homeLab/CLAUDE.md` "Operational Current State" (authoritative, line 60)
