# HomeLab Project Changelog

## 2026-05-20 → 2026-05-21 - Home Assistant deployed on tower (VM 112) with porch cam watchdog

### Outcome
- HA OS 17.3 running on tower as **VM 112** at **192.168.68.111** (DHCP reservation for MAC `bc:24:11:94:b8:9a`)
- Replaces the IFTTT-based porch cam watchdog (Hubspace plug control was the gap — IFTTT has no Hubspace service, only Tapo)
- Tower watchdog migration is deferred (HA on tower can't watch tower; see Follow-up)

### Why on tower instead of book5
- First attempt was on book5 as VM 111. Book5 hung mid-deploy from userspace OOM (VM 100 omarchy still at 10GB, HAOS first-boot I/O storm pushed it over). ICMP answered, sshd/pveproxy wedged, required physical power-cycle (no remote access).
- Moved to tower. Used VMID 112 because the partial book5 VM 111 record is cluster-wide locked until book5 is recovered and `qm destroy 111` runs.
- Saved memories: `book5-oom-during-vm-deploy.md`, `tower-hang-kernel-pin-not-root-cause.md`, `ha-book5-watchdog-plan.md`.

### Infrastructure changes on tower
- New ZFS dataset `media-pool/vm-disks` → registered as Proxmox storage `media-pool-vm` (zfspool, images+rootdir). Chose this over `local-zfs-tower` (82% full → would push to 91% with HA disk). media-pool already has precedent for non-media datasets (`media-pool/ollama`).
- VM 101 ubuntu-server **trimmed from 64GB → 36GB RAM** via virtio_balloon. Module wasn't loaded in the guest (Proxmox set ballooning target but guest ignored it); loaded with `modprobe virtio_balloon` + persisted via `/etc/modules-load.d/virtio_balloon.conf`. Actual working set in VM 101 was ~7.6GB so 36GB is still 4x headroom.
- VM 112 spec: 4GB RAM, 32GB disk on `media-pool-vm`, q35 machine type, OVMF UEFI **without** pre-enrolled MS keys (`pre-enrolled-keys=0`). Tried SeaBIOS first to skip OVMF debugging — HAOS image is UEFI-only, doesn't boot under SeaBIOS. SB-disabled OVMF works.

### Integrations deployed inside HA
- **HACS** (community store) via SSH addon (Advanced SSH & Web Terminal). Addon required `username: root` because we enabled SFTP — that's a hard requirement of the addon, not a choice.
- **Hubspace** (`jdeath/Hubspace-Homeassistant`, in HACS default repos now). Discovered 6 devices including the dual-outlet outdoor plug HPPA52CWBA023 ("Lights" device, Outside area). Outlet 2 = porch camera = `switch.lights_outlet_2` (friendly name "Porch Camera"). Note: entity_id is generated from device+outlet number, not the friendly name — renaming via UI doesn't change the entity_id, integration regenerates it on reload.
- **Frigate** (blakeblackshear, in HACS default repos). Created 4 devices (Frigate server + 3 cams: Tapo Porch, Tapo 360 Living Room, Plate Zone) but ZERO entities until MQTT was wired up.
- **MQTT**. The non-obvious gotcha: Frigate's HA integration is a discovery/topic listener — without MQTT pointing at Frigate's broker (mosquitto on VM 101 at 192.168.68.101:1883, anonymous), the Frigate devices stay empty. First attempt accidentally picked the "Mosquitto Mqtt Broker app" option which would install HAOS's own bundled broker (separate from VM 101's, would not see Frigate's topics). Removed that, re-added MQTT with "Manually enter broker details" → 192.168.68.101:1883, blank user/pass. Entity count jumped from ~20 (Hubspace + a few HA core) to 118 within seconds.

### Porch cam watchdog automation
- ID `porch_cam_watchdog`, friendly name "Porch cam offline → power cycle plug"
- Trigger: `camera.tapo_porch` state = `unavailable` for 2 minutes
- Action: `switch.lights_outlet_2` off → 10s delay → on → TTS to `media_player.family_room_speaker` (Google Nest Mini, auto-discovered by Google Cast integration)
- Mode: single
- Created via REST API POST to `/api/config/automation/config/porch_cam_watchdog`, then `services/automation/reload`. Verified plug toggles cleanly (off→on tested live during creation — actually power-cycled the cam, came back in ~30s).

### Access plumbing
- Long-lived access token created in HA → stored at `tower:/root/ha-emergency-kit/ha-token-claude.txt` (perms 600)
- HA emergency-kit backup file (the encryption key for HA backups) copied to `tower:/root/ha-emergency-kit/` and `ubuntu:~/ha-emergency-kit/` (perms 600 each). Mac copy deleted by user. 1Password also has it.
- Mac SSH config: added `Host ha` block with `ProxyJump tower` (Twingate intercepts 192.168.68.0/22 from Mac, same workaround as `ssh ubuntu`). `ssh ha` → root@HAOS SSH addon container.
- Twingate resource `homeassistant` (alias `ha.lab`) created pointing at 192.168.68.65, needs updating to 192.168.68.111 (IP moved when we set the DHCP reservation).

### Issues hit and resolved
- **DNS dead on book5** at start of the deploy: `/etc/resolv.conf` listed only Twingate's 100.95.0.x resolvers, which were unresponsive. Fixed in a parallel session by repointing sdwan0's NM connection at pihole (see 2026-05-20 sister entry). `network-health-monitor.sh` patched to also probe DNS — previously logged "green" through the outage because it only checked ICMP+socket+systemctl.
- **VM 112 boot looked black-screen at first**. Screen dumps showed `\0`-only pixels which I mistook for OVMF hanging. Actually HAOS was booting normally; first-boot Supervisor container pulls take 5-15min and the screen sits on "Waiting for the Home Assistant CLI to be ready" for most of it. Got fooled twice (book5 + tower) before checking the screen content properly.
- **VM 112 IP drifted from .65 → .67 → .111** as we added DHCP reservation. HAOS internal "reboot" only restarts containers, not the OS — had to `qm shutdown 112 && qm start 112` to force a fresh DHCP lease grab.

### Follow-up
- **HA-book5 watchdog still pending.** Need a second small HA (2GB/32GB, Tapo integration only) on book5 to watch tower. Plan saved at `~/.claude/projects/-Users-j-projects-homeLab/memory/ha-book5-watchdog-plan.md`. Blocked on book5 being healthy (currently hung from this incident) + VM 100 trim to 6GB.
- **Retire IFTTT applets** (`tower_plug_off`, `pc_plug_off`, etc.) once HA-book5 is up — Tapo integration in HA replaces them all natively.
- **Pi1 off-site watcher** (~50 lines of Python) as belt-and-suspenders for "both home nodes down" scenarios. Defer until HA-book5 done.
- **MQTT auth.** Currently anonymous on mosquitto. Fine on LAN but worth locking down with a user/pass. Need to update Frigate + HA MQTT integration in sync.
- **Hubspace entity_id stability.** Renames via UI don't stick — integration regenerates on reload. If we depend on these in automations, document the entity_ids that exist post-regeneration rather than relying on friendly-name-derived ids.

## 2026-05-20 - book5 DNS broken / sdwan0 swapped to pihole

### Incident
- `ping github.com` on book5 failed with "Temporary failure in name resolution"
- Direct queries to public resolvers (8.8.8.8) worked; only the configured resolvers failed
- `/etc/resolv.conf` listed `100.95.0.251-254` — Twingate's internal DNS, supplied via NM connection `sdwan0` (ipv4.method=manual, ipv4.dns-search=`~.` so it's catch-all)
- `twingate status` reported "online" and `/run/twingate/auth.sock` existed, but `dig @100.95.0.251 github.com` timed out — tunnel up, resolvers themselves not answering

