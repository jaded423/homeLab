---
type: concept
title: Troubleshooting — symptom → fix + setup recipes
tags: [troubleshooting, ssh, sudo, twingate, ollama, watchdog, gpu, hardware, setup, maintenance, backup]
related: [dns-adblocking, watchdogs, gpu-passthrough, mullvad, access-model, book5, tower, vm101-ubuntu, vm100-omarchy, pihole]
---

# Troubleshooting

Recurring homelab problems + their fixes, plus setup/maintenance recipes that don't
belong to a single host. Symptom → fix. Commands are verbatim — the exact command **is**
the reference. When a fix really belongs to another concept page, it's a one-liner + link.
For a fully downed host (unreachable, stuck at login, silent hang), use the
**`homelab-host-recovery` skill** — it walks reachability → web UI → service health →
watchdog logs → kernel forensics → guarded restart per host.

## SSH

### Connection refused
```bash
systemctl status sshd                 # is SSH running
sudo ufw status | grep 22             # firewall allows SSH
sudo ss -tlnp | grep :22              # is it listening
sudo systemctl restart sshd           # restart
```

### Permission denied
```bash
# Fix key permissions on Mac
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub

# Fix authorized_keys on the server
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

Can't reach a host at all (wrong path, not a key problem) → the access model owns which
alias to use: [[access-model]]. `-local` timing out while the bare Tailscale alias works
is **expected when off-LAN**, not a fault.

## Sudo

### Sudo not accepting password
```bash
sudo -v      # prompts for password, resets sudo timestamp, fresh 15-min window
```

### If `sudo -v` doesn't fix it
```bash
groups | grep wheel                            # wheel group membership
sudo -l                                         # sudo config
journalctl -n 100 | grep -iE 'sudo|pam|auth'    # auth errors
```

## Twingate

### After reboot — green but can't connect
**Problem:** connectors show "Connected" but resources are unreachable. **Cause:** Mac
client has stale routing tables.
```bash
# Restart Twingate on Mac
killall Twingate && open -a Twingate
# Or via menu bar: icon → Quit → Reopen
```
May take 5–10 minutes to re-establish routes.

### Connector shows DEAD / can't resolve / ads return network-wide
On [[book5]] the connector goes DEAD_HEARTBEAT_TOO_OLD (while systemd says active) when a
Twingate update recreates `sdwan0` with dead `100.95.0.x` resolvers. This is **auto-remediated**
now (NM dispatcher hook `90-twingate-dns-pin`). The full DNS story + manual fallback lives on
[[dns-adblocking]] — start there for any DNS/adblock/connector-DNS symptom.

### Connector not connecting (generic)
```bash
# Docker deployment
docker ps -a | grep twingate
docker logs twingate-connector

# systemd deployment
systemctl status twingate-connector
journalctl -u twingate-connector -f

systemctl restart twingate-connector
```

### Can't access resources
- Ensure the Twingate app is connected on Mac.
- Check resources are assigned to your user in the admin console (`https://jaded423.twingate.com`).
- Verify the connector is online, then reconnect the app.
- Which resources ride Twingate vs Tailscale → [[access-model]]. Why VM 101 is walled off → [[mullvad]].

## Ollama (on [[vm101-ubuntu]])

### Service not running
```bash
systemctl status ollama
sudo systemctl restart ollama
journalctl -u ollama -f
```

### Slow inference
```bash
lspci | grep -i vga                                              # verify GPU
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor        # CPU governor
htop   # or btop
```

### Out of memory
```bash
free -h                 # RAM/swap
zramctl                 # zram
ollama run llama3.2:1b  # try a smaller model
```

### Model not found
```bash
ollama list
ollama pull modelname:tag
```

## Watchdogs (CPU / network)

Status checks and how to resume a VM the CPU watchdog suspended, tune the threshold, or
disable temporarily — all live on [[watchdogs]] (it owns `cpu-watchdog.sh` and
`network-health-monitor.sh`). Quick pointers:
```bash
systemctl status cpu-watchdog
tail -f /var/log/cpu-watchdog.log
qm list && qm resume <VMID>          # un-suspend a VM the watchdog paused
journalctl -t net-health             # network-health-monitor log
```

## GPU passthrough

