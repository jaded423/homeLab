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