### Investigation
- Confirmed 100.95.0.x are Twingate-owned (route via `sdwan0`, not Tailscale — Tailscale's `dns status` just reads `/etc/resolv.conf` and reports the same IPs as "system DNS")
- `systemctl restart twingate.service` did NOT bring the resolvers back; CLI `twingate stop && twingate start` blocked on an interactive "another VPN active" prompt (Tailscale also up — both use CGNAT, hence the false detection)
- Watchdog `network-health-monitor.sh` had logged every 10-minute check as fully healthy throughout the outage — it never probes DNS resolution, only ICMP to public IPs + systemctl + socket existence

### Fix
1. Started TW client back up via systemctl (left in `online` state)
2. Moved sdwan0 DNS off Twingate's broken resolvers and onto pihole:
   ```
   nmcli connection modify sdwan0 ipv4.dns 192.168.68.248
   nmcli connection modify sdwan0 ipv4.ignore-auto-dns yes
   nmcli device reapply sdwan0
   ```
   Persisted to `/etc/NetworkManager/system-connections/sdwan0.nmconnection`. resolv.conf now has only `nameserver 192.168.68.248`. pihole resolves both LAN and public — book5 does not need Twingate-internal name resolution.
3. DNS verified: `getent hosts github.com` → 140.82.114.4, `ping github.com` succeeds. Twingate still `online`, connector untouched.

### Watchdog Patch
- `/usr/local/bin/network-health-monitor.sh` patched (backup at `network-health-monitor.sh.bak-2026-05-20`)
- Added `check_dns()` — probes `getent ahostsv4` against cloudflare/google/github with 4s timeout
- Added new state branch "Case 4.5: DNS broken but everything else OK" — logs `action=dns_broken` and a hint to check resolv.conf/pihole/sdwan0. **Does not auto-remediate** — the 2026-05-20 incident showed TW client restart didn't fix it, and blind restart loops are worse than a clear log line
- "Case 5: Everything OK" now also requires `dns_ok=OK` so the watchdog doesn't report green during a future DNS outage
- log_check format unchanged (callers compatible); DNS state shows up via a separate `INFO dns_broken: ...` line

### Risk / Follow-up
- If Twingate client install/update overwrites the NM connection, sdwan0 DNS will revert to 100.95.0.x. Backup of original kept; re-apply nmcli commands if observed
- Root cause of TW resolver outage not determined (likely Twingate backend / sdwan0 tunnel state) — if it recurs, capture `twingate logs` + `ip -s link show sdwan0` before re-applying the workaround

## 2025-11-07 - Project Inception

### Initial Setup
- Created homeLab project directory structure
- Initialized git repository
- Created GitHub repository (private): github.com/jaded423/homeLab
- Set up multi-AI documentation (CLAUDE.md, GEMINI.md, AGENTS.md symlinks)

### Research Completed
- Launched gemini-researcher agent for comprehensive market research
- Researched GPU options for local LLM inference (RTX 3090, 4090, L40S)
- Researched server hardware (enterprise servers vs mini PCs)
- Researched complete system configurations
- Researched networking equipment and software stack
- Researched budget optimization and purchasing strategies

**Key Finding:** 100k token context requires ~25GB VRAM for KV Cache alone, making 24GB GPUs (RTX 3090/4090) tight but workable for 7B models. 48GB GPUs (L40S/A6000) remove all constraints.

### Documentation Created
- **llm-homelab-research-2025.md** (884 lines) - Comprehensive research document with:
  - VRAM requirement analysis for different model sizes and context lengths
  - GPU comparison with prices and performance metrics
  - Complete system configurations for three budget tiers
  - Server hardware options (enterprise and mini PC)
  - Networking equipment recommendations
  - Software stack guidance (Proxmox, Ollama, OpenWebUI)
  - Purchase links and vendor recommendations
  - Operating cost estimates
  - Upgrade path strategy

- **build-plan.md** (810 lines) - Actionable implementation guide with:
  - Recommended build specification: Budget-conscious starter ($2,200)
  - Complete component list with purchase links
  - Step-by-step assembly and setup instructions
  - 4-week implementation timeline
  - Software installation procedures
  - Testing and optimization guide
  - Upgrade path strategy
  - Risk assessment and mitigation
  - Alternative configurations for different budgets

### Recommendations Established

**Primary Recommendation:** Budget-Conscious Starter Build ($2,200 total)
- **LLM Workstation** ($1,350):
  - GPU: Used RTX 3090 24GB ($650) - best VRAM-per-dollar
  - CPU: AMD Ryzen 5 7600 ($200)
  - Motherboard: Gigabyte B650M DS3H ($130)
  - RAM: 32GB DDR5-6000 ($100)
  - Storage: 1TB NVMe SSD ($60)
  - PSU: Corsair RM750e 750W ($100)
  - Case: Phanteks Eclipse G300A ($60)
  - Cooler: Thermalright Phantom Spirit ($50)

- **Server Component** ($700):
  - Beelink SER7 (Ryzen 7 7840HS, 32GB RAM, 500GB SSD)
  - Quiet, power-efficient, perfect for home use

- **Networking** ($150):
  - TP-Link DS108-M2 (8-port 2.5GbE switch)

**Capabilities:**
- Run 7B models with ~60k context smoothly (30-40 tokens/sec)
- 100k context possible with offloading (15-20 tokens/sec)
- Annual operating cost: ~$600/year electricity

**Upgrade Path:**
- Short-term (3-6 months): Add storage, upgrade to 64GB RAM ($250-500)
- Long-term (12-18 months): Upgrade to L40S 48GB for true 100k context freedom ($3,000 net after selling RTX 3090)

### Next Steps
1. Set eBay alerts for RTX 3090 under $700
2. Create PCPartPicker list with all components
3. Join communities (r/LocalLLaMA, r/homelab, Ollama Discord)
4. Review research document thoroughly
5. Begin purchasing components

### Resources Compiled
- Purchase links to Amazon, Newegg, eBay, and specialized retailers
- Community resources (Reddit, Discord)
- Learning resources (documentation, benchmarks)
- Price tracking tools
- Software installation guides

---

**Project Status:** Ready for hardware purchasing phase
**Total Documentation:** ~1,700 lines across 3 files
**Next Review:** After component purchases or in 30 days
## 2025-11-12 - Remote Desktop Access (wayvnc) Setup

### Overview
Successfully configured remote desktop access to the CachyOS server using wayvnc, enabling full GUI access via VNC over SSH tunnel. This allows viewing and controlling the Hyprland desktop environment from anywhere with SSH access.

### What Was Implemented

#### 1. wayvnc VNC Server Installation
- **Package:** wayvnc (Wayland-native VNC server)
- **Configuration:** Listens on `127.0.0.1:5900` (localhost only for security)
- **GPU Acceleration:** Enabled with `--gpu` flag for better performance
- **Auto-start:** Added to Hyprland config (`~/.config/hypr/hyprland.conf`)
- **Command:** `wayvnc 127.0.0.1 5900 --max-fps=30 --gpu`

#### 2. SSH Tunnel Configuration
- **Security Model:** VNC not exposed to network, only accessible via SSH tunnel
- **No firewall changes needed:** Port 5900 remains blocked externally
- **Connection method:** SSH port forwarding (`-L 5900:localhost:5900`)

**From Mac:**
```bash
# Create SSH tunnel (keep running)
ssh -L 5900:localhost:5900 jaded@192.168.1.228

# Connect VNC to localhost
open vnc://localhost:5900
# OR
open -a "VNC Viewer" localhost:5900
```

#### 3. VNC-Friendly Keybindings
Added Ctrl-based keybindings that work through VNC (SUPER key doesn't pass through VNC clients):

**Launching Applications:**
- `Ctrl + Enter` → Open terminal (kitty)
- `Ctrl + Space` → Open application launcher (wofi)

**Workspace Navigation:**
- `Ctrl + 1-9` → Switch to workspace 1-9
- `Ctrl + Shift + 1-9` → Move current window to workspace 1-9

**Legacy Bindings (still work):**
- `Ctrl + Alt + T` → Open terminal
- `Ctrl + Alt + Space` → Open app menu
- `Ctrl + Alt + W` → Close active window

**Original SUPER keybindings still work locally** (on physical machine):
- `SUPER + Return` → Terminal
- `SUPER + Space` → App launcher
- `SUPER + 1-9` → Switch workspaces
- `SUPER + Shift + 1-9` → Move window to workspace

#### 4. Waybar Status Bar Configuration
- **Issue:** Waybar couldn't detect Hyprland when started from SSH
- **Solution:** Start Waybar with `HYPRLAND_INSTANCE_SIGNATURE` environment variable
- **Location:** `~/.config/waybar/config`
- **Modules:** Power menu, workspaces, window title, clock, system stats, battery

**Removed:** Temporary [T] and [A] text shortcuts (replaced by keyboard shortcuts)

#### 5. Auto-login Configuration
- **Display Manager:** SDDM
- **Configuration:** `/etc/sddm.conf`
- **User:** jaded
- **Session:** Hyprland
- **Behavior:** Automatically logs in on boot, starts Hyprland and all services

### Files Modified

**Server Configuration Files:**
1. `~/.config/hypr/hyprland.conf`
   - Added wayvnc auto-start command
   - Added VNC-friendly keybindings (Ctrl + Enter, Ctrl + Space, etc.)
   - Added workspace switching and window movement keybindings

2. `~/.config/waybar/config`
   - Restored original configuration (power menu + workspaces)
   - Removed temporary text shortcuts

3. `/etc/sddm.conf`
   - Configured auto-login for user jaded
   - Set session to Hyprland

4. `~/.config/wayvnc/config.bak`
   - Backed up problematic config file (not used, command-line args used instead)

### Usage Instructions

#### Connecting to Desktop Remotely

**Step 1: Create SSH Tunnel**
```bash
# On Mac - open terminal and run:
ssh -L 5900:localhost:5900 jaded@192.168.1.228
# Keep this terminal open
```

**Step 2: Connect VNC Client**
```bash
# In another terminal or Finder (Cmd+K):
open vnc://localhost:5900

# OR use VNC Viewer app:
open -a "VNC Viewer" localhost:5900
```

**Step 3: Use the Desktop**
- Click to interact with windows and menus
- Use VNC-friendly keybindings (Ctrl+Enter, Ctrl+Space, etc.)
- No password required (secured by SSH tunnel)

#### Managing wayvnc Service

**Check if running:**
```bash
pgrep -a wayvnc
```

**View logs:**
```bash
tail -f /tmp/wayvnc.log
```

**Manually start (if needed):**
```bash
WAYLAND_DISPLAY=wayland-1 wayvnc 127.0.0.1 5900 --max-fps=30 --gpu &
```

**Restart Waybar (if workspace numbers missing):**
```bash
killall waybar
HYPRLAND_INSTANCE_SIGNATURE=$(ls -1 /run/user/1000/hypr/ | head -1) \
WAYLAND_DISPLAY=wayland-1 waybar &
```

### Technical Details

**Why SSH Tunnel?**
- **Security:** VNC traffic encrypted via SSH, no plaintext over network
- **No firewall changes:** Port 5900 never exposed to network
- **No VNC password needed:** SSH authentication provides security
- **Works remotely:** Same method works from anywhere (home or via Twingate)

**Why Ctrl Keybindings?**
- **VNC limitation:** SUPER (Windows/Command) key intercepted by VNC clients and host OS
- **Workaround:** Use Ctrl-based shortcuts that pass through VNC protocol
- **Dual support:** Both SUPER and Ctrl bindings coexist (SUPER for local, Ctrl for VNC)

**Performance Settings:**
- **FPS limit:** 30 FPS (good balance of responsiveness and bandwidth)
- **GPU acceleration:** Enabled for smoother rendering
- **Resolution:** Native 2880x1800 (Samsung eDP-1 display)

### Verification

**Connection verified working:**
- ✅ SSH tunnel establishes successfully
- ✅ VNC Viewer connects to localhost:5900
- ✅ Hyprland desktop visible and responsive
- ✅ Mouse input works
- ✅ Keyboard input works
- ✅ Ctrl+Enter opens terminal
- ✅ Ctrl+Space opens app launcher
- ✅ Workspace switching with Ctrl+1-9
- ✅ Window movement with Ctrl+Shift+1-9
- ✅ Waybar displays correctly with workspace numbers
- ✅ Auto-start works after reboot

### Troubleshooting Reference

**Issue: VNC connection refused**
```bash
# Check wayvnc is running
pgrep wayvnc

# Start if needed
WAYLAND_DISPLAY=wayland-1 wayvnc 127.0.0.1 5900 --max-fps=30 --gpu &
```

**Issue: Workspace numbers not showing in Waybar**
```bash
# Restart Waybar with Hyprland signature
killall waybar
HYPRLAND_INSTANCE_SIGNATURE=$(ls -1 /run/user/1000/hypr/ | head -1) \
WAYLAND_DISPLAY=wayland-1 waybar &
```

**Issue: Keybindings not working**
```bash
# Reload Hyprland config (from VNC or SSH)
hyprctl reload

# Or verify keybindings in config
grep -E "bind.*CTRL" ~/.config/hypr/hyprland.conf
```

**Issue: SSH tunnel drops**
```bash
# Keep SSH tunnel persistent with autossh
brew install autossh  # On Mac
autossh -M 0 -L 5900:localhost:5900 jaded@192.168.1.228
```

### Benefits

**Remote Access:**
- Full GUI access to server from anywhere
- No need to be physically at the machine
- Works over Twingate for remote access
- Can manage desktop applications remotely

**Development Workflow:**
- Can use graphical applications remotely
- Test GUI applications without being at server
- Access file managers, browsers, IDEs visually
- Debug desktop environment issues remotely

**Convenience:**
- VNC-friendly keyboard shortcuts for common tasks
- Auto-login on boot (no manual intervention needed)
- Persistent setup survives reboots
- Low bandwidth usage (30 FPS limit)

### Security Considerations

**Good Security Practices:**
- ✅ VNC only on localhost (not exposed to network)
- ✅ SSH tunnel provides encryption
- ✅ No VNC password needed (SSH auth is stronger)
- ✅ Firewall unchanged (port 5900 still blocked)
- ✅ Works with existing SSH key authentication

**Potential Concerns:**
- Auto-login means physical access = full access
  - Acceptable for home lab environment
  - Server is in secure location (home)
- VNC has no additional authentication
  - Mitigated by SSH tunnel requirement
  - Cannot connect without SSH access first

### Future Enhancements

**Possible Improvements:**
- Set up autossh for persistent SSH tunnel on Mac
- Configure VNC Viewer with saved connection
- Add additional Ctrl keybindings for more functions
- Optimize FPS based on network conditions
- Consider X11 forwarding for individual apps as alternative

### Documentation Updates

**Server Documentation (`~/README.md`):**
- Added wayvnc remote desktop access section
- Documented connection procedure
- Added keybinding reference
- Included troubleshooting steps

**Work Mac (`~/.claude/docs/homelab.md`):**
- Remote desktop access section added
- SSH tunnel configuration documented
- VNC client setup instructions
- Security model explanation

---

**Status:** ✅ Fully operational and tested
**Auto-start:** ✅ Configured (survives reboots)
**Security:** ✅ SSH tunnel only (no network exposure)
**Performance:** ✅ Smooth at 30 FPS with GPU acceleration
**Last Tested:** 2025-11-12

## 2026-05-06 - Added Homelable Visualizer LXC (CT 103) on book5

**What changed:**
- Created LXC 103 `homelable` on prox-book5 via community-scripts ProxmoxVE installer
  - Debian 13 unprivileged, 2 vCPU / 2 GB RAM / 8 GB disk on `local-zfs-book5`
  - Bridge `vmbr1`, IP `192.168.68.61` (DHCP)
  - Native install (Python 3.13 + uv venv + Node 20 + Caddy frontend), no Docker
- Configured `SCANNER_RANGES=["192.168.68.0/22"]` in `/opt/homelable/backend/.env`
- Added `homelable-mcp.service` (uvicorn on 0.0.0.0:8001) for AI integration
  - Generated `MCP_API_KEY` and `MCP_SERVICE_KEY`, stored in `/opt/homelable/mcp/.env` and backend `.env`
  - Wired into `~/.claude.json` as MCP server `homelable` (transport: `http`)
- User added Twingate resource for 192.168.68.61 (all ports) so it's reachable from Mac via tunnel

**Why:**
- Wanted a visual topology + live status overview of the homelab
- MCP integration lets Claude Code read topology, trigger scans, add/edit nodes during sessions

**Files modified:**
- `/etc/pve/lxc/103.conf` (book5) — new container
- `/etc/systemd/system/homelable.service` (CT 103) — backend systemd unit (created by installer)
- `/etc/systemd/system/homelable-mcp.service` (CT 103) — MCP server systemd unit (created manually)
- `/opt/homelable/backend/.env` (CT 103) — `SCANNER_RANGES` and `MCP_SERVICE_KEY`
- `/opt/homelable/mcp/.env` (CT 103) — MCP keys + `BACKEND_URL=http://localhost:8000`
- `~/.claude.json` (Mac) — added `homelable` MCP server entry
- `~/projects/homeLab/CLAUDE.md` — added CT 103 to current state
- `~/.claude/CLAUDE.md` — added CT 103 to Home Lab Quick Reference
- `~/.claude/docs/projects.md` — bumped Home Lab Last Updated, added Homelable to services

**Technical notes:**
- **Bridge gotcha:** community-scripts default is `vmbr0`. On book5 vmbr0 is inactive (post Feb-2026 router migration; vmbr1 is the 2.5GbE primary, already documented in global CLAUDE.md). First install attempt failed with "No IP assigned to CT 103 after 60 attempts". Fix: destroy + re-run with `var_brg=vmbr1` env var. Also pin CT ID with `var_ctid=103` (default would have picked 101 since 100/102 are used).
- **MCP transport:** Homelable's README says `--transport sse`, but the server uses `StreamableHTTPSessionManager`. Claude Code needs `type: "http"` (streamable-http), not `type: "sse"`. README is stale — verified via `claude mcp list` showing "Failed to connect" with `sse` and "Connected" with `http`.
- **Skipped host apt upgrade:** installer prompts to run `apt upgrade` on the Proxmox host — declined ([2] Ignore). Out of scope for one LXC install.
- **MCP server is native (not Docker):** community-scripts installer skips MCP entirely. Set up a venv at `/opt/homelable/mcp/.venv` and a separate systemd unit, mirroring the existing `homelable.service` pattern.

---

## 2026-05-06 - Populated Homelable Canvas via MCP

**What changed:**
- Seeded the Homelable canvas with 17 nodes / 13 edges / 4 parent links via MCP from a fresh Claude Code session
- Triggered first nmap scan (192.168.68.0/22) — discovered 26 devices
  - 10 hidden as duplicates of nodes already created
  - 4 approved with confident labels: TP-Link AP (192.168.71.250), PlayStation (.51), Nintendo Switch (.68), Google device (.56)
  - 2 hidden as randomized/transient MACs (visiting phones)
  - 10 left pending for user triage (mostly Espressif ESP32 + TP-Link smart-home gear)
- Created topology: gateway (192.168.68.1) at root → both Proxmox hosts, Pi-hole, Mac, IoT, mobile devices
- Set parent_id on VM/LXC nodes so they nest visually under their Proxmox host

**Why:**
- User wanted to see Homelable in action with their actual network — a fresh install ships with a demo canvas (Freebox Ultra / OpnSense / NAS-01 / etc.) which had been cleared
- Combined manual node creation from documented infrastructure with nmap-driven discovery for unknown devices

**Files modified:**
- (None on Mac — all changes via MCP to `/opt/homelable/data/homelab.db` on CT 103)

**Technical notes:**
- **Gateway and second AP same OUI:** gateway MAC `XX:XX:XX:XX:XX:XX` (.68.1) and `XX:XX:XX:XX:XX:XX` (.71.250) — adjacent MACs, both with the same TP-Link OUI prefix → almost certainly a mesh setup, primary router + AP/satellite. The .71.250 lives in the same /22 broadcast domain.
- **CT 102 trans IP:** 192.168.68.65 (was previously undocumented in network sheets).
- **OUI patterns on the network:** 6× Espressif (ESP32-based custom IoT — Tasmota/ESPHome/Shelly territory), 4× TP-Link (Tapo/Kasa devices), 1× Earda (smart switch/dimmer brand), plus consoles + Chromecast/Nest.
- **Approval payload format:** `approve_device` only takes `id`, `label`, `type`. To set `hostname`/`ip`/`status` afterward, use `update_node`. (We didn't need to since the discovered IP is auto-applied by approve.)
- **Edge defaults:** modeled wifi devices as connecting directly to the gateway (logical topology), not through the AP — Homelable canvas is meant to be a logical map, not a physical L2 trace.

---