VM GPU not showing, `nvidia-smi` failing, interface renamed after passthrough, VRAM-limited
model crashes — the passthrough concept page owns the detail: [[gpu-passthrough]]. Quick checks:
```bash
lspci -nnk -s 01:00        # host: vfio binding
dmesg | grep -i dmar       # IOMMU
lsmod | grep nvidia        # driver loaded in guest
```
> NOTE: the M4000 (Maxwell, 8 GB VRAM) is vfio-bound to [[vm101-ubuntu]]; models >8 GB
> fail. Its NVENC is walled by Maxwell EOL (software x264 fallback). See [[gpu-passthrough]].

## Desktop environment (Hyprland, on [[vm100-omarchy]])

### Waybar not appearing
```bash
pgrep waybar
killall waybar && waybar &
waybar --log-level debug
```

### Wallpaper not changing
```bash
killall hyprpaper && hyprpaper &
cat ~/.config/hypr/hyprpaper.conf
```

### Reload Hyprland
```bash
hyprctl reload
```

## Known hardware issues

### Intel I218-LM NIC bug ([[tower]])
**Problem:** TSO causes network hangs requiring a physical reboot. **Symptoms:** complete
SSH loss, Proxmox web UI unreachable, server unresponsive.
```bash
# /etc/network/interfaces on prox-tower — disable offloads
iface nic0 inet manual
    post-up /usr/sbin/ethtool -K nic0 tso off gso off gro off
```
Verify offloads are off:
```bash
ssh root@192.168.2.249 "ethtool -k nic0 | grep -E 'tcp-seg|generic'"   # expect: off x3
```
> NOTE: the verify command's `192.168.2.249` is **pre-migration historical** — [[tower]]'s
> current IP is `192.168.68.249` (`ssh tower`). On [[tower]] today vmbr0 = Intel I218-LM
> (e1000e, 1G), vmbr1 = Realtek RTL8125 (r8169, 2.5G, primary). netconsole on the bridge
> does **not** work — use the rsyslog forward to [[book5]] (`/var/log/tower-remote.log`)
> to see the last messages before a hang.

## Historical / retired (kept for context)

- **Samba** — the old share-not-accessible / symlinks / slow-transfer recipes are **retired**:
  smbd was disabled on [[book5]] 2026-05-27 (unused, `/root` share security smell). Ignore
  the Samba maintenance commands in older docs.
- **Google Drive rclone mounts** (`rclone-gdrive.service` / `rclone-elevated.service`) and
  **MagicMirror kiosk** (`192.168.2.131`) are pre-migration deep-doc content with no current
  operational role — treat as historical unless re-provisioned.

---

# Setup recipes

Install/config procedures that apply across hosts.

## Proxmox node CLI setup

Standard CLI toolchain for a Proxmox node (installed on [[book5]] + [[tower]], Dec 2 2025):
tmux, zsh (default) + Oh My Zsh + Powerlevel10k, Neovim, Node/npm, deno, fzf, zoxide,
Claude Code.

```bash
# 1. Fix DNS (use Pi-hole)
echo '# Fixed DNS - use Pi-hole' > /etc/resolv.conf
echo 'nameserver 192.168.68.248' >> /etc/resolv.conf
echo 'nameserver 8.8.8.8' >> /etc/resolv.conf

# 2. Base packages
apt update
apt install -y tmux zsh neovim git curl unzip fzf build-essential make

# 3. Oh My Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# 4. Powerlevel10k
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k

# 5. deno, zoxide, Claude Code
curl -fsSL https://deno.land/install.sh | sh
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
curl -fsSL https://claude.ai/install.sh | bash

# 6. Set zsh as default
chsh -s $(which zsh)

# 7. Copy configs from Mac (run on Mac)
scp ~/projects/zshConfig/zshrc root@<proxmox-ip>:~/.zshrc
scp ~/projects/zshConfig/p10k.zsh root@<proxmox-ip>:~/.p10k.zsh

# 8. Clone nvim config
git clone https://github.com/jaded423/nvimConfig.git ~/.config/nvim

# 9. Update PATH
echo 'export DENO_INSTALL="/root/.deno"' >> ~/.zshrc
echo 'export PATH="$DENO_INSTALL/bin:$HOME/.local/bin:$PATH"' >> ~/.zshrc

# 10. Symlinks for immediate access
ln -sf /root/.local/bin/zoxide /usr/local/bin/zoxide
ln -sf /root/.deno/bin/deno /usr/local/bin/deno
ln -sf /root/.local/bin/claude /usr/local/bin/claude
```
Verify, then logout/login to use zsh:
```bash
which zoxide deno claude   # should show /usr/local/bin
```

