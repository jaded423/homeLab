# HomeLab Project Documentation

## Table of Contents
- [Overview](#overview)
- [Project Goals](#project-goals)
- [Current Status](#current-status)
- [Quick Reference](#quick-reference)
- [Documentation Structure](#documentation-structure)
- [Version History](#version-history)

## Overview

This project documents the research, planning, and setup of an affordable but powerful home laboratory environment designed to run local LLMs with medium context sizes.

**Project Type**: Infrastructure / Hardware Research
**Status**: Research Complete - Ready for Hardware Purchase
**Budget**: $2,200 (Budget-Conscious Starter Build)

## Project Goals

1. **Server Component**: Reliable server infrastructure for hosting services
2. **LLM Workstation**: Computer capable of running local LLMs with medium context sizes (100k tokens)
3. **Budget-Friendly**: Maximize performance within reasonable cost constraints
4. **Well-Integrated**: Components that work well together with room for growth

## Current Status

**Phase**: Research Complete ✅ → **Ready for Hardware Purchasing** 🛒

### Recommended Build: Budget-Conscious Starter ($2,200 total)

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

## Quick Reference

### Key Commands
```bash
# Check GPU availability (once built)
nvidia-smi

# Monitor system resources
htop

# Check network connectivity
ip addr show
```

### Important Paths
- Research docs: `docs/llm-homelab-research-2025.md`
- Build guide: `docs/build-plan.md`
- OS comparison: `docs/linux-os-comparison.md`
- Network setup: `docs/twingate-pihole-setup.md`

## Documentation Structure

**📚 Detailed Documentation**: See the `docs/` directory:

### Core Documents
- **[llm-homelab-research-2025.md](docs/llm-homelab-research-2025.md)** - Comprehensive hardware research (883 lines)
- **[build-plan.md](docs/build-plan.md)** - Build specifications and purchasing guide (851 lines)
- **[homelab-planning-guide.md](docs/homelab-planning-guide.md)** - Infrastructure planning (763 lines)

### Configuration Guides
- **[linux-os-comparison.md](docs/linux-os-comparison.md)** - OS selection analysis (678 lines)
- **[pihole-setup.md](docs/pihole-setup.md)** - Ad blocking DNS setup (472 lines)
- **[twingate-pihole-setup.md](docs/twingate-pihole-setup.md)** - Secure remote access (472 lines)

### Meta Documentation
- **[changelog.md](docs/changelog.md)** - Complete version history
- **[Budget homeLab server.md](docs/Budget homeLab server.md)** - Budget analysis

## Key Insights from Research

- **VRAM Requirements**: 100k context needs ~25GB VRAM for KV Cache alone
- **Best Value GPU**: Used RTX 3090 24GB offers best VRAM-per-dollar
- **Server Choice**: Mini PCs provide excellent efficiency for home use
- **Networking**: 2.5GbE provides headroom without excessive cost

## Next Steps

1. ✅ Research complete
2. 🔄 **Purchase hardware** (current phase)
3. ⬜ Assembly and setup
4. ⬜ OS installation (likely Proxmox)
5. ⬜ Service deployment (Ollama, OpenWebUI, etc.)

## Version History

**Current Version**: v1.0.1
**Last Updated**: 2025-11-14

**Full changelog**: [docs/changelog.md](docs/changelog.md)

### Recent Updates
- 2025-11-14 - [MINOR] Added Pi-hole documentation and Twingate remote access setup
- 2025-11-14 - [MINOR] Documentation optimized and restructured
- 2025-11-07 - [MAJOR] Project initialized with comprehensive research

### 2025-11-14 - Pi-hole Documentation and Twingate Integration

**Changes:**
- Created comprehensive Pi-hole setup documentation (`docs/pihole-setup.md`)
- Created Twingate remote access setup guide (`docs/twingate-pihole-setup.md`)
- Investigated and documented existing Pi-hole DNS-over-TLS configuration
- Updated global homelab documentation with Pi-hole IP address (192.168.1.191)
- Discovered and documented dnsdist DoT configuration on port 8853

**Impact:**
- Complete documentation of existing Pi-hole setup with DNS-over-TLS
- Clear guide for setting up Twingate resources for remote Pi-hole access
- Identified DNS record mismatch issue (pihole.jadedviber.com → 35.147.140.96 vs actual home IP)
- Enables secure remote DNS and ad-blocking via Twingate Zero Trust network
- Future-ready for Pi 5 migration with documented setup steps

**Files created:**
- `docs/pihole-setup.md` - Complete Pi-hole configuration, DoT setup, troubleshooting (472 lines)
- `docs/twingate-pihole-setup.md` - Step-by-step Twingate resource setup guide (472 lines)

**Files modified:**
- `~/.claude/docs/homelab.md` - Added Pi-hole IP (192.168.1.191) to infrastructure overview

---

*This documentation follows the lean structure pattern with detailed content in `docs/` subdirectory.*