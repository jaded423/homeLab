# Linux OS Options for HomeLab Server - Comprehensive Comparison

**Created:** November 7, 2025
**Purpose:** Choose the right operating system for your homelab server component

---

## Quick Recommendation Guide

**Complete Beginner** → CasaOS or Unraid ($59)
**Docker-Focused** → Ubuntu Server 24.04 LTS
**VM-Heavy Workload** → Proxmox VE
**Storage/NAS Priority** → TrueNAS SCALE
**LLM Hosting Specifically** → Ubuntu Server 24.04 LTS

---

## Detailed OS Comparisons

### 1. Proxmox VE (FREE)

**Best For:** Mixed VM + Container workloads, learning enterprise virtualization

#### Core Features
- **KVM Virtualization**: Full hardware virtualization for VMs
- **LXC Containers**: Lightweight Linux containers (faster than VMs)
- **GPU Passthrough**: Pass GPU to VM for LLM inference
- **Web UI**: Comprehensive management interface on port 8006
- **Clustering**: Multi-node support (advanced)
- **ZFS Support**: Native ZFS for storage pools
- **Backup/Restore**: Built-in snapshot and backup system

#### Setup Complexity
- **Initial Setup:** Medium (15-30 min from USB)
- **Learning Curve:** Moderate - Web UI is intuitive, but concepts require learning
- **Configuration:** Most done via web UI, some CLI for advanced features

#### Docker Integration
- **Method 1:** Docker in LXC container (lightweight, recommended for simple setups)
- **Method 2:** Docker in VM (full isolation, GPU passthrough possible)
- **Method 3:** Docker directly on Proxmox host (not recommended, breaks updates)

#### GPU Passthrough
- **Support:** Excellent - PCIe passthrough to VMs
- **Use Case:** Pass RTX 3090/4090 to Ubuntu VM for LLM inference
- **Limitation:** GPU unavailable to host when passed through

#### Pros
- Industry-standard KVM/QEMU virtualization
- Excellent web UI - manage everything from browser
- Free and open source (enterprise version available)
- Large community and extensive documentation
- Can run multiple OS types (Linux, Windows, BSD)
- ZFS integration for data integrity
- Great for learning enterprise skills

#### Cons
- Overkill if only running Docker containers
- Requires learning virtualization concepts
- Uses more resources than bare-metal OS
- Enterprise repo requires paid subscription (non-critical)
- Docker integration not as seamless as native Linux

#### When to Choose Proxmox
- You want to run multiple VMs (Ubuntu for LLM + Windows + etc)
- Learning enterprise virtualization skills
- Need isolation between workloads
- Want web-based management
- Planning multi-node cluster future

#### Community & Support
- **Rating:** 5/5 ⭐⭐⭐⭐⭐
- Very active forum, extensive wiki, YouTube tutorials

---

### 2. Ubuntu Server 24.04 LTS (FREE)

**Best For:** Docker-focused homelab, LLM hosting, simplicity

#### Core Features
- **Long Term Support:** 5 years security updates (until 2029)
- **Native Docker:** Install Docker/Docker Compose easily
- **NVIDIA Drivers:** Best support for GPU drivers
- **Hardware Enablement (HWE):** Latest kernel for new hardware
- **Snap Packages:** Universal package format (controversial)
- **APT Package Manager:** Traditional Debian packages

#### Setup Complexity
- **Initial Setup:** Easy (10-15 min from USB)
- **Learning Curve:** Low - familiar to most Linux users
- **Configuration:** Primarily CLI, optional Cockpit web UI

#### Docker Support
- **Native:** Install via `apt` or official Docker repo
- **Docker Compose:** Full support, recommended deployment method
- **Rootless Mode:** Supported for security
- **NVIDIA Container Toolkit:** Official support for GPU containers

#### VM Hosting
- **Method:** KVM + libvirt (command-line or virt-manager)
- **Ease:** More manual than Proxmox, but capable
- **Use Case:** Occasional VMs, Docker is primary workload

#### GPU Support for LLM
- **NVIDIA Drivers:** Excellent - `ubuntu-drivers autoinstall`
- **CUDA:** Full support
- **Docker GPU:** NVIDIA Container Toolkit integrates perfectly

