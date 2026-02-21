# Gaming VM Setup Plan

**Target Machine:** prox-tower (192.168.2.249)
**Created:** December 15, 2025
**Status:** Planning

---

## Overview

Set up a Windows gaming VM on prox-tower with GPU passthrough (Quadro M4000) for retro gaming - DOSBox, Populous, Steam classics, GOG titles.

**Architecture:**
- Small Windows VM (50-60GB) for OS + game launchers
- Shared storage via Samba for game installs
- GPU passthrough for graphics acceleration
- Access via Proxmox noVNC console or Parsec/Moonlight

---

## Current State

### prox-tower Hardware
| Component | Spec |
|-----------|------|
| CPU | Intel Xeon E5-2683 v4 (16c/32t @ 2.1GHz) |
| RAM | 78GB |
| GPU | NVIDIA Quadro M4000 (8GB VRAM) |
| Storage | ~359GB ZFS (rpool-tower) |
| Network | Dual-NIC (1GbE mgmt + 2.5GbE primary) |

### Current Storage Situation
| Location | Used | Available |
|----------|------|-----------|
| prox-tower ZFS pool | 305GB | **54GB** |
| VM 101 (inside) | 179GB | 101GB |
| prox-book5 ZFS pool | 89.5GB | **825GB** |

### Space Consumers on VM 101
| Item | Size | Action |
|------|------|--------|
| TV Shows | 109GB | Move to book5 |
| Ollama models | 37GB | Keep |
| Downloads | 3.7GB | Keep |
| OS + Docker | ~29GB | Keep |

---

## Phase 1: Free Up Storage Space

### 1.1 Move TV Shows to book5 NFS

**Why:** Frees ~109GB on tower, TV Shows don't need fast local storage

**Commands (run from VM 101):**
```bash
# Check NFS mount is available
df -h /mnt/book5-media

# Create TV Shows directory on book5
mkdir -p /mnt/book5-media/TV\ Shows

# Move TV Shows (use rsync for safety)
rsync -avh --progress /home/jaded/media/TV\ Shows/ /mnt/book5-media/TV\ Shows/

# Verify transfer completed
ls -la /mnt/book5-media/TV\ Shows/
du -sh /mnt/book5-media/TV\ Shows/

# After verification, remove local copies
rm -rf /home/jaded/media/TV\ Shows/*

# Update symlink or Plex library path
# Plex library should point to: /mnt/book5-media/TV Shows
```

