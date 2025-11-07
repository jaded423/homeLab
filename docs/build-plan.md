# HomeLab Build Plan & Action Guide

**Created:** November 7, 2025
**Based on:** Comprehensive market research of November 2025

## Executive Summary

After extensive research, here's your personalized build plan for running local LLMs with medium-to-large context sizes (30k-100k tokens).

**Key Insight:** The 100k context requirement is **VRAM-intensive**. Even a 7B parameter model needs ~29GB total VRAM (4GB model + 25GB KV Cache) for 100k tokens. This means 24GB GPUs (RTX 3090/4090) will be tight, requiring offloading to system RAM which slows inference significantly.

---

## Recommended Build: Budget-Conscious Starter ($2,200)

This configuration gets you started immediately while leaving a clear upgrade path to 48GB VRAM when needed.

### Build Specifications

#### LLM Workstation - $1,350

| Component | Model | Price | Why This Choice |
|:----------|:------|:------|:----------------|
| **GPU** | Used RTX 3090 24GB | $650 | Best VRAM-per-dollar, handles 7B@60k comfortably |
| **CPU** | AMD Ryzen 5 7600 | $200 | Sufficient for GPU inference, modern AM5 platform |
| **Motherboard** | Gigabyte B650M DS3H | $130 | PCIe 4.0, good VRM, upgrade path to Ryzen 9 |
| **RAM** | 32GB DDR5-6000 | $100 | Minimum for LLM hosting, expandable to 128GB |
| **SSD** | Crucial P3 Plus 1TB NVMe | $60 | Fast enough for model loading, affordable |
| **PSU** | Corsair RM750e 750W | $100 | Reliable, efficient, powers RTX 3090 |
| **Case** | Phanteks Eclipse G300A | $60 | Good airflow for GPU cooling |
| **Cooler** | Thermalright Phantom Spirit | $50 | Excellent air cooler, quiet operation |

**Workstation Total: $1,350**

#### Server Component - $700

| Component | Model | Price | Why This Choice |
|:----------|:------|:------|:----------------|
| **Mini PC** | Beelink SER7 (Ryzen 7 7840HS) | $700 | Quiet, power-efficient, 64GB RAM support |

**Includes:**
- AMD Ryzen 7 7840HS (8 cores, 16 threads)
- 32GB DDR5 RAM (expandable to 64GB)
- 500GB NVMe SSD
- 2.5GbE networking
- WiFi 6E
- ~8-11W idle, ~95W max power

**Server Total: $700**

#### Networking - $150

| Component | Model | Price | Why This Choice |
|:----------|:------|:------|:----------------|
| **Switch** | TP-Link DS108-M2 (8-port 2.5GbE) | $150 | Affordable 2.5GbE for fast model transfers |

**Alternative:** Start with existing 1GbE switch (free), upgrade later if needed.

---

### Total Investment: $2,200

**What You Get:**
- Workstation capable of running 7B models with ~60k context smoothly
- 100k context possible (with slower performance due to offloading)
- Quiet mini PC server for Proxmox, Docker, TrueNAS
- Modern, upgradeable platform (AM5, DDR5, PCIe 4.0)
- Power-efficient for home use (~600W max, ~200W idle)

**Annual Operating Cost:** ~$600/year in electricity (@$0.17/kWh, 8hr/day use)

---

## What This Setup Can Do

### Immediately Capable Of:

✅ **7B Models:**
- Full 60k context at good speed (30-40 tokens/sec)
- 100k context possible (15-20 tokens/sec with offloading)
- Examples: Llama 3.2 7B, Mistral 7B, Qwen 7B

✅ **13B Models:**
- Comfortable at 30k context (20-25 tokens/sec)
- Tight at 60k+ context (requires aggressive quantization)
- Examples: Llama 2 13B, Vicuna 13B

✅ **Server Capabilities:**
- Proxmox VE for VM management
- TrueNAS for network storage
- Docker containers for services
- Home automation, media server, etc.

### Limitations:

⚠️ **VRAM Bottleneck:**
- 30B+ models limited to 30-40k context
- 100k context on 7B models requires offloading (slower)
- True 100k context freedom requires 48GB GPU upgrade

⚠️ **Not Suitable For:**
- Running multiple concurrent models
- 70B+ models (need 48GB+ VRAM)
- Production workloads with many users

---

## Purchase Links & Ordering Guide

### Where to Buy Each Component

#### GPU - Used RTX 3090 24GB ($650)

**Primary Option:**
- [eBay RTX 3090 Search](https://ebay.com/sch/i.html?_nkw=rtx+3090)
- **Price Range:** $600-800
- **Protection:** Use PayPal Goods & Services
- **What to Check:** Test immediately, watch for mining cards (not necessarily bad if undervolted)

**Alternative Option:**
- [r/hardwareswap](https://reddit.com/r/hardwareswap)
- **Benefits:** Community reputation, can negotiate
- **Safety:** Use PayPal, check seller karma

**New Option (Budget Stretch):**
- RTX 4080 Super 16GB: $1,100 new
- **Note:** Less VRAM (16GB vs 24GB), not recommended for your use case

#### CPU, Motherboard, RAM Bundle

**Option 1: Buy Separately**
- CPU: [AMD Ryzen 5 7600 on Amazon](https://amazon.com/s?k=ryzen+5+7600) - $200
- Motherboard: [Gigabyte B650M DS3H on Newegg](https://newegg.com/p/N82E16813145413) - $130
- RAM: [32GB DDR5-6000 on Amazon](https://amazon.com/s?k=32gb+ddr5+6000) - $100

**Option 2: Micro Center Bundle** (If near a store)
- [Micro Center CPU/Mobo Bundles](https://microcenter.com)
- Often $50-100 savings on CPU+mobo combo

#### Storage

- **SSD:** [Crucial P3 Plus 1TB on Amazon](https://amazon.com/s?k=crucial+p3+plus+1tb) - $60
- **Alternative:** WD Blue SN580 1TB - $55

#### Power Supply

- **Recommended:** [Corsair RM750e on Newegg](https://newegg.com/p/N82E16817139309) - $100
- **Alternative:** EVGA SuperNOVA 750 GT - $90

#### Case

- **Recommended:** [Phanteks Eclipse G300A on Newegg](https://newegg.com/p/N82E16811854128) - $60
- **Alternative:** Fractal Design Focus G - $65

#### Cooler

- **Recommended:** [Thermalright Phantom Spirit on Amazon](https://amazon.com/s?k=thermalright+phantom+spirit) - $50
- **Alternative:** Deepcool AK620 - $55

#### Server - Beelink SER7

- **Primary:** [Beelink SER7 on Amazon](https://amazon.com/s?k=Beelink+SER7) - $700
- **Configuration:** 32GB RAM, 500GB SSD
- **Alternative:** Minisforum MS-01 - $900 (more expandable)

#### Networking Switch

- **Recommended:** [TP-Link DS108-M2 on Amazon](https://amazon.com/s?k=tp-link+2.5gbe+switch) - $150
- **Budget Option:** Start with existing 1GbE switch, upgrade later

---

## Step-by-Step Build & Setup Process

### Phase 1: Research & Purchase (Week 1)

**Day 1-2: Shopping**
1. **Start with GPU** (longest to find good deal)
   - Set eBay alerts for RTX 3090 under $700
   - Check r/hardwareswap daily
   - Target: $600-650 for used card in good condition

2. **Order other components**
   - Use PCPartPicker to verify compatibility
   - Order from Amazon/Newegg for fast shipping
   - Consider Micro Center if nearby for bundle deals

3. **Order server**
   - Beelink SER7 from Amazon
   - Usually 2-3 day shipping

**Budget Check:** Confirm total is within $2,200-2,500 range

### Phase 2: Hardware Assembly (Week 2)

**Day 1: Workstation Build**

1. **Prepare workspace**
   - Clear, well-lit area
   - Anti-static mat or wrist strap (optional but recommended)
   - Phillips screwdriver

2. **Install components** (order matters!)
   ```
   1. Install PSU in case
   2. Install motherboard standoffs
   3. Install CPU on motherboard (outside case)
   4. Install RAM
   5. Install CPU cooler
   6. Install motherboard in case
   7. Install SSD in M.2 slot
   8. Install GPU
   9. Connect all cables (24-pin, 8-pin CPU, PCIe power)
   10. Connect case front panel headers
   ```

3. **First boot test**
   - Connect monitor, keyboard, mouse
   - Power on - should POST to BIOS
   - **Troubleshooting:** If no display, reseat RAM and GPU

**Day 2: Server Setup**

1. **Unbox Beelink SER7**
   - Already assembled, just needs OS

2. **Test mini PC**
   - Connect monitor, power on
   - Verify it boots

### Phase 3: Software Installation (Week 2-3)

#### Workstation Setup

**Step 1: Install Ubuntu Server 24.04 LTS**

```bash
# Download Ubuntu Server ISO
# Create bootable USB with Rufus (Windows) or Balena Etcher (Mac)
# Boot from USB, select "Install Ubuntu Server"
# During install:
# - Hostname: llm-workstation
# - Username: your_name
# - Install OpenSSH server: Yes
# - Install Docker: Yes
```

**Step 2: Install NVIDIA Drivers**

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install NVIDIA driver
sudo apt install nvidia-driver-550 -y

# Reboot
sudo reboot

# Verify GPU is detected
nvidia-smi
# Should show RTX 3090 with 24GB VRAM
```

**Step 3: Install Docker & NVIDIA Container Toolkit**

```bash
# Install Docker (if not already installed)
sudo apt install docker.io docker-compose -y

# Add your user to docker group
sudo usermod -aG docker $USER

# Install NVIDIA Container Toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt update
sudo apt install nvidia-container-toolkit -y

# Restart Docker
sudo systemctl restart docker

# Test GPU in Docker
docker run --rm --gpus all nvidia/cuda:12.0-base-ubuntu22.04 nvidia-smi
# Should show GPU info
```

**Step 4: Install Ollama (LLM Backend)**

```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Test Ollama
ollama --version

# Pull a test model
ollama pull llama3.2:7b

# Test inference
ollama run llama3.2:7b "Hello, how are you?"
```

**Step 5: Install OpenWebUI (Frontend)**

```bash
# Run OpenWebUI with Docker
docker run -d -p 3000:8080 \
  --name open-webui \
  --gpus all \
  --add-host=host.docker.internal:host-gateway \
  -v open-webui:/app/backend/data \
  ghcr.io/open-webui/open-webui:main

# Access OpenWebUI
# Open browser: http://llm-workstation:3000
# Create account (first user becomes admin)
```

#### Server Setup (Beelink SER7)

**Step 1: Install Proxmox VE**

```bash
# Download Proxmox VE ISO from proxmox.com
# Create bootable USB
# Boot from USB, install Proxmox

# During install:
# - Hostname: homelab-server
# - IP: 192.168.1.100 (use your network range)
# - Gateway: 192.168.1.1 (your router)
# - DNS: 8.8.8.8

# After install, access web UI
# https://192.168.1.100:8006
```

**Step 2: Initial Proxmox Configuration**

```bash
# Update Proxmox (via web UI or SSH)
apt update && apt upgrade -y

# Remove enterprise repo (if not subscribed)
rm /etc/apt/sources.list.d/pve-enterprise.list

# Add no-subscription repo
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > \
  /etc/apt/sources.list.d/pve-install-repo.list

apt update
```

**Step 3: Create TrueNAS VM (Optional)**

```bash
# Download TrueNAS SCALE ISO
# In Proxmox web UI:
# 1. Upload ISO
# 2. Create new VM
# 3. Assign 8GB RAM, 2 cores
# 4. Install TrueNAS
# 5. Configure storage pools
```

### Phase 4: Testing & Optimization (Week 3)

**Test 1: LLM Inference Performance**

```bash
# On workstation, test different models
ollama pull llama3.2:7b
ollama pull mistral:7b
ollama pull llama2:13b

# Benchmark (rough timing)
time ollama run llama3.2:7b "Write a 500 word essay about AI"

# Monitor GPU usage
watch -n 1 nvidia-smi
```

**Test 2: Context Window Scaling**

```bash
# Create a long context test
# Generate 30k token prompt (use GPT-4 or Claude to create)
# Test inference at different context lengths:
# - 8k tokens
# - 30k tokens
# - 60k tokens
# - 100k tokens (expect slowdown)

# Measure tokens/sec at each level
```

**Test 3: Server Workloads**

```bash
# On Proxmox server, create test VMs
# Deploy Docker containers
# Monitor resource usage
```

### Phase 5: Production Setup (Week 4)

**Workstation Configuration**

1. **Set up model library**
   ```bash
   # Create model storage directory
   mkdir -p ~/llm-models

   # Pull your favorite models
   ollama pull llama3.2:7b
   ollama pull mistral:7b
   ollama pull codellama:13b
   ollama pull llama2:13b
   ```

2. **Configure OpenWebUI**
   - Set up user accounts
   - Configure model settings
   - Enable RAG (Retrieval Augmented Generation)
   - Set up document uploads

3. **Set up backups**
   ```bash
   # Backup script for models
   rsync -avz ~/.ollama/models/ user@homelab-server:/backups/llm-models/
   ```

**Server Configuration**

1. **Deploy services**
   - Docker containers for any services
   - Configure networking
   - Set up backups

2. **Configure automated backups**
   - Use Proxmox Backup Server or
   - Script rsync backups to external drive

---

## Upgrade Path Strategy

### Phase 1: Immediate Build (Now) - $2,200

What you're building above. Gets you working immediately.

### Phase 2: Short-Term Upgrades (3-6 months) - $250-500

**Priority 1: More Storage ($150-300)**
- Add 2TB NVMe SSD for model library
- Store 50-100 models locally

**Priority 2: More RAM ($100-150)**
- Upgrade workstation to 64GB DDR5
- Better for 100k context offloading

**Priority 3: Server Storage ($200-400)**
- Add HDDs to server for TrueNAS
- 2x 4TB drives in mirror for backups

### Phase 3: Major Upgrade (12-18 months) - $2,500-4,500

**Option A: GPU Upgrade to RTX 4090 ($1,000 net)**
- Sell RTX 3090 for $500-600
- Buy RTX 4090 for $1,600
- Benefit: 2x faster inference, same 24GB VRAM
- Best for: Speed matters more than context length

**Option B: GPU Upgrade to L40S 48GB ($3,000 net)**
- Sell RTX 3090 for $500-600
- Buy L40S 48GB for $4,500
- Benefit: True 100k context on 13B+ models, no compromises
- Best for: Need longer context, larger models

**Recommendation:** Start with cheap 3090. After 6-12 months of use, you'll know if you need:
- **Faster inference** → RTX 4090
- **More VRAM** → L40S 48GB
- **Nothing** → Stick with 3090, it's working fine

---

## Alternative Build Options

### If Budget is Tighter ($1,500-1,800)

**Option A: Workstation Only**
- Build just the LLM workstation ($1,350)
- Skip dedicated server initially
- Run Proxmox/Docker on the workstation
- Add server later when budget allows

**Option B: Smaller Server**
- Swap Beelink SER7 ($700) for:
  - Used Dell R730 ($400) - powerful but loud
  - Cheaper mini PC ($400-500) - less powerful

### If Budget Allows More ($3,000-4,000)

**Option A: RTX 4090 Build**
- Upgrade GPU to RTX 4090 ($1,800)
- Better CPU: Ryzen 7 7800X3D ($350)
- 64GB RAM ($200)
- 2TB SSD ($150)
- Same server ($700)
- **Total:** ~$3,600
- **Benefit:** Fastest consumer inference

**Option B: Better Server**
- Keep workstation as-is ($1,350)
- Upgrade to Minisforum MS-01 ($1,200)
  - More RAM capacity (96GB)
  - More storage bays
  - 10GbE networking
- Add 10GbE switch ($400)
- **Total:** ~$3,200
- **Benefit:** More robust infrastructure

---

## Expected Timeline

| Phase | Duration | Tasks |
|:------|:---------|:------|
| **Research & Purchase** | Week 1 | Find GPU deal, order components |
| **Hardware Assembly** | Week 2 | Build workstation, set up server |
| **Software Installation** | Week 2-3 | Install OS, drivers, LLM software |
| **Testing & Learning** | Week 3-4 | Test models, learn tools, optimize |
| **Production Use** | Week 4+ | Daily use, gather experience |
| **First Upgrade** | Month 3-6 | Add storage, RAM as needed |
| **Major Upgrade** | Month 12-18 | GPU upgrade if needed |

**Total Time to Working System:** 2-3 weeks

---

## Cost Breakdown Summary

### Initial Investment

| Category | Item | Cost |
|:---------|:-----|:-----|
| **GPU** | Used RTX 3090 24GB | $650 |
| **CPU/Mobo** | Ryzen 5 7600 + B650M | $330 |
| **RAM** | 32GB DDR5-6000 | $100 |
| **Storage** | 1TB NVMe SSD | $60 |
| **PSU** | 750W 80+ Gold | $100 |
| **Case** | ATX with good airflow | $60 |
| **Cooler** | Tower air cooler | $50 |
| **Server** | Beelink SER7 | $700 |
| **Networking** | 2.5GbE switch | $150 |
| | **TOTAL** | **$2,200** |

### Operating Costs

| Cost Type | Annual Amount |
|:----------|:--------------|
| Electricity (8hr/day use) | $600 |
| Internet (no change) | $0 |
| Cooling (minimal AC impact) | $50-100 |
| **Total Annual Operating Cost** | **~$700/year** |

### Optional Upgrades (6-12 months)

| Upgrade | Cost |
|:--------|:-----|
| 2TB SSD for models | $150 |
| 32GB→64GB RAM | $150 |
| Server storage (2x4TB HDD) | $200 |
| **Total Optional Upgrades** | **$500** |

### Major Upgrade Path (12-18 months)

| Option | Cost | Benefit |
|:-------|:-----|:--------|
| RTX 4090 upgrade (sell 3090) | $1,000 net | 2x speed, same VRAM |
| L40S 48GB upgrade (sell 3090) | $3,000 net | 100k context freedom |

---

## Risk Assessment & Mitigation

### Main Risks

**1. Used GPU Failure**
- **Risk Level:** Low-Medium
- **Likelihood:** 5-10% in first year
- **Mitigation:**
  - Buy from reputable eBay sellers (>99% feedback)
  - Use PayPal Goods & Services (buyer protection)
  - Test immediately upon receipt
  - Budget $100 for extended warranty (SquareTrade)

**2. VRAM Insufficient for 100k Context**
- **Risk Level:** Medium
- **Likelihood:** High for 13B+ models
- **Mitigation:**
  - Start with 7B models (proven to work)
  - Plan for L40S upgrade if needed
  - Use 4-bit quantization aggressively

**3. Noise from Server**
- **Risk Level:** Low (with mini PC)
- **Likelihood:** Very low with Beelink SER7
- **Mitigation:**
  - Chose mini PC over enterprise server
  - Can add sound dampening if needed

**4. Higher Than Expected Power Bill**
- **Risk Level:** Low
- **Likelihood:** Medium (depends on usage)
- **Mitigation:**
  - Monitor power with smart plugs
  - Power down when not in use
  - Conservative estimate: $600/year

**5. Complexity Overwhelming**
- **Risk Level:** Medium for beginners
- **Likelihood:** Depends on experience
- **Mitigation:**
  - Excellent documentation available
  - Active communities (r/LocalLLaMA, r/homelab)
  - Start simple, add complexity gradually
  - This guide provides step-by-step instructions

### Warranty Coverage

| Component | Warranty | Source |
|:----------|:---------|:-------|
| Used RTX 3090 | None | Personal risk |
| New Components | 1-3 years | Manufacturer |
| Beelink SER7 | 1 year | Manufacturer |

**Recommendation:** Budget extra $200 for component replacement in year 1

---

## Success Metrics

### After Week 4 (Initial Setup Complete):

- ✅ Workstation can run 7B models smoothly
- ✅ 60k context inference working
- ✅ OpenWebUI accessible and configured
- ✅ Server running Proxmox with Docker
- ✅ Basic monitoring set up

### After Month 3 (Production Use):

- ✅ Using LLMs daily for work/projects
- ✅ Understand VRAM limitations firsthand
- ✅ Have experience with 5-10 different models
- ✅ Server hosting 3-5 services
- ✅ Know if upgrade needed

### After Month 12 (Mature Setup):

- ✅ Decided on GPU upgrade path (or satisfied with 3090)
- ✅ Have workflow dialed in
- ✅ Infrastructure stable and reliable
- ✅ ROI positive vs cloud LLM costs

---

## Comparison: HomeLab vs Cloud LLMs

### Cost Analysis (12 Months)

**HomeLab:**
- Initial investment: $2,200
- Operating costs: $700/year
- **Year 1 Total:** $2,900
- **Year 2 Total:** $700
- **Year 3 Total:** $700

**Cloud LLMs (Claude/GPT-4):**
- Heavy use: ~$200-500/month
- **Year 1 Total:** $2,400-6,000
- **Year 2 Total:** $2,400-6,000
- **Year 3 Total:** $2,400-6,000

**Break-Even:** 12-15 months for heavy users, 24-30 months for moderate users

### Benefits of HomeLab:

✅ **Privacy:** Your data never leaves your hardware
✅ **No Rate Limits:** Run as many queries as you want
✅ **Customization:** Fine-tune models for your use case
✅ **Learning:** Hands-on experience with ML infrastructure
✅ **Long-Term Savings:** Cloud costs add up over time

### Benefits of Cloud:

✅ **Latest Models:** GPT-4, Claude 3.5 access immediately
✅ **No Maintenance:** Someone else handles infrastructure
✅ **Scalability:** Easy to scale up/down
✅ **No Upfront Cost:** Pay as you go

**Recommendation:** Use **both**. HomeLab for bulk work, privacy-sensitive tasks, and experimentation. Cloud for latest models and high-complexity reasoning.

---

## Next Steps

### Immediate Actions (This Week)

1. **Set eBay alerts** for RTX 3090 under $700
   - [Create eBay saved search](https://ebay.com/sch/i.html?_nkw=rtx+3090)
   - Enable daily email notifications

2. **Create PCPartPicker list** with all components
   - [PCPartPicker](https://pcpartpicker.com)
   - Verify compatibility
   - Track prices

3. **Join communities** for support
   - [r/LocalLLaMA](https://reddit.com/r/LocalLLaMA) - LLM enthusiasts
   - [r/homelab](https://reddit.com/r/homelab) - Homelab hardware/software
   - [Ollama Discord](https://discord.gg/ollama) - Ollama support

4. **Review research document** thoroughly
   - [llm-homelab-research-2025.md](llm-homelab-research-2025.md)
   - Understand VRAM requirements deeply
   - Note alternative components

5. **Decide on budget**
   - Confirm $2,200 budget works
   - Or adjust to $1,500 (workstation only) or $3,500 (RTX 4090)

### Week 1: Purchasing

1. **Buy GPU** (most time-sensitive)
   - Target: Used RTX 3090 for $600-650
   - Use PayPal Goods & Services
   - Verify seller reputation

2. **Order other components**
   - Use Amazon Prime for fast shipping
   - Consider Micro Center bundle if nearby

3. **Order server**
   - Beelink SER7 from Amazon
   - Usually 2-3 day delivery

### Week 2-3: Build & Setup

Follow detailed instructions in "Step-by-Step Build & Setup Process" section above.

### Week 4+: Learn & Optimize

- Test different models
- Experiment with context lengths
- Join community discussions
- Document your experience
- Share findings with others

---

## Questions to Consider Before Building

1. **Do I have space for the equipment?**
   - Workstation: Standard desktop PC size
   - Server: Small (5"x5"x2")
   - Total: Can fit on a desk

2. **Is my electrical circuit adequate?**
   - Peak load: ~850W (workstation + server)
   - Idle: ~200W
   - Standard 15A circuit handles this easily

3. **Do I have good internet?**
   - Initial setup: Need to download 20-30GB (models, OS)
   - Ongoing: Minimal bandwidth needed
   - LAN only after setup

4. **What's my cooling situation?**
   - Room temperature impact: ~200-400W heat output
   - Similar to having 2-3 people in the room
   - May need fan or AC in small room

5. **Do I have time to learn?**
   - Initial learning curve: 20-40 hours over first month
   - Ongoing maintenance: 2-4 hours/month
   - Worth it if using regularly

6. **Am I comfortable with command line?**
   - Required: Basic Linux comfort
   - Learnable: Excellent resources available
   - Alternative: Use OpenWebUI web interface primarily

---

## Conclusion

You now have a comprehensive, actionable plan to build a powerful homeLab for running local LLMs with medium-to-large context sizes.

**The Path Forward:**

1. **Start with $2,200 budget build** (RTX 3090 + Ryzen 5 7600 + Beelink SER7)
2. **Learn the limitations** of 24GB VRAM over 6-12 months
3. **Upgrade to L40S 48GB** if you need true 100k context freedom
4. **Enjoy privacy, no rate limits, and long-term cost savings**

This approach minimizes risk, maximizes learning, and provides a clear upgrade path. You'll have hands-on experience with local LLM inference while keeping costs reasonable.

**You're ready to start shopping!**

---

## Appendix: Additional Resources

### Documentation
- Full research: [llm-homelab-research-2025.md](llm-homelab-research-2025.md)
- Project overview: [../CLAUDE.md](../CLAUDE.md)

### Communities
- [r/LocalLLaMA](https://reddit.com/r/LocalLLaMA) - Local LLM enthusiasts
- [r/homelab](https://reddit.com/r/homelab) - Homelab hardware & software
- [r/buildapc](https://reddit.com/r/buildapc) - PC building help
- [Ollama Discord](https://discord.gg/ollama) - Ollama support
- [ServeTheHome Forums](https://forums.servethehome.com) - Server hardware

### Tools
- [PCPartPicker](https://pcpartpicker.com) - Parts compatibility & pricing
- [CamelCamelCamel](https://camelcamelcamel.com) - Amazon price tracking
- [Hardware Corner LLM Benchmarks](https://hardware-corner.net/llm-inference-performance) - GPU benchmarks
- [LocalLLM.in](https://localllm.in/graphs) - Community benchmarks

### Learning Resources
- [Proxmox VE Documentation](https://pve.proxmox.com/wiki)
- [Ollama Documentation](https://github.com/ollama/ollama)
- [OpenWebUI Docs](https://docs.openwebui.com)
- [llama.cpp Documentation](https://github.com/ggerganov/llama.cpp)

### Price Tracking & Deals
- [r/buildapcsales](https://reddit.com/r/buildapcsales) - Real-time deals
- [Slickdeals](https://slickdeals.net) - Tech deals
- [TechBargains](https://techbargains.com) - Component deals

---

**Document Version:** 1.0
**Last Updated:** November 7, 2025
**Next Review:** After purchase completion or in 30 days