#### Pros
- Simplest for Docker-first workflow
- Excellent NVIDIA GPU support
- Large community, extensive documentation
- Latest software packages
- Familiar to most developers
- Great for LLM hosting (Ollama, OpenWebUI via Docker)

#### Cons
- Snap packages polarizing (can disable)
- More bloat than Debian (but still lightweight)
- No web UI by default (can add Cockpit)
- VM management less polished than Proxmox

#### When to Choose Ubuntu Server
- Docker is your primary workload
- Hosting LLM inference (Ollama + OpenWebUI)
- Want latest packages and kernel
- Familiar with Ubuntu ecosystem
- GPU-accelerated applications

#### Recommended Setup for LLM Hosting
```bash
# After Ubuntu Server install
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Install NVIDIA drivers
sudo ubuntu-drivers autoinstall
sudo reboot

# Install NVIDIA Container Toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt update && sudo apt install -y nvidia-container-toolkit
sudo systemctl restart docker

# Deploy Ollama + OpenWebUI
docker compose up -d
```

#### Community & Support
- **Rating:** 5/5 ⭐⭐⭐⭐⭐
- Massive community, Ask Ubuntu, extensive tutorials

---

### 3. Debian 12 "Bookworm" (FREE)

**Best For:** Maximum stability, resource efficiency, "set it and forget it"

#### Core Features
- **Rock-Solid Stability:** Conservative package versions
- **Minimal Resource Use:** Leaner than Ubuntu
- **Universal Base:** Many distros derive from Debian
- **APT Package Manager:** Same as Ubuntu
- **Backports Available:** Newer software when needed

#### Setup Complexity
- **Initial Setup:** Easy (10-15 min from USB)
- **Learning Curve:** Low-Medium (slightly less hand-holding than Ubuntu)
- **Configuration:** Primarily CLI

#### Differences from Ubuntu
- **Packages:** Older stable versions vs newer Ubuntu releases
- **Drivers:** May require manual firmware installation (non-free repo)
- **HWE Kernel:** Not available (stable kernel only)
- **Updates:** Less frequent, more tested

#### When Debian is Better Choice
- You prioritize stability over bleeding-edge features
- Resource-constrained server (Debian uses ~50MB less RAM)
- Long-term deployment without frequent updates
- You prefer "pure" Debian over Ubuntu's additions

#### GPU Support
- **NVIDIA:** Supported, but requires non-free repo
- **Installation:** More manual than Ubuntu's `ubuntu-drivers`

#### Pros
- Maximum stability and reliability
- Minimal resource footprint
- No corporate influence (Ubuntu = Canonical)
- Foundation of thousands of derivative distros
- Very long support cycle

#### Cons
- Older package versions (intentional trade-off)
- Less friendly for GPU/hardware setup
- Fewer "just works" shortcuts than Ubuntu
- Smaller community vs Ubuntu (but still large)

#### When to Choose Debian
- Stability > latest features
- Experience with Linux (not first homelab)
- Long-term deployment (years without reinstall)
- Prefer minimal system without extras

#### Community & Support
- **Rating:** 4/5 ⭐⭐⭐⭐
- Excellent documentation, but less beginner-friendly than Ubuntu

---

### 4. TrueNAS SCALE (FREE)

**Best For:** Network Attached Storage (NAS) with ZFS

#### Core Features
- **ZFS File System:** Data integrity, snapshots, compression
- **Web UI:** Comprehensive storage management
- **Docker/Kubernetes:** Deploy apps via TrueNAS interface
- **VM Support:** Basic KVM virtualization
- **SMB/NFS Shares:** Network file sharing
- **Replication:** Remote backup and disaster recovery

#### Setup Complexity
- **Initial Setup:** Easy (guided installer)
- **Learning Curve:** Medium (ZFS concepts require study)
- **Configuration:** Primarily web UI

#### Docker/K8s Apps
- **Method:** TrueCharts catalog - one-click app deployment
- **Selection:** 150+ pre-configured apps
- **Limitation:** More rigid than native Docker Compose
- **Use Case:** Simple apps, not complex multi-container stacks

#### VM Hosting
- **Support:** Basic KVM through web UI
- **Limitation:** Less featured than Proxmox
- **Use Case:** Occasional VM, storage is primary

