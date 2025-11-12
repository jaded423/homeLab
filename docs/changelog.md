# HomeLab Project Changelog

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
