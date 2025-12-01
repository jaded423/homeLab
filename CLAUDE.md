# HomeLab Project Documentation

## Table of Contents
- [Overview](#overview)
- [Project Goals](#project-goals)
- [Current Status](#current-status)
- [Network Cheat Sheet](#network-cheat-sheet)
- [Quick Reference](#quick-reference)
- [Documentation Structure](#documentation-structure)
- [Version History](#version-history)

## Overview

This project documents the research, planning, and setup of an affordable but powerful home laboratory environment designed to run local LLMs with medium context sizes.

**Project Type**: Infrastructure / Hardware Research  
**Status**: Proxmox Running - VMs Deployed  
**Budget**: $2,200 (Budget-Conscious Starter Build)

## Project Goals

1. **Server Component**: Reliable server infrastructure for hosting services ✅
2. **LLM Workstation**: Computer capable of running local LLMs with medium context sizes (100k tokens)
3. **Budget-Friendly**: Maximize performance within reasonable cost constraints
4. **Well-Integrated**: Components that work well together with room for growth

## Current Status

**Phase**: Infrastructure Deployed ✅

### Completed
- ✅ Proxmox installed and running on laptop (192.168.2.250)
- ✅ 3 VMs configured (omarchy-desktop, ubuntu-desktop, ubuntu-server)
- ✅ Pi-hole DNS running on Raspberry Pi
- ✅ Twingate zero-trust networking configured
- ✅ Git repos cloned to Proxmox
- ✅ SSH access to Mac via Twingate (works from any network)

### In Progress
- 🔄 Second Proxmox node arriving (more RAM)
- 🔄 Cross-backup between Proxmox nodes planned

### Upcoming
- ⬜ Proxmox cluster or PBS backup setup
- ⬜ LLM workstation build

## Network Cheat Sheet

### Network: 192.168.2.0/24

| Device | IP | Services |
|--------|-----|----------|
| **Router** | 192.168.2.1 | Gateway (TP-Link) |
| **Proxmox Host** | 192.168.2.250 | proxmox-jade.local, SSH |
| **Pi-hole Pi** | 192.168.2.131 | DNS :53, Pi-hole :80/443, MagicMirror :8080, Homarr :7575 |

### Proxmox VMs

| VMID | Name | IP | Status |
|------|------|-----|--------|
| 100 | omarchy-desktop | 192.168.2.161 | Running |
| 101 | ubuntu-desktop | — | Stopped |
| 102 | ubuntu-server | 192.168.2.126 | Running (Twingate connector in Docker) |

### Twingate Remote Access

| Network | Connector Location | Purpose |
|---------|-------------------|---------|
| Home | VM 102 (ubuntu-server) | Primary home access |
| Home | Pi (192.168.2.131) | Redundant home access |
| Mac-Remote | Mac (Docker) | SSH into Mac from anywhere |
| Work | Work PC | Access to work resources |

**To SSH into Mac from anywhere:**
```bash
ssh joshuabrown@mac-ssh.local
```

## Quick Reference

### Key Commands
```bash
# Proxmox VM management
qm list                          # List all VMs
qm start 100                     # Start VM 100
qm stop 100                      # Stop VM 100
qm snapshot 100 snap-name        # Create snapshot
qm rollback 100 snap-name        # Rollback to snapshot

# Twingate
twingate status                  # Check connection status
twingate resources               # List available resources
twingate auth <resource>         # Authenticate to resource

# Check GPU availability (once built)
nvidia-smi

# Monitor system resources
htop

# Check network connectivity
ip addr show
```

### Important Paths

**On Proxmox (192.168.2.250):**
- Git repos: `~/repos/homeLab`, `~/repos/claudeGlobal`
- VM configs: `/etc/pve/qemu-server/`

**On Mac:**
- Projects: `~/projects/homeLab`
- Claude global config: `~/.claude/`

### SSH Access
```bash
# From Mac to Proxmox (via Twingate or local)
ssh root@192.168.2.250

# From Proxmox to Mac (via Twingate - works anywhere)
ssh joshuabrown@mac-ssh.local

# From Proxmox to VMs (local only)
ssh root@192.168.2.161    # omarchy-desktop
ssh root@192.168.2.126    # ubuntu-server
```

## Documentation Structure

**📚 Detailed Documentation**: See the `docs/` directory:

### Core Documents
- **[llm-homelab-research-2025.md](docs/llm-homelab-research-2025.md)** - Comprehensive hardware research
- **[build-plan.md](docs/build-plan.md)** - Build specifications and purchasing guide
- **[homelab-planning-guide.md](docs/homelab-planning-guide.md)** - Infrastructure planning

### Configuration Guides
- **[linux-os-comparison.md](docs/linux-os-comparison.md)** - OS selection analysis
- **[pihole-setup.md](docs/pihole-setup.md)** - Ad blocking DNS setup with DNS-over-TLS
- **[twingate-pihole-setup.md](docs/twingate-pihole-setup.md)** - Secure remote access for Pi-hole

### Meta Documentation
- **[changelog.md](docs/changelog.md)** - Complete version history
- **[Budget homeLab server.md](docs/Budget%20homeLab%20server.md)** - Budget analysis

## Hardware

### Current Infrastructure
- **Proxmox Host**: Laptop at 192.168.2.250 (temporary until 2nd PC arrives)
- **Raspberry Pi**: Pi-hole, MagicMirror, Homarr, Twingate connector
- **Second Proxmox Node**: Ordered from eBay (more RAM) - arriving soon

### Planned Build: Budget-Conscious Starter ($2,200 total)

**LLM Workstation** ($1,350):
- GPU: Used RTX 3090 24GB ($650)
- CPU: AMD Ryzen 5 7600 ($200)
- RAM: 32GB DDR5 ($100)
- Storage: 1TB NVMe ($50)

**Server** ($700):
- Beelink SER7 Mini PC
- AMD Ryzen 7 7735HS
- 32GB RAM, 1TB NVMe

**Networking** ($150):
- 2.5GbE managed switch
- CAT6a cabling

## Version History

**Current Version**: v1.1.0  
**Last Updated**: 2025-12-01

### Recent Changes
- v1.1.0 (2025-12-01): Added network cheat sheet, Proxmox/Twingate setup docs
- v1.0.1 (2025-11-14): Initial documentation structure

**Full changelog**: [docs/changelog.md](docs/changelog.md)

---

*This documentation follows the lean structure pattern with detailed content in `docs/` subdirectory.*