#### GPU Passthrough
- **Support:** Limited - primarily for VMs
- **Docker:** Can pass GPU to containers (manual configuration)

#### Pros
- Best-in-class NAS functionality
- ZFS data protection and features
- Excellent for media servers (Plex, Jellyfin)
- Active development (based on Debian)
- Can run apps via Docker/K8s

#### Cons
- Overkill if you don't need NAS features
- ZFS requires learning (pool design is permanent)
- Docker integration less flexible than native
- Higher hardware requirements (16GB RAM minimum for ZFS)
- Not ideal for general compute workloads

#### When to Choose TrueNAS SCALE
- Network storage is primary use case
- Want ZFS data protection
- Running media server + file shares
- Need snapshot and replication features
- Some Docker apps as secondary feature

#### Not Recommended For
- Pure LLM inference workstation
- Docker-first workflow
- Limited RAM (<32GB)

#### Community & Support
- **Rating:** 5/5 ⭐⭐⭐⭐⭐
- Excellent forum, active development, great documentation

---

### 5. Unraid (PAID: $59-129)

**Best For:** Beginners wanting easy GUI management, flexible storage

#### Pricing (November 2025)
- **Basic:** $59 (up to 6 storage devices)
- **Plus:** $89 (up to 12 storage devices)
- **Pro:** $129 (unlimited storage devices)
- **License:** Lifetime, tied to USB flash drive

#### Core Features
- **Parity-Protected Array:** Drive failure protection without RAID
- **Docker Management:** Excellent GUI for container deployment
- **VM Support:** KVM virtualization with easy GPU passthrough
- **Community Apps:** Huge repository of one-click installs
- **Web UI:** Clean, user-friendly interface
- **Plugin System:** Extend functionality easily

#### Setup Complexity
- **Initial Setup:** Very Easy (guided, graphical)
- **Learning Curve:** Low - most beginner-friendly option
- **Configuration:** Primarily web UI

#### Array Flexibility
- **Unique Feature:** Mix drive sizes without waste
- **Parity:** 1 or 2 parity drives protect against failures
- **Expansion:** Add drives one at a time, any size
- **vs RAID:** More flexible, but slower performance

#### Docker & Apps
- **Support:** Excellent - best GUI for Docker management
- **Community Apps:** 1000+ pre-configured templates
- **One-Click Install:** Plex, Jellyfin, Home Assistant, etc.
- **GPU Support:** Easy passthrough to containers

#### GPU Passthrough
- **Ease:** Best-in-class - checkboxes in web UI
- **Use Case:** Pass GPU to gaming VM or LLM Docker container
- **Limitation:** Single GPU can only go to one destination

#### Pros
- Easiest homelab OS to learn
- Excellent for beginners
- Best Docker container management GUI
- Great community and app ecosystem
- Flexible storage expansion
- Active development and support

#### Cons
- **COSTS MONEY** ($59-129 depending on disk count)
- Array performance slower than RAID
- Not as enterprise-focused as Proxmox
- Limited clustering/HA features
- Requires USB flash drive (single point of failure)

#### Is It Worth The Cost?
**YES if:**
- New to homelabs and want ease-of-use
- Value your time (GUI saves hours of CLI work)
- Want community app templates
- Need flexible storage expansion

**NO if:**
- Comfortable with Linux CLI
- Budget is tight (free alternatives exist)
- Need enterprise features (clustering, HA)
- Prefer pure open-source

#### When to Choose Unraid
- First homelab setup
- Want Docker + VM + NAS in one package
- Value ease of use over cost
- Running media server (very popular use case)
- Need flexible storage that can grow organically

#### Community & Support
- **Rating:** 5/5 ⭐⭐⭐⭐⭐
- Very active forum, YouTube tutorials, responsive developers

---

### 6. CasaOS (FREE)

**Best For:** Absolute beginners, simple Docker app hosting

#### Core Features
- **One-Click Apps:** App store interface for Docker containers
- **Modern Web UI:** Clean, mobile-friendly design
- **File Manager:** Browse server files via browser
- **Simple Networking:** Easy port management
- **Minimal Setup:** Installs on top of existing Debian/Ubuntu

#### Setup Complexity
- **Initial Setup:** Very Easy (one-line install script)
- **Learning Curve:** Lowest of all options
- **Configuration:** All via web UI