**Gotchas:**
- **DNS:** Twingate may manage `/etc/resolv.conf` with broken DNS — set Pi-hole first (step 1). Broader DNS story → [[dns-adblocking]].
- **PATH:** curl-installed tools land in `~/.local/bin`; the symlinks fix immediate access.
- **Claude Code:** needs browser auth on first run — SSH from Mac to authenticate.
- **Nvim plugins:** first open, Lazy.nvim auto-installs (~1 min).

## Setup scripts reference (`~/setup/` on the server)

| Script | Purpose |
|--------|---------|
| `install-docker.sh` | Install Docker + Compose |
| `install-twingate-docker.sh` | Install Twingate via Docker |
| `setup-ssh.sh` | Enable/configure SSH |
| `setup-samba.sh` | Install/configure Samba *(Samba retired 2026-05-27)* |
| `configure-firewall.sh` | Configure UFW |
| `update-samba-symlinks.sh` | Enable symlink support *(retired)* |

Config files: `docker-compose.yml` (Twingate container, 644), `.env` (Twingate creds, 600),
`twingate-tokens.sh` (token export, 644).

## Maintenance tasks

```bash
# Daily
systemctl status sshd && docker ps
df -h /

# Weekly
sudo pacman -Syu            # update system (Arch/CachyOS host)
journalctl -p err -b        # check errors

# Monthly
sudo ufw status verbose                          # review firewall
docker-compose pull && docker-compose up -d      # update images
sudo pacman -Sc                                  # clean cache
```
> NOTE: older docs listed `smb` in the daily `systemctl status` — dropped (Samba retired).

## Backup strategy

Important dirs: `~/setup/`, `~/.config/`, `~/.ssh/`, `/etc/samba/` *(last one now moot)*.
```bash
# Backup setup dir from Mac
scp -r jaded@192.168.68.250:~/setup ~/backups/homelab-setup-$(date +%Y%m%d)

# Backup configs from Mac
ssh jaded@192.168.68.250 'tar czf - ~/.config/hypr ~/.config/waybar ~/.ssh' \
  > ~/backups/homelab-configs-$(date +%Y%m%d).tar.gz
```

## System updates

```bash
# CachyOS / Arch
sudo pacman -Syu        # full update
sudo pacman -Syyu       # force refresh
yay -Syu                # AUR packages

# Docker
cd ~/setup
docker-compose pull
docker-compose up -d
```

## Sources

- `~/.claude/docs/homelab/troubleshooting.md` (deep doc — migrated)
- `~/.claude/docs/homelab/setup-guides.md` (deep doc — folded into Setup recipes)
- `~/projects/homeLab/CLAUDE.md` lines 45–119 (Operational Current State, authoritative — retirements, current IPs, watchdog/GPU/DNS ownership)

## tmux detach storm (2026-06-12, unsolved)

point4 client detached every couple seconds for several minutes, then stopped on its own. **Ruled out:** the Claude session inside point4 (zero tmux refs in transcript), tmux-resurrect backup agent, cron, Music/Hammerspoon relaunch loop, rogue tmux processes (live sampler clean). Not the 2026-02-27 background-process incident pattern.

**If it recurs:** check `/tmp/tmux-detach.log` for timestamps (the detach-logger hooks are left armed but die with a tmux server restart — re-arm below); check Ghostty tab health (a client SIGHUP looks identical to a detach from inside tmux); note what each Claude window was doing.

```bash
# Re-arm tmux detach logger (after any tmux server restart)
tmux set-hook -g client-detached 'run-shell "echo \"$(date +%H:%M:%S) detached: #{hook_client} session=#{hook_session_name}\" >> /tmp/tmux-detach.log"'
tmux set-hook -g client-attached 'run-shell "echo \"$(date +%H:%M:%S) attached: #{hook_client}\" >> /tmp/tmux-detach.log"'
```

Tracked as an open item in `~/projects/homeLab/TODO.md`. (Migrated out of global `~/.claude/CLAUDE.md` 2026-07-07 by `/sum` one-home audit.)
