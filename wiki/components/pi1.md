---
type: component
title: Pi1 @ Elevated
host: pi1
ip: 100.98.16.63
tags: [raspberry-pi, dietpi, git-backup, tailscale, elevated-office, tft]
related: [access-model, push-all, pc]
---

# Pi1 @ Elevated

Raspberry Pi 1 Model B+ running **DietPi-Bookworm** (ARMv6; cutover from Raspbian
2026-05-12). Sits at the Elevated office as an offsite **git backup mirror** — one of
three remotes for the user's repos alongside GitHub + Gitea. Has a 3.5" SPI TFT running
a custom `hub` dashboard. No Wi-Fi: internet rides the host machine's ICS, but Tailscale
reachability is host-independent.

## Access

```bash
ssh pi1            # Tailscale — works from anywhere with Tailscale on
ssh rpi1           # Alias
```

Default user `root` (DietPi convention). Tailscale IP `100.98.16.63` is stable across
host swaps. Full model → [[access-model]].

## Git Backup Mirror

| Property | Value |
|----------|-------|
| Location | `~/git-mirrors/*.git` (root user; DietPi defaults user to root) |
| Repos | 15 bare repositories |
| Size | ~152 MB |
| Updates | Weekly push from Mac via the `push-all` skill (pushes to GitHub + Gitea + Pi1) |

**Historical:** the old 4-hourly cron (`~/git-mirrors/sync-mirrors.sh` pulling *from*
GitHub) was retired 2026-05-12 when the workflow shifted to push-from-Mac. The script is
kept on disk for reference but is not invoked.

## Custom Dashboard: `hub`

Python + rich script at `/usr/local/bin/pi1-hub` (source on Mac at
`~/Desktop/pi1-dietpi/hub.py`). Aliased to `hub` in `/root/.bashrc`.

```bash
hub   # fullscreen dashboard
# Ctrl-C exits to shell
```

Renders: CPU bar + temp, RAM bar, Swap bar, 1/5/15-min load average; Network (eth0 IP,
Tailscale IP + state, live ↓/↑ KB/s); Storage (root used/total % bar, `git-mirrors` dir
size); Service dots for tailscaled, ssh, cron. Bar colors: green <60%, yellow <85%, red
≥85%. Refresh: 2s.

**Tweaking layout:** edit `~/Desktop/pi1-dietpi/hub.py` on Mac, then
`scp hub.py pi1:/usr/local/bin/pi1-hub && ssh pi1 chmod +x /usr/local/bin/pi1-hub`.

## TFT Screen

Hosyond 3.5" SPI TFT (480×320, ILI9486 + XPT2046) — a Waveshare 35a **clone**, not
genuine. Same physical unit that previously lived on pi-office (now pi-mom).

**Critical:** the in-tree `ili9486` tinydrm driver does NOT work on this clone (solid
white). Must use the custom fbtft overlay `waveshare35a.dtbo` (compiled from
[swkim01/waveshare-dtoverlays](https://github.com/swkim01/waveshare-dtoverlays)). Known-good
`.dtbo` lives at `/boot/firmware/overlays/waveshare35a.dtbo` on pi1; source backup at
`~/Desktop/pi1-dietpi/screen/waveshare35a.dts.src` on Mac + on pi-mom.

Config:
- `/boot/firmware/config.txt`: `dtparam=spi=on` + `dtoverlay=waveshare35a:rotate=270`
- `/boot/firmware/cmdline.txt` (appended): `consoleblank=0 fbcon=map:10`
- Console font: Terminus 8×16 (`FONTFACE="Terminus"` + `FONTSIZE="8x16"` in
  `/etc/default/console-setup`) — ~60×20 chars at 480×320

Rotation `270` (not `90`) because the Pi 1B+ must physically lay a specific way for the
keyboard/network cables to clear. Log in on the TFT directly with a USB keyboard — same
`root` / `1234` credentials.

## Network & Internet (ICS-dependent)

Pi1 has **no Wi-Fi/Bluetooth** — it routes through whichever host machine it's
USB-Ethernet plugged into, via that OS's Internet Connection Sharing. Currently usually
plugged into the [[pc]] (Elevated office), occasionally Mac (home).

- **Tailscale**: `100.98.16.63` — stable across host swaps (host-independent reachability)
- **ICS subnet**: `192.168.137.x` (Windows ICS) or `192.168.2.x` (macOS Internet Sharing) — drifts with DHCP
- **Gateway**: `192.168.137.1` (Windows) or `192.168.2.1` (Mac) — the host's ethernet adapter

Internet still requires PC (or Mac) powered on; only Tailscale reach is host-independent.
Pi1 is **not reachable by LAN IP** from outside its ICS subnet.

## Login Credentials

| User | Password |
|------|----------|
| root | `1234` (temporary — local-only Pi, minimal access) |
| dietpi | `1234` |

The `AUTO_SETUP_GLOBAL_PASSWORD` field in `dietpi.txt` did NOT apply during first-boot for
this cutover — the password had to be set manually via `chpasswd` over SSH. If reflashing,
plan to set passwords post-boot, not via dietpi.txt.

## Hardware

| Component | Details |
|-----------|---------|
| Model | Raspberry Pi 1 Model B+ |
| CPU | ARM1176JZF-S (ARMv6, 700 MHz single-core) |
| RAM | 512 MB (475 MB usable) |
| Storage | 8 GB SD card |
| Network | 10/100 Ethernet (no Wi-Fi, no Bluetooth) |
| Display | 3.5" SPI TFT (Hosyond, ILI9486 + XPT2046, 480×320) |
| Power | 5V micro-USB |

## Swap

512 MB swapfile at `/var/swap` (down from DietPi's default 1.5 GB / 3× RAM). Set via
`/boot/dietpi/func/dietpi-set_swapfile 512 /var/swap` and persisted in `/boot/dietpi.txt`
(`AUTO_SETUP_SWAPFILE_SIZE=512`). SD-card swap is slow on ARMv6 — fine for occasional
overflow, don't rely on it for active workloads.

## Useful Knobs

- **Prefix history search**: `/root/.inputrc` binds up/down arrows to
  `history-search-backward`/`forward` — type a prefix, then up to walk matching commands.
- **Ghostty terminfo**: pushed via `infocmp -x xterm-ghostty | ssh pi1 'tic -x -'` to
  silence DietPi's "Unsupported SSH client terminal" warning when SSHing from Ghostty.
- **`dietpi-config`**: interactive menu for system tweaks (network, swap, services).
- **`dietpi-software`**: menu for adding/removing packages (Tailscale ID is 175).

## Common Commands

```bash
ssh pi1                    # SSH in
ssh pi1 hub                # Launch dashboard remotely (use in a clean tmux split)
ssh pi1 'tailscale status'
ssh pi1 'systemctl status tailscaled'
ssh pi1 'free -h'          # RAM/swap snapshot
ssh pi1 'df -h /'          # Disk
ssh pi1 reboot             # Reboot
```

## Sources

- `~/.claude/docs/homelab/pi1.md` (deep doc)
- `~/projects/homeLab/CLAUDE.md` → "Operational Current State" (line 94, Pi1 @ Elevated)