#### Docker Support
- **Method:** Wrapper around Docker with GUI
- **App Store:** Growing selection of pre-configured apps
- **Custom:** Can still use Docker Compose manually

#### Limitations
- **Not a Hypervisor:** Cannot run VMs
- **Basic Features:** Lacks advanced options
- **Younger Project:** Less mature than alternatives
- **Community:** Smaller than established projects

#### Pros
- Easiest possible entry to homelab
- Beautiful, intuitive UI
- No learning curve required
- Free and open source
- Good for non-technical users
- Can install on existing system

#### Cons
- Limited features vs Proxmox/Unraid
- No VM support
- Smaller app ecosystem
- Less enterprise-ready
- May outgrow it quickly

#### When to Choose CasaOS
- Complete beginner to Linux/homelabs
- Want to test waters before commitment
- Simple Docker app hosting (Pi-hole, Home Assistant)
- Don't need VMs or advanced features
- Want app-store-like experience

#### Upgrade Path
- CasaOS installs on Ubuntu → can remove it and use Ubuntu directly
- Learn Docker basics, then graduate to Proxmox or native Docker

#### Community & Support
- **Rating:** 3/5 ⭐⭐⭐
- Growing community, good documentation for what it offers

---

### 7. Rocky Linux / AlmaLinux (FREE)

**Best For:** Enterprise training, RHEL compatibility

#### What They Are
- **Rocky Linux:** Community rebuild of Red Hat Enterprise Linux (RHEL)
- **AlmaLinux:** Another RHEL clone, funded by CloudLinux
- **Purpose:** Free RHEL alternative after CentOS discontinued

#### Core Features
- **RHEL Compatibility:** Same packages, same commands
- **Stability:** Enterprise-grade, conservative updates
- **SELinux:** Mandatory Access Control security system
- **Long Support:** 10 years per major version
- **DNF/YUM:** Red Hat package managers (not APT)

#### Setup Complexity
- **Initial Setup:** Easy (similar to other distros)
- **Learning Curve:** Medium-High (if coming from Debian/Ubuntu)
- **Configuration:** CLI-focused

#### When to Choose Over Debian/Ubuntu
- Your job uses RHEL (training on compatible system)
- Need RHEL package compatibility
- Prefer DNF over APT
- Want 10-year support cycle

#### For Homelab LLM Hosting
- **Verdict:** Unnecessary complexity for most users
- Ubuntu/Debian have better GPU driver support
- Smaller homelab community than Ubuntu
- Choose only if RHEL experience is specific goal

#### Pros
- Enterprise-focused (good resume skill)
- Extremely stable
- Long support cycle
- Free RHEL alternative

#### Cons
- Steeper learning curve if Debian/Ubuntu background
- Smaller homelab community
- SELinux can complicate setup
- Less DIY/hobbyist focus

#### Community & Support
- **Rating:** 4/5 ⭐⭐⭐⭐
- Good documentation, but enterprise-focused

---

## Comparison Table

| OS | Ease of Use | VM Support | Docker Support | Storage Features | GPU Passthrough | Best For |
|:---|:------------|:-----------|:---------------|:-----------------|:----------------|:---------|
| **Proxmox VE** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Mixed VM+Container |
| **Ubuntu Server** | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | Docker + LLM hosting |
| **Debian** | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | Stability-focused |
| **TrueNAS SCALE** | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ | NAS + some apps |
| **Unraid** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Beginners, ease of use |
| **CasaOS** | ⭐⭐⭐⭐⭐ | ❌ | ⭐⭐⭐⭐ | ⭐⭐ | ❌ | Absolute beginners |
| **Rocky/Alma** | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | Enterprise training |

---

## Decision Flowchart

### Start Here

**Q1: Is this your first homelab?**
- **YES** → Go to Q2
- **NO** → Go to Q4

**Q2: Do you want to pay for easier experience?**
- **YES** → **Unraid** ($59-129)
- **NO** → Go to Q3

**Q3: Are you comfortable with command line?**
- **YES** → **Ubuntu Server 24.04**
- **NO** → **CasaOS**

**Q4: What's your primary workload?**
- **Network Storage/NAS** → **TrueNAS SCALE**
- **Running VMs** → **Proxmox VE**
- **Docker Containers** → **Ubuntu Server 24.04**
- **Mix of VMs + Docker** → **Proxmox VE**