**Plex Library Update:**
1. Open Plex web UI (http://192.168.1.126:32400/web)
2. Settings → Libraries → TV Shows
3. Edit library, change path to `/mnt/book5-media/TV Shows`
4. Scan library to verify

### 1.2 Verify Space Reclaimed

```bash
# On prox-tower host
ssh root@192.168.2.249 "zfs list rpool-tower"

# Should show significantly more available space (~160GB+)
```

---

## Phase 2: Set Up Shared Games Storage

### 2.1 Create Games Directory on VM 101

```bash
# SSH into VM 101
ssh jaded@192.168.1.126

# Create games directory
mkdir -p /home/jaded/games

# Set permissions
chmod 755 /home/jaded/games
```

### 2.2 Add Samba Share for Games

**Edit Samba config on VM 101:**
```bash
sudo nano /etc/samba/smb.conf
```

**Add this section:**
```ini
[Games]
   path = /home/jaded/games
   browseable = yes
   read only = no
   guest ok = no
   valid users = jaded
   create mask = 0755
   directory mask = 0755
```

**Restart Samba:**
```bash
sudo systemctl restart smbd
```

**Test from another machine:**
```bash
# From Mac
open smb://192.168.1.126/Games

# Or mount via command line
mkdir -p ~/mnt/games
mount_smbfs //jaded@192.168.1.126/Games ~/mnt/games
```

---

## Phase 3: Prepare GPU Passthrough

### 3.1 Check IOMMU Status

```bash
# SSH to prox-tower
ssh root@192.168.2.249

# Check if IOMMU is enabled
dmesg | grep -e DMAR -e IOMMU

# Check IOMMU groups
find /sys/kernel/iommu_groups/ -type l | sort -V

# Find the Quadro M4000
lspci -nn | grep -i nvidia
# Note the PCI address (e.g., 03:00.0) and device IDs
```

### 3.2 Enable IOMMU (if not already enabled)

**Edit GRUB config:**
```bash
nano /etc/default/grub

# Add to GRUB_CMDLINE_LINUX_DEFAULT:
# For Intel CPU: intel_iommu=on iommu=pt
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"
```

**Update GRUB and reboot:**
```bash
update-grub
reboot
```

### 3.3 Blacklist NVIDIA Driver on Host

**Create blacklist file:**
```bash
echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidia" >> /etc/modprobe.d/blacklist.conf
```

### 3.4 Configure VFIO for GPU

**Get GPU device IDs:**
```bash
lspci -nn | grep -i nvidia
# Output example: 03:00.0 VGA compatible controller [0300]: NVIDIA Corporation GM204GL [Quadro M4000] [10de:13f1]
# Note: [10de:13f1] are the vendor:device IDs
```

**Configure VFIO:**
```bash
# Create vfio.conf
echo "options vfio-pci ids=10de:XXXX,10de:YYYY" > /etc/modprobe.d/vfio.conf
# Replace XXXX,YYYY with actual GPU and audio device IDs

# Add vfio modules to load early
echo "vfio" >> /etc/modules
echo "vfio_iommu_type1" >> /etc/modules
echo "vfio_pci" >> /etc/modules
echo "vfio_virqfd" >> /etc/modules

# Update initramfs
update-initramfs -u -k all

# Reboot
reboot
```

### 3.5 Verify GPU is Bound to VFIO

```bash
lspci -nnk | grep -A3 -i nvidia
# Should show: Kernel driver in use: vfio-pci
```

---

## Phase 4: Create Windows Gaming VM

### 4.1 Download Windows ISO

**Option A: Windows 10 (recommended for retro games)**
- Download from Microsoft: https://www.microsoft.com/software-download/windows10ISO
- Upload to Proxmox: Datacenter → prox-tower → local → ISO Images → Upload

**Option B: Windows 11**
- Requires TPM emulation in Proxmox
- More overhead, less necessary for retro gaming

### 4.2 Download VirtIO Drivers

```bash
# On prox-tower
cd /var/lib/vz/template/iso/
wget https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
```

### 4.3 Create VM via Proxmox Web UI

**General:**
- VM ID: 102 (or next available)
- Name: `gaming-vm`
- Resource Pool: (leave blank)

**OS:**
- ISO image: Windows 10/11 ISO
- Type: Microsoft Windows
- Version: 10/2022 or 11/2022

**System:**
- Machine: q35
- BIOS: OVMF (UEFI)
- Add TPM: (only if Windows 11)
- SCSI Controller: VirtIO SCSI

**Disks:**
- Bus/Device: SCSI
- Storage: local-zfs-tower
- Disk size: **60GB** (OS + launchers only)
- Cache: Write back
- Discard: checked (for TRIM)

**CPU:**
- Cores: 4-6
- Type: host

**Memory:**
- Memory: 16384 MB (16GB)
- Ballooning: unchecked (for gaming stability)

**Network:**
- Bridge: vmbr1 (2.5GbE network)
- Model: VirtIO

### 4.4 Add GPU Passthrough to VM

**Via Proxmox Web UI:**
1. Select gaming-vm → Hardware → Add → PCI Device
2. Select the Quadro M4000
3. Check: "All Functions"
4. Check: "Primary GPU" (if you want display output from GPU)
5. Check: "PCI-Express"

**Or via command line:**
```bash
# Edit VM config
nano /etc/pve/qemu-server/102.conf

# Add GPU passthrough line (adjust PCI address)
hostpci0: 03:00,pcie=1,x-vga=1
```

### 4.5 Add VirtIO Drivers ISO

1. Hardware → Add → CD/DVD Drive
2. Select virtio-win.iso
3. Bus: IDE, Device: 1

### 4.6 VM Config Summary

```
# /etc/pve/qemu-server/102.conf (example)
bios: ovmf
boot: order=scsi0;ide0
cores: 6
cpu: host
efidisk0: local-zfs-tower:vm-102-disk-0,size=1M
hostpci0: 03:00,pcie=1,x-vga=1
ide0: local:iso/Win10.iso,media=cdrom
ide1: local:iso/virtio-win.iso,media=cdrom
machine: q35
memory: 16384
name: gaming-vm
net0: virtio=XX:XX:XX:XX:XX:XX,bridge=vmbr1
ostype: win10
scsi0: local-zfs-tower:vm-102-disk-1,size=60G
scsihw: virtio-scsi-pci
```

---

## Phase 5: Install Windows

### 5.1 Boot and Install Windows

1. Start VM from Proxmox console
2. Boot from Windows ISO
3. At disk selection: "Load driver" → Browse to VirtIO ISO → `vioscsi\w10\amd64`
4. Install VirtIO SCSI driver, disk should appear
5. Complete Windows installation

### 5.2 Install VirtIO Drivers in Windows

After Windows boots:
1. Open VirtIO ISO in File Explorer
2. Run `virtio-win-gt-x64.msi` (installs all drivers)
3. Or manually install from each folder:
   - `Balloon` - Memory ballooning
   - `NetKVM` - Network driver
   - `vioserial` - Serial driver
   - `qxldod` - Display driver (not needed with GPU passthrough)

### 5.3 Install NVIDIA Drivers

1. Download Quadro drivers from NVIDIA: https://www.nvidia.com/Download/index.aspx
2. Select: Quadro → Quadro Series → Quadro M4000
3. Install drivers
4. Reboot

### 5.4 Configure Display

**Option A: Use GPU output directly**
- Connect monitor to Quadro M4000 outputs
- Best performance, no encoding overhead

**Option B: Use Parsec/Moonlight (remote play)**
- Install Parsec: https://parsec.app/
- Low latency remote gaming from Mac
- Works great for retro games

**Option C: Proxmox noVNC console**
- Built-in, always works
- Higher latency, fine for turn-based/strategy games

---

## Phase 6: Install Gaming Software

### 6.1 Map Network Drive for Games

1. Open File Explorer
2. Right-click "This PC" → "Map network drive"
3. Drive letter: `G:`
4. Folder: `\\192.168.1.126\Games`
5. Check "Reconnect at sign-in"
6. Enter credentials (jaded / samba password)

### 6.2 Install Steam

1. Download: https://store.steampowered.com/
2. Install to C: drive
3. Add G: drive as Steam Library folder:
   - Steam → Settings → Storage → Add Drive → G:\SteamLibrary

### 6.3 Install GOG Galaxy

1. Download: https://www.gog.com/galaxy
2. Install to C: drive
3. Set default game install location to G:\GOG Games

### 6.4 Install DOSBox

**Option A: DOSBox Staging (recommended)**
- Modern fork with better defaults
- https://dosbox-staging.github.io/
- Install to C:, games can go on G:\DOS

**Option B: DOSBox-X**
- More accurate emulation
- https://dosbox-x.com/

**DOSBox Config:**
```ini
# In dosbox.conf
[dosbox]
machine = svga_s3

[cpu]
cycles = auto

[autoexec]
mount G G:\DOS
G:
```

### 6.5 Install Populous

**From GOG:**
1. Purchase/download Populous from GOG
2. GOG version includes DOSBox preconfigured
3. Install to G:\GOG Games\Populous

**Manual with DOSBox:**
1. Copy Populous files to G:\DOS\Populous
2. In DOSBox: `cd POPULOUS` then `POP.EXE`

---

## Phase 7: Optimization (Optional)

### 7.1 CPU Pinning

For better gaming performance, pin VM to specific CPU cores:

```bash
# Edit VM config
nano /etc/pve/qemu-server/102.conf

# Add CPU pinning (example: cores 8-13)
cpu: host
cores: 6
cpuunits: 1024
affinity: 8-13
```

### 7.2 Hugepages

For reduced memory latency:

```bash
# On prox-tower host
echo "vm.nr_hugepages = 8192" >> /etc/sysctl.conf
sysctl -p

# In VM config, add:
hugepages: 1024
```

### 7.3 Audio Passthrough (Optional)

If you want audio from the VM:

**Option A: HDMI audio through GPU**
- Audio passes through HDMI/DisplayPort
- Works if monitor has speakers or audio out

**Option B: USB audio device passthrough**
- Pass through a USB sound card/DAC

**Option C: Scream (virtual audio over network)**
- https://github.com/duncanthrax/scream
- Streams audio to Mac with low latency

---

## Quick Reference

### Access Points

| Service | Address |
|---------|---------|
| Proxmox Web UI | https://192.168.2.249:8006 |
| Gaming VM Console | Proxmox → gaming-vm → Console |
| Games Share | `\\192.168.1.126\Games` or `smb://192.168.1.126/Games` |
| Plex | http://192.168.1.126:32400/web |

### VM Resource Allocation

| VM | CPU | RAM | Disk | Purpose |
|----|-----|-----|------|---------|
| 101 ubuntu-server | 12 cores | 40GB | 300GB | Plex, qBit, Ollama, Samba |
| 102 gaming-vm | 6 cores | 16GB | 60GB | Windows + GPU passthrough |

### Useful Commands

```bash
# Check GPU passthrough status
lspci -nnk | grep -A3 -i nvidia

# Check IOMMU groups
find /sys/kernel/iommu_groups/ -type l | sort -V

# Start/stop gaming VM
qm start 102
qm stop 102

# Check VM status
qm status 102

# View VM console (text mode)
qm terminal 102
```

---

## Troubleshooting

### GPU Passthrough Issues

**"Error: IOMMU not enabled"**
- Verify BIOS has VT-d enabled
- Check GRUB has `intel_iommu=on`
- Run `dmesg | grep -i iommu` to verify

**"GPU not in separate IOMMU group"**
- May need ACS override patch
- Or try different PCIe slot

**"Code 43" in Windows Device Manager**
- Add to VM config: `args: -cpu host,kvm=off,hv_vendor_id=proxmox`
- This hides virtualization from NVIDIA driver

### Network Drive Issues

**"Cannot connect to \\192.168.1.126\Games"**
- Verify Samba is running: `systemctl status smbd`
- Check firewall: `sudo ufw status`
- Test from VM 101 locally first

### Performance Issues

**Low FPS in games**
- Verify GPU driver installed correctly
- Check CPU pinning
- Ensure memory ballooning is disabled
- Monitor with Task Manager / GPU-Z

---

## Estimated Timeline

| Phase | Tasks | Time Estimate |
|-------|-------|---------------|
| 1 | Move TV Shows to book5 | 30-60 min (depends on transfer speed) |
| 2 | Set up Samba games share | 15 min |
| 3 | Configure GPU passthrough | 30-60 min |
| 4 | Create Windows VM | 15 min |
| 5 | Install Windows + drivers | 45-60 min |
| 6 | Install gaming software | 30 min |
| 7 | Optimization (optional) | 30 min |

**Total: ~3-5 hours** (can be done in stages)

---

## Next Steps

1. [ ] Move TV Shows to book5 NFS
2. [ ] Verify storage space reclaimed
3. [ ] Create Games Samba share on VM 101
4. [ ] Check IOMMU/GPU passthrough readiness
5. [ ] Download Windows ISO and VirtIO drivers
6. [ ] Create gaming VM
7. [ ] Install Windows and drivers
8. [ ] Install gaming software
9. [ ] Enjoy Populous!

---

*Plan created by Claude Code - December 15, 2025*