**Q5: Do you need to learn enterprise skills for work?**
- **RHEL environment** → **Rocky Linux**
- **General DevOps** → **Ubuntu Server 24.04**

---

## Specific Recommendation: LLM Hosting Server

### Best Choice: Ubuntu Server 24.04 LTS

**Why:**
1. **Native Docker Support:** Ollama + OpenWebUI deploy easily
2. **NVIDIA Drivers:** Best GPU driver support of all options
3. **NVIDIA Container Toolkit:** Official GPU passthrough to Docker
4. **LTS Support:** 5 years updates (until 2029)
5. **Large Community:** Most tutorials assume Ubuntu
6. **Latest Kernel:** HWE kernel supports newest hardware

### Setup Steps for LLM Server

```bash
# 1. Install Ubuntu Server 24.04 from USB
# Choose minimal installation, enable SSH

# 2. Update system
sudo apt update && sudo apt upgrade -y

# 3. Install NVIDIA drivers
sudo ubuntu-drivers autoinstall
sudo reboot

# 4. Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# 5. Install NVIDIA Container Toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# 6. Test GPU access in Docker
docker run --rm --gpus all nvidia/cuda:12.0-base-ubuntu22.04 nvidia-smi

# 7. Deploy Ollama + OpenWebUI
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  ollama:
    image: ollama/ollama:latest
    volumes:
      - ./ollama:/root/.ollama
    ports:
      - "11434:11434"
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    restart: unless-stopped

  openwebui:
    image: ghcr.io/open-webui/open-webui:main
    ports:
      - "3000:8080"
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
    volumes:
      - ./openwebui:/app/backend/data
    restart: unless-stopped
EOF

docker compose up -d

# 8. Pull a model and test
docker exec -it ollama-container ollama pull llama3.2:7b

# Access OpenWebUI at http://server-ip:3000
```

### Alternative: If You Want VMs Too

**Use Proxmox VE** → Create Ubuntu Server VM → Pass GPU through → Follow steps above inside VM

This gives you:
- Flexibility to run other VMs (Windows, other Linux distros)
- Snapshot/backup of entire LLM VM
- Ability to test different configurations
- Slightly more overhead, but manageable

---

## Troubleshooting Common Issues

### NVIDIA Drivers Won't Install
```bash
# Check if Secure Boot is enabled (must disable for NVIDIA)
mokutil --sb-state

# If enabled, disable in BIOS/UEFI

# Alternative: Use signed NVIDIA driver
sudo apt install nvidia-driver-535-server
```

### Docker Can't Access GPU
```bash
# Verify NVIDIA Container Toolkit installed
dpkg -l | grep nvidia-container-toolkit

# Check Docker runtime configuration
docker info | grep -i runtime

# Test GPU access
docker run --rm --gpus all nvidia/cuda:12.0-base-ubuntu22.04 nvidia-smi

# If fails, reconfigure
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### Proxmox GPU Passthrough Not Working
```bash
# Enable IOMMU in Proxmox
# Edit /etc/default/grub
# Add: intel_iommu=on (or amd_iommu=on)
update-grub
reboot

# Check IOMMU groups
find /sys/kernel/iommu_groups/ -type l

# If GPU in separate group, can pass through
# If not, may need ACS override patch
```

---

## Summary

**For most LLM homelab users:**
- **Server OS:** Ubuntu Server 24.04 LTS
- **Deployment:** Docker + Docker Compose
- **LLM Stack:** Ollama (backend) + OpenWebUI (frontend)
- **Why:** Simplest path to working LLM inference with GPU acceleration

**Only choose alternatives if:**
- **Proxmox:** You need VMs + containers (more complex)
- **Unraid:** You're willing to pay for ease of use (great for beginners)
- **TrueNAS:** Storage/NAS is primary requirement (not LLM-focused)
- **Debian:** You need absolute stability (slight tradeoff in convenience)

**Avoid for LLM hosting:**
- CasaOS (no VM support, too simple)
- Rocky/Alma (unnecessary complexity, worse GPU support)

---

**Document Version:** 1.0
**Last Updated:** November 7, 2025
**Next Review:** After significant OS releases or 6 months
