# HomeLab for Local LLMs - Comprehensive Research Guide
**Research Date:** November 2025
**Target Use Case:** Running local LLMs with medium context sizes (30k-100k tokens)

---

## Executive Summary

Building a homelab for running local LLMs requires careful consideration of GPU VRAM, system architecture, and budget. The **critical bottleneck** for medium-to-long context windows (30k-100k tokens) is GPU VRAM due to the KV Cache, which can consume ~25GB for a 100k context window alone.

**Key Findings:**
- **Minimum VRAM:** 24GB (RTX 3090/4090) for 7B models with 100k context
- **Recommended VRAM:** 48GB (A6000/L40S) for 13B+ models with 100k context
- **Best Value GPU:** Used RTX 3090 24GB ($600-800) - exceptional VRAM-per-dollar
- **Best Performance GPU:** RTX 4090 24GB ($1,600-1,800) - fastest consumer option
- **Total Budget Range:** $2,500 (budget) to $6,000+ (performance tier)

---

## Table of Contents
1. [Understanding VRAM Requirements for Long Context](#1-understanding-vram-requirements)
2. [GPU Options for LLM Inference](#2-gpu-options-for-llm-inference)
3. [Complete System Configurations](#3-complete-system-configurations)
4. [Server Hardware Options](#4-server-hardware-options)
5. [Networking Equipment](#5-networking-equipment)
6. [Software Stack](#6-software-stack)
7. [Budget Optimization & Where to Buy](#7-budget-optimization)
8. [Complete Build Tiers](#8-complete-build-tiers)
9. [Operating Costs](#9-operating-costs)
10. [Upgrade Path Strategy](#10-upgrade-path-strategy)

---

## 1. Understanding VRAM Requirements

### The KV Cache Challenge

The **KV Cache** (Key-Value Cache) is the primary VRAM bottleneck for long context windows. It stores attention keys and values for all previous tokens, growing linearly with context length.

**VRAM Estimation Formula:**
- KV Cache: ~1GB per 4,000 tokens
- For 100k context: ~25GB VRAM for KV Cache alone
- Total VRAM = Model Weights + KV Cache + Overhead

### VRAM Requirements by Model Size & Context

| Model Size | Quantization | Model VRAM | KV Cache (100k) | Total VRAM | Recommended GPU |
|:-----------|:-------------|:-----------|:----------------|:-----------|:----------------|
| **7B** | FP16 (16-bit) | ~14 GB | ~25 GB | **~39 GB** | A6000 / L40S |
| **7B** | 8-bit | ~7 GB | ~25 GB | **~32 GB** | A6000 / L40S |
| **7B** | 4-bit | ~4 GB | ~25 GB | **~29 GB** | A6000 / 3090 w/ offload |
| **13B** | FP16 (16-bit) | ~26 GB | ~25 GB | **~51 GB** | Multi-GPU / Cloud |
| **13B** | 8-bit | ~13 GB | ~25 GB | **~38 GB** | A6000 / L40S |
| **13B** | 4-bit | ~7 GB | ~25 GB | **~32 GB** | A6000 / L40S |
| **30B** | 8-bit | ~30 GB | ~25 GB | **~55 GB** | Multi-GPU / Cloud |
| **30B** | 4-bit | ~15 GB | ~25 GB | **~40 GB** | A6000 / L40S |

**Key Insight:** Even with 4-bit quantization, running 100k context on consumer 24GB cards requires offloading to system RAM, which severely impacts performance.

### Practical Context Window Recommendations

| GPU VRAM | Model Size | Max Practical Context | Performance Notes |
|:---------|:-----------|:----------------------|:------------------|
| **24GB** (RTX 3090/4090) | 7B | ~60k tokens | Good performance |
| **24GB** (RTX 3090/4090) | 7B | ~100k tokens | Requires offloading, slower |
| **24GB** (RTX 3090/4090) | 13B | ~30k tokens | Tight fit, 4-bit required |
| **48GB** (A6000/L40S) | 7B | 100k+ tokens | Excellent performance |
| **48GB** (A6000/L40S) | 13B | ~100k tokens | Good performance |
| **48GB** (A6000/L40S) | 30B | ~50-70k tokens | 4-bit quantization |

---

## 2. GPU Options for LLM Inference

### Consumer GPUs (NVIDIA)

#### NVIDIA RTX 4090 - 24GB VRAM
- **New Price:** $1,600 - $1,800
- **Performance:** Fastest consumer GPU for LLMs (~50 tokens/sec on 7B models)
- **Context Capability:** 7B models up to ~60k comfortably, 100k with offloading
- **Weblinks:**
  - [Newegg - RTX 4090](https://www.newegg.com/p/pl?d=rtx+4090)
  - [Performance Benchmarks](https://hardware-corner.net/llm-inference-performance/comparisons/NVIDIA-RTX-4090-24GB/)
- **Pros:** Best-in-class performance, modern architecture, efficient
- **Cons:** Expensive, 100k context still challenging
- **Recommendation:** Best overall choice if budget allows

#### NVIDIA RTX 3090 / 3090 Ti - 24GB VRAM
- **Used Price:** $600 - $800
- **Performance:** ~70-80% of RTX 4090 speed
- **Context Capability:** Same as 4090 (VRAM-limited, not compute-limited)
- **Weblinks:**
  - [eBay - RTX 3090](https://www.ebay.com/sch/i.html?_nkw=rtx+3090)
  - [Used Price Chart](https://bestvaluegpu.com/history/Nvidia-GeForce-RTX-3090/)
  - [LocalLLM Benchmarks](https://localllm.in/graphs/generation-rtx-3090/)
- **Pros:** **BEST VALUE** - 24GB VRAM at lowest cost
- **Cons:** Older architecture, higher power consumption
- **Recommendation:** **TOP PICK for budget-conscious builders**

#### NVIDIA RTX 4080 Super - 16GB VRAM
- **New Price:** $1,000 - $1,200
- **Performance:** Very fast, but VRAM-limited
- **Context Capability:** Struggles with 100k context on any model
- **Weblinks:** [Best Buy - RTX 4080 Super](https://www.bestbuy.com/site/searchpage.jsp?st=rtx+4080+super)
- **Recommendation:** **NOT RECOMMENDED** for 30k-100k context use case

### Consumer GPUs (AMD)

#### AMD Radeon RX 7900 XTX - 24GB VRAM
- **New Price:** $900 - $1,000
- **Used Price:** $700 - $850
- **Performance:** ~80-95% of RTX 3090 Ti with mature ROCm support
- **Context Capability:** Same VRAM as 3090/4090
- **Weblinks:**
  - [Amazon - RX 7900 XTX](https://www.amazon.com/s?k=rx+7900+xtx)
  - [MLC-LLM Performance](https://mlc.ai/blog/2023/11/10/rx7900xtx-llm-inference)
- **Pros:** Good value, competitive performance with improving software
- **Cons:** ROCm ecosystem less mature than CUDA
- **Recommendation:** Solid AMD alternative, especially if you find a good deal

### Professional / Workstation GPUs

#### NVIDIA RTX A6000 (Ada) / L40S - 48GB VRAM
- **New Price:** $4,500 (L40S) to $6,800 (A6000 Ada)
- **Used Price:** $3,000 - $4,000
- **Performance:** L40S matches RTX 4090 speed with 2x VRAM
- **Context Capability:** 13B models with 100k context, 30B with 70k context
- **Weblinks:**
  - [NVIDIA L40S](https://www.nvidia.com/en-us/data-center/l40s/)
  - eBay for used options
- **Pros:** **Removes VRAM bottleneck**, ECC memory, excellent for serious work
- **Cons:** Very expensive
- **Recommendation:** Best choice for professionals or enthusiasts with budget

---

## 3. Complete System Configurations

### CPU Recommendations

#### AMD Ryzen 9 7950X
- **Price:** ~$450
- **Specs:** 16 cores, 32 threads, 5.7 GHz boost
- **Use Case:** Excellent for CPU inference, multitasking
- **Weblink:** [Amazon - 7950X](https://www.amazon.com/s?k=ryzen+9+7950x)

#### Intel Core i9-14900K
- **Price:** ~$550
- **Specs:** 24 cores (8P+16E), 5.8 GHz boost
- **Use Case:** Top single-thread performance
- **Weblink:** [Amazon - i9-14900K](https://www.amazon.com/s?k=14900k)

#### AMD Threadripper (7000 series)
- **Price:** $1,500+
- **Use Case:** Multi-GPU setups, maximum PCIe lanes
- **Recommendation:** Overkill for most homelab setups

### Memory (RAM) Requirements

| System RAM | Use Case | Notes |
|:-----------|:---------|:------|
| **32GB** | Minimum | Adequate for 7B models with GPU inference |
| **64GB** | Recommended | Sweet spot for most use cases |
| **128GB** | Future-proof | Large models, CPU fallback, multiple VMs |

**Recommendation:** Start with 64GB DDR5-6000 for AM5 (Ryzen) builds

### Motherboard Considerations

- **PCIe 4.0/5.0:** Ensure x16 slot for GPU
- **M.2 Slots:** At least 2x for OS + model storage
- **Quality VRM:** Important for Ryzen 9 / i9 CPUs

**Recommended Boards:**
- **Budget:** Gigabyte B650M DS3H ($130)
- **Mid-Range:** ASRock B650E PG Riptide ($200)
- **High-End:** MSI MAG Z790 TOMAHAWK WIFI ($250)

### Storage Strategy

| Storage Type | Purpose | Recommended Size | Speed |
|:-------------|:--------|:-----------------|:------|
| **NVMe SSD (Primary)** | OS, active models | 1-2TB | Critical |
| **NVMe SSD (Secondary)** | Model library | 2-4TB | Important |
| **SATA SSD** | Less-used models | 2-4TB | Acceptable |
| **HDD (Archive)** | Model archive, backups | 8TB+ | Slow but cheap |

**Model Size Reference:**
- 7B model (4-bit): ~4GB
- 13B model (4-bit): ~7GB
- 30B model (4-bit): ~15GB
- 70B model (4-bit): ~35GB

**Recommendation:** 2-4TB NVMe SSD to store 50-100 models comfortably

### Power Supply Requirements

| GPU | PSU Requirement | Recommended Models |
|:----|:----------------|:-------------------|
| **RTX 3090** | 850W | Corsair RM850e ($130) |
| **RTX 4090** | 1000W | Corsair RM1000e ($180) |
| **L40S** | 1200W | SeaSonic FOCUS Plus 1200W |

**Important:** RTX 4090 requires ATX 3.0 PSU with native 12VHPWR connector

### Cooling Requirements

| Component | Solution | Price |
|:----------|:---------|:------|
| **CPU (Ryzen 7950X, i9-14900K)** | High-end air cooler | $50-80 |
| **CPU (High Load)** | 360mm AIO liquid cooler | $120-160 |
| **GPU** | Case with excellent airflow | $60-160 |

**Recommended Coolers:**
- **Air:** Thermalright Phantom Spirit 120 ($50)
- **AIO:** Arctic Liquid Freezer II 360 ($120)

**Recommended Cases:**
- **Budget:** Phanteks Eclipse G300A ($60)
- **Mid:** Lian Li Lancool 216 ($100)
- **Premium:** Fractal Design Meshify 2 ($160)

---

## 4. Server Hardware Options

### Used Enterprise Servers

#### Dell PowerEdge R730
- **Price:** $375 - $750
- **Specs:** Dual Xeon E5-2680 v4 (28 cores), 64-256GB RAM
- **Storage:** 8-16 drive bays
- **Power:** ~200W idle, 400W+ under load
- **Noise:** **LOUD** - not suitable for living spaces
- **Weblink:** [eBay - R730](https://www.ebay.com/sch/i.html?_nkw=Dell+PowerEdge+R730)
- **Pros:** Best performance per dollar, high RAM capacity
- **Cons:** High power consumption, very noisy
- **Recommendation:** Only if you have a dedicated server room

#### HP ProLiant DL380 Gen9
- **Price:** $200 - $500
- **Specs:** Similar to R730
- **Power & Noise:** Same issues as Dell
- **Weblink:** [eBay - DL380 Gen9](https://www.ebay.com/sch/i.html?_nkw=HP+ProLiant+DL380+Gen9)
- **Pros:** Very affordable
- **Cons:** Known for aggressive fan noise with non-HP components
- **Recommendation:** Budget option for dedicated server room

### Mini PC Servers (Recommended for Homelab)

#### Minisforum MS-01
- **Price:** $800 - $1,200
- **Specs:** Intel i9-13900H, up to 96GB DDR5
- **Storage:** Multiple M.2 NVMe slots
- **Power:** 15-30W idle, ~120W max
- **Noise:** Very quiet
- **Weblink:** [Amazon - MS-01](https://www.amazon.com/s?k=Minisforum+MS-01)
- **Pros:** Excellent performance, power-efficient, quiet, 10GbE networking
- **Cons:** Limited storage bays vs enterprise servers
- **Recommendation:** **BEST choice for home environments**

#### Beelink SER / GTR7 Pro
- **Price:** $600 - $900
- **Specs:** AMD Ryzen 7940HS / 8845HS, up to 64GB DDR5
- **Power:** 8-11W idle, ~95W max
- **Noise:** Very quiet
- **Weblink:** [Amazon - Beelink SER](https://www.amazon.com/s?k=Beelink+SER)
- **Pros:** Great value, very power-efficient
- **Cons:** Lower max RAM than MS-01
- **Recommendation:** Best value mini PC server

#### ASUS NUC (formerly Intel NUC)
- **Price:** $700 - $1,100
- **Specs:** Intel Core Ultra, up to 96GB DDR5
- **Power:** ~10W idle
- **Weblink:** [Newegg - ASUS NUC](https://www.newegg.com/p/pl?d=ASUS+NUC)
- **Pros:** Reliable, well-supported
- **Cons:** More expensive than competitors
- **Recommendation:** Good but pricier alternative

### New Entry-Level Servers

#### HPE ProLiant MicroServer Gen11
- **Price:** $930 - $1,300+
- **Specs:** Xeon E-2414, 16-32GB ECC RAM, 4 drive bays
- **Pros:** Warranty, support, compact, quiet
- **Cons:** Lower performance for price vs mini PCs
- **Weblink:** [HPE MicroServer](https://www.hpe.com/psnow/doc/psn1015037334us-en)
- **Recommendation:** Only if warranty/support is critical

---

## 5. Networking Equipment

### Managed vs Unmanaged Switches

**For HomeLab: Use MANAGED switches**

**Benefits of Managed Switches:**
- **VLANs:** Segment lab network from home devices
- **QoS:** Prioritize LLM workstation traffic
- **Monitoring:** Troubleshoot network issues
- **Port Configuration:** Advanced features

### Network Speed Requirements

| Speed | Use Case | Cost |
|:------|:---------|:-----|
| **1GbE** | Single workstation | $50-100 |
| **2.5GbE** | Fast model transfers from NAS | $100-250 |
| **10GbE** | Multi-machine distributed inference | $400-500 |

**Recommendation:** Start with 1GbE. Upgrade to 2.5GbE if using NAS for model storage.

**Important:** LLM inference bottleneck is GPU VRAM bandwidth (>900 GB/s), not network speed (1.25 GB/s for 10GbE). Network only matters for loading models from storage.

### Recommended Switches

#### Ubiquiti (UniFi) - Premium Ecosystem
- **USW-Flex-2.5G-5:** $49 (5-port 2.5GbE)
- **USW-Flex-2.5G-8-PoE:** $199 (8-port 2.5GbE with PoE)
- **Pros:** Polished ecosystem, unified management
- **Cons:** More expensive

#### TP-Link (Omada) - Best Value
- **DS108-M2:** $100-150 (8-port 2.5GbE, unmanaged)
- **SG3210XHP-M2:** $230 (8-port 2.5GbE + 2x 10GbE SFP+, managed)
- **Pros:** Competitive features, budget-friendly
- **Cons:** Less polished than UniFi
- **Recommendation:** **Best value for homelab**

#### Netgear - 10GbE Options
- **GS110MX:** $450 (8-port 1GbE + 2-port 10GbE)
- **XS716T (used):** ~$400 (16-port 10GbE)
- **Pros:** Affordable 10GbE entry
- **Cons:** Lacks ecosystem of UniFi/Omada

### Cable Recommendations

| Cable Type | Max Distance | Use Case | Price/ft |
|:-----------|:-------------|:---------|:---------|
| **Cat6** | 55m @ 10GbE | Short runs | $0.20 |
| **Cat6a** | 100m @ 10GbE | Recommended standard | $0.40 |
| **Cat7** | 100m @ 10GbE | Overkill, non-standard connectors | $0.80 |

**Recommendation:** Use Cat6a for all new installations

---

## 6. Software Stack

### Virtualization & OS

#### Proxmox VE (Server OS)
- **Cost:** Free
- **Use Case:** Server base OS for managing VMs and containers
- **Features:** KVM (full VMs), LXC (containers), GPU passthrough
- **Weblink:** [Proxmox Official](https://www.proxmox.com/)
- **Recommendation:** **Best choice for homelab server**

#### TrueNAS SCALE (Storage)
- **Cost:** Free
- **Use Case:** Network storage with ZFS
- **Features:** Data integrity, snapshots, Docker/K8s support
- **Deployment:** Can run as VM within Proxmox
- **Weblink:** [TrueNAS SCALE](https://www.truenas.com/truenas-scale/)
- **Recommendation:** Excellent for storage management

#### Ubuntu Server LTS (LLM Host OS)
- **Cost:** Free
- **Use Case:** OS for LLM workstation or VM
- **Features:** Best NVIDIA driver support, large community
- **Alternative:** Debian (more stable, minimal)
- **Weblink:** [Ubuntu Server](https://ubuntu.com/server)
- **Recommendation:** **Best choice for LLM hosting**

### Deployment Strategy

| Method | Performance | Flexibility | Ease of Use | Recommendation |
|:-------|:------------|:------------|:------------|:---------------|
| **Bare Metal** | Best | Low | Medium | Single powerful machine |
| **Docker** | Excellent | High | High | **RECOMMENDED for homelab** |
| **Kubernetes** | Good | Highest | Low | Overkill for single node |

**Recommendation:** Use **Docker** for LLM inference software

### LLM Inference Software

#### Backend Engines

**Ollama** (Recommended for Beginners)
- **Ease of Use:** ⭐⭐⭐⭐⭐
- **Features:** Auto model download, OpenAI-compatible API, CLI + GUI
- **Models:** Supports multimodal, tool-calling, 100+ models
- **Installation:** `curl -fsSL https://ollama.com/install.sh | sh`
- **Weblink:** [Ollama Official](https://ollama.com/)
- **Recommendation:** **Start here - easiest setup**

**llama.cpp** (For Developers)
- **Ease of Use:** ⭐⭐⭐
- **Features:** High performance, CPU + GPU, GGUF format
- **Use Case:** Building custom applications
- **Weblink:** [llama.cpp GitHub](https://github.com/ggerganov/llama.cpp)
- **Recommendation:** For advanced users

**vLLM** (Production-Grade)
- **Ease of Use:** ⭐⭐
- **Features:** High throughput, PagedAttention, production-ready
- **Use Case:** Serving multiple users, maximum performance
- **Weblink:** [vLLM GitHub](https://github.com/vllm-project/vllm)
- **Recommendation:** For performance-critical deployments

**LocalAI** (Multi-Model Support)
- **Ease of Use:** ⭐⭐⭐⭐
- **Features:** OpenAI API compatible, LLM + image + audio
- **Use Case:** Developers wanting API compatibility
- **Weblink:** [LocalAI GitHub](https://github.com/mudler/LocalAI)

#### Frontend Web UIs

**OpenWebUI** (Recommended)
- **Ease of Use:** ⭐⭐⭐⭐⭐
- **Features:** Modern UI, RAG, multi-user, image generation
- **Backend Support:** Ollama, OpenAI-compatible APIs
- **Installation:** `docker run -d -p 3000:8080 ghcr.io/open-webui/open-webui:main`
- **Weblink:** [OpenWebUI GitHub](https://github.com/open-webui/open-webui)
- **Recommendation:** **Best overall web UI**

**text-generation-webui** (Power Users)
- **Ease of Use:** ⭐⭐⭐
- **Features:** Highly customizable, extensions, advanced controls
- **Use Case:** Power users wanting maximum control
- **Weblink:** [text-generation-webui GitHub](https://github.com/oobabooga/text-generation-webui)

#### Recommended Stack

**Beginner-Friendly:**
```bash
# Install Ollama (backend)
curl -fsSL https://ollama.com/install.sh | sh

# Run OpenWebUI (frontend)
docker run -d -p 3000:8080 --gpus all \
  ghcr.io/open-webui/open-webui:main

# Download a model
ollama pull llama3.2:7b
```

**Access:** http://localhost:3000

---

## 7. Budget Optimization

### Where to Buy

#### New Equipment
- **Amazon:** Broad selection, fast shipping
  - [Amazon.com](https://amazon.com)
- **Newegg:** Tech-focused, competitive pricing
  - [Newegg.com](https://newegg.com)
- **B&H Photo:** Excellent for workstations
  - [BHPhotoVideo.com](https://bhphotovideo.com)
- **Micro Center:** Best for in-store CPU/mobo bundles
  - [MicroCenter.com](https://microcenter.com)

#### Used Enterprise (Servers)
- **TechMikeNY:** Top-rated refurbished servers
  - [TechMikeNY.com](https://techmikeny.com)
- **ServerMonkey:** Tested and guaranteed
  - [ServerMonkey.com](https://servermonkey.com)
- **eBay:** Good for deals, use PayPal protection
  - Look for TechMikeNY's eBay store

#### Used Consumer (GPUs, Components)
- **r/hardwareswap:** Reddit community marketplace
  - [reddit.com/r/hardwareswap](https://reddit.com/r/hardwareswap)
- **eBay:** Use PayPal Goods & Services
- **Facebook Marketplace:** Local deals, test before buying
- **Craigslist:** Same as Facebook, meet in public place

### November 2025 Sales Events
- **Black Friday:** November 28, 2025
- **Cyber Monday:** December 1, 2025
- **Deals running:** Throughout November on all major sites
- **Expected discounts:** GPUs (NVIDIA 50-series, AMD 9000-series), SSDs, CPUs

### New vs Used Strategy

#### Buy NEW (Priority Items)
1. **GPUs** - Warranty critical, unless excellent deal on used 3090
2. **SSDs** - Too risky used due to wear/failure potential
3. **PSUs** - Safety and stability critical
4. **Motherboards** - Warranty important for troubleshooting

#### Buy USED (Safe Bets)
1. **Enterprise Servers** - Best value (R730, DL380)
2. **RAM** - Very reliable, rarely fails
3. **Enterprise HDDs** - Buy refurbished from reputable sellers
4. **Consumer CPUs** - Safe if from trusted source

#### Special Case: Used RTX 3090
- **Recommendation:** Excellent value at $600-800
- **Check:** Mining history (undervolted mining cards can be fine)
- **Verify:** Test thoroughly upon receipt, use PayPal protection
- **Warranty:** None, but savings justify risk for many

---

## 8. Complete Build Tiers

### Budget Tier: ~$2,500 Total

**Goal:** Maximum VRAM for minimum cost, capable of 7B models with 60k+ context

#### LLM Workstation - $1,350

| Component | Model | Price | Link |
|:----------|:------|:------|:-----|
| **GPU** | Used RTX 3090 24GB | $650 | [eBay](https://ebay.com/sch/i.html?_nkw=rtx+3090) |
| **CPU** | AMD Ryzen 5 7600 | $200 | [Amazon](https://amazon.com/s?k=ryzen+5+7600) |
| **Motherboard** | Gigabyte B650M DS3H | $130 | [Newegg](https://newegg.com/p/N82E16813145413) |
| **RAM** | 32GB DDR5-6000 | $100 | [Amazon](https://amazon.com/s?k=32gb+ddr5+6000) |
| **SSD** | Crucial P3 Plus 1TB NVMe | $60 | [Amazon](https://amazon.com/s?k=crucial+p3+plus+1tb) |
| **PSU** | Corsair RM750e 750W | $100 | [Newegg](https://newegg.com/p/N82E16817139309) |
| **Case** | Phanteks Eclipse G300A | $60 | [Newegg](https://newegg.com/p/N82E16811854128) |
| **Cooler** | Thermalright Phantom Spirit | $50 | [Amazon](https://amazon.com/s?k=thermalright+phantom+spirit) |

**Total: $1,350**

#### Server - $1,050

| Component | Model | Price | Link |
|:----------|:------|:------|:-----|
| **Base Server** | Dell R730xd 24-Bay (2x E5-2680 v4) | $400 | [TechMikeNY](https://techmikeny.com/dell-poweredge-r730xd-24-bay-sff/) |
| **RAM** | 128GB DDR4 ECC (8x16GB) | $250 | [eBay](https://ebay.com/sch/i.html?_nkw=128gb+ddr4+ecc+ram) |
| **OS Storage** | 2x 480GB Enterprise SATA SSD | $100 | [TechMikeNY](https://techmikeny.com/480gb-enterprise-sata-ssd/) |
| **Data Storage** | 4x 4TB Refurb SAS HDD | $300 | [eBay](https://ebay.com/sch/i.html?_nkw=4tb+sas+hdd) |

**Total: $1,050**

**Grand Total: $2,400**

**Capabilities:**
- Run 7B models with ~60k context smoothly
- 100k context possible with offloading (slower)
- Plenty of server resources for Proxmox, TrueNAS, Docker containers
- **Power:** ~850W full load

---

### Mid Tier: ~$4,000 Total

**Goal:** Modern GPU with excellent performance, robust server

#### LLM Workstation - $2,190

| Component | Model | Price | Link |
|:----------|:------|:------|:-----|
| **GPU** | RTX 4080 Super 16GB | $1,100 | [Best Buy](https://bestbuy.com/site/searchpage.jsp?st=rtx+4080+super) |
| **CPU** | AMD Ryzen 7 7800X3D | $350 | [Amazon](https://amazon.com/s?k=7800x3d) |
| **Motherboard** | ASRock B650E PG Riptide | $200 | [Newegg](https://newegg.com/p/N82E16813162080) |
| **RAM** | 32GB DDR5-6000 CL30 | $110 | [Amazon](https://amazon.com/s?k=32gb+ddr5+6000+cl30) |
| **SSD** | WD_BLACK SN850X 2TB NVMe | $150 | [Amazon](https://amazon.com/s?k=sn850x+2tb) |
| **PSU** | SeaSonic FOCUS Plus 850W | $130 | [Newegg](https://newegg.com/p/N82E16817151186) |
| **Case** | Lian Li Lancool 216 | $100 | [Newegg](https://newegg.com/p/N82E16811112631) |
| **Cooler** | Thermalright Phantom Spirit | $50 | [Amazon](https://amazon.com/s?k=thermalright+phantom+spirit) |

**Total: $2,190**

#### Server - $1,850

| Component | Model | Price | Link |
|:----------|:------|:------|:-----|
| **Base Server** | Dell R740xd 24-Bay (2x Xeon Silver) | $800 | [TechMikeNY](https://techmikeny.com/dell-poweredge-r740xd-24-bay-sff/) |
| **RAM** | 256GB DDR4 ECC (8x32GB) | $500 | [eBay](https://ebay.com/sch/i.html?_nkw=256gb+ddr4+ecc+ram) |
| **OS Storage** | 2x 960GB Enterprise SATA SSD | $150 | [TechMikeNY](https://techmikeny.com/960gb-enterprise-sata-ssd/) |
| **Data Storage** | 4x 8TB Refurb SAS HDD | $400 | [eBay](https://ebay.com/sch/i.html?_nkw=8tb+sas+hdd) |

**Total: $1,850**

**Grand Total: $4,040**

**Capabilities:**
- Faster inference than budget tier
- 16GB VRAM limits long context work (NOT ideal for 100k context goal)
- Excellent for gaming + moderate LLM use
- More powerful server with ample RAM
- **Power:** ~1,050W full load
- **NOTE:** Consider downgrading to used RTX 3090 to get same 24GB VRAM at lower cost

---

### Performance Tier: ~$6,000 Total

**Goal:** Top consumer hardware, professional-grade server

#### LLM Workstation - $3,600

| Component | Model | Price | Link |
|:----------|:------|:------|:-----|
| **GPU** | RTX 4090 24GB | $1,800 | [Newegg](https://newegg.com/p/pl?d=rtx+4090) |
| **CPU** | Intel i9-14900K | $550 | [Amazon](https://amazon.com/s?k=14900k) |
| **Motherboard** | MSI MAG Z790 TOMAHAWK WIFI | $250 | [Newegg](https://newegg.com/p/N82E16813144566) |
| **RAM** | 64GB DDR5-6400 | $200 | [Amazon](https://amazon.com/s?k=64gb+ddr5+6400) |
| **SSD** | Samsung 990 Pro 4TB NVMe | $300 | [Amazon](https://amazon.com/s?k=samsung+990+pro+4tb) |
| **PSU** | Corsair RM1000e 1000W | $180 | [Newegg](https://newegg.com/p/N82E16817139310) |
| **Case** | Fractal Design Meshify 2 | $160 | [Newegg](https://newegg.com/p/N82E16811352132) |
| **Cooler** | Arctic Liquid Freezer II 360 | $160 | [Amazon](https://amazon.com/s?k=arctic+liquid+freezer+ii+360) |

**Total: $3,600**

#### Server - $3,150

| Component | Model | Price | Link |
|:----------|:------|:------|:-----|
| **Base Server** | Dell R740xd (2x Xeon Gold 6138) | $1,200 | [TechMikeNY](https://techmikeny.com/dell-poweredge-r740xd-24-bay-sff/) |
| **RAM** | 512GB DDR4 ECC (16x32GB) | $900 | [eBay](https://ebay.com/sch/i.html?_nkw=512gb+ddr4+ecc+ram) |
| **OS Storage** | 2x 1.92TB Enterprise SATA SSD | $250 | [TechMikeNY](https://techmikeny.com/1.92tb-enterprise-sata-ssd/) |
| **Data Storage** | 8x 8TB Refurb SAS HDD | $800 | [eBay](https://ebay.com/sch/i.html?_nkw=8tb+sas+hdd) |

**Total: $3,150**

**Grand Total: $6,750**

**Capabilities:**
- Fastest consumer GPU for LLM inference
- 24GB VRAM for 7B models with 60k-100k context
- Top-tier CPU for any workload
- Massive server RAM for extensive virtualization
- **Power:** ~1,300W full load
- **Note:** Still VRAM-limited for 100k context on larger models

---

### Professional Tier: ~$8,000+ (Optional)

**For 48GB VRAM (True 100k Context Freedom):**

Replace GPU in Performance Tier with:
- **NVIDIA L40S 48GB:** $4,500 new
- **Used RTX A6000 48GB:** $3,000-4,000

**Total Adjustment:** +$2,000-$2,700

**This enables:**
- 13B models with full 100k context
- 30B models with 50-70k context
- No compromise on context length

---

## 9. Operating Costs

### Power Consumption Estimates

| Tier | Workstation (Load) | Server (Load) | Total Load | Idle Power |
|:-----|:-------------------|:--------------|:-----------|:-----------|
| **Budget** | ~550W | ~300W | **~850W** | ~200W |
| **Mid** | ~650W | ~400W | **~1,050W** | ~250W |
| **Performance** | ~800W | ~500W | **~1,300W** | ~300W |

### Annual Electricity Costs

**Assumptions:**
- Electricity rate: $0.17/kWh (US average)
- Usage: 8 hours/day full load, 16 hours/day idle

| Tier | Daily kWh | Monthly kWh | Annual Cost |
|:-----|:----------|:------------|:------------|
| **Budget** | 9.8 kWh | 294 kWh | **~$600/year** |
| **Mid** | 12.4 kWh | 372 kWh | **~$760/year** |
| **Performance** | 15.2 kWh | 456 kWh | **~$930/year** |

### Cost Optimization Tips

1. **Idle Power Management:**
   - Configure aggressive CPU C-states
   - Use power management tools
   - Consider mini PC server instead of enterprise rack server (save ~$200/year)

2. **Smart Usage:**
   - Power down server when not needed
   - Use power scheduling with wake-on-LAN
   - Leverage renewable energy if available

3. **Cooling:**
   - Performance tier may need dedicated cooling (portable AC/mini-split)
   - Estimate additional $100-200/year for cooling in hot climates

---

## 10. Upgrade Path Strategy

### Phase 1: Get Started Quickly

**Priority:** Build LLM workstation first

**Recommended Budget Tier Start:**
- Used RTX 3090 24GB: $650
- Ryzen 5 7600 + B650M board: $330
- 32GB DDR5: $100
- 1TB NVMe SSD: $60
- PSU + Case + Cooler: $210

**Total: $1,350** - Immediately functional for LLM work

**Benefits:**
- Working system in days
- Learn LLM inference software
- Determine actual needs before buying server

### Phase 2: Add Server Infrastructure

**Timeline:** 3-6 months later

**Options:**
1. **Mini PC Server:** Beelink/Minisforum ($600-900)
   - Quiet, efficient, perfect for home
2. **Enterprise Server:** Dell R730xd ($400-800)
   - More performance, but noisy and power-hungry

**Add to server:**
- Network storage (TrueNAS)
- VM management (Proxmox)
- Docker containers for services

### Easy Future Upgrades (In Order of Priority)

1. **RAM** (Easiest)
   - Workstation: 32GB → 64GB ($100-150)
   - Server: Add more DIMMs as needed
   - **Impact:** Run larger models, more VMs

2. **Storage** (Simple)
   - Add 2-4TB NVMe SSD for model library ($150-300)
   - Add HDDs to server for bulk storage
   - **Impact:** Store more models, data

3. **GPU** (Moderate)
   - Sell RTX 3090, buy RTX 4090 (~$1,000 net)
   - Or save for L40S 48GB for true 100k context
   - **Impact:** Faster inference, longer context

4. **Server Expansion** (Ongoing)
   - Add more drives as storage needs grow
   - Upgrade server RAM for more VMs

### Future-Proofing Decisions

**At Initial Purchase:**

1. **Motherboard**
   - Get PCIe 5.0 support (future GPUs)
   - Ensure sufficient M.2 slots (4+ ideal)
   - **Cost:** +$50-100
   - **Benefit:** Easy GPU/storage upgrades

2. **PSU Over-Provisioning**
   - Buy 850W for RTX 3090 (only needs 750W)
   - Buy 1000W+ for future RTX 5090
   - **Cost:** +$30-50
   - **Benefit:** Future GPU upgrade without PSU replacement

3. **Case with Good Airflow**
   - Supports large coolers and GPUs
   - **Cost:** +$40-60
   - **Benefit:** Accommodate future hardware

4. **Server with Many Drive Bays**
   - R730xd/R740xd has 24 bays
   - **Cost:** $0 (same price as 8-bay)
   - **Benefit:** Trivial storage expansion

### When to Upgrade vs Buy New

**Upgrade the existing system if:**
- Core components (mobo/CPU) still relevant (< 3 years old)
- Bottleneck is clear (GPU VRAM, storage space)
- Incremental upgrade cost < 50% of new build

**Build new system if:**
- Platform is outdated (DDR4 → DDR5, PCIe 3.0 → 5.0)
- Multiple components need replacement
- New use case requires different architecture

---

## Conclusion & Recommendations

### For Your Specific Use Case (30k-100k Token Context)

**The Hard Truth:**
- **100k context is VRAM-intensive:** Even 7B models need ~29GB total with 4-bit quantization
- **24GB GPUs are tight:** RTX 3090/4090 can do 60k comfortably, 100k with compromises
- **48GB is the sweet spot:** L40S/A6000 removes all VRAM anxiety for 100k context

### Recommended Build Path

#### Option A: Budget-Conscious ($2,400)
```
✓ Used RTX 3090 24GB ($650)
✓ Ryzen 5 7600 system ($700)
✓ Mini PC server - Beelink ($700-900)
= Ready for 7B models, 60k context, room to experiment
```

**Upgrade later:** Save for L40S 48GB when you need true 100k context on larger models

#### Option B: Performance-First ($3,600)
```
✓ RTX 4090 24GB ($1,800)
✓ Ryzen 7 7800X3D system ($1,800)
= Fastest consumer option, same VRAM limits as 3090
```

**When to choose:** You value speed and plan to stay with 7B-13B models

#### Option C: No-Compromise ($7,000+)
```
✓ NVIDIA L40S 48GB ($4,500)
✓ High-end Ryzen/Intel system ($2,500)
✓ Mini PC or enterprise server ($1,000)
= Run ANY model size with 100k context
```

**When to choose:** Professional use, budget allows, want zero compromises

### My Top Recommendation

**Start with Budget Tier + Mini PC:**
- **LLM Workstation:** Used RTX 3090 24GB build ($1,350)
- **Server:** Beelink SER ($700)
- **Network:** TP-Link Omada 2.5GbE switch ($150)
- **Total:** ~$2,200

**Why:**
1. **Immediate capability:** Run 7B models with 60k context right away
2. **Learn the limits:** Understand what 24GB can/can't do before spending $4,500 on L40S
3. **Quiet & efficient:** Mini PC server perfect for home (vs loud enterprise rack)
4. **Clear upgrade path:** L40S upgrade when you need it, keep everything else

**When to upgrade to 48GB:**
- You regularly hit VRAM limits
- You need 13B+ models with 100k context
- Your use case justifies the $4,500 investment

---

## Additional Resources

### Communities & Forums
- **r/LocalLLaMA:** Reddit community for local LLM enthusiasts
- **r/homelab:** Homelab hardware and software discussions
- **Ollama Discord:** [discord.gg/ollama](https://discord.gg/ollama)

### Benchmarking Tools
- **Hardware Corner LLM Benchmarks:** [hardware-corner.net/llm-inference-performance](https://hardware-corner.net/llm-inference-performance)
- **LocalLLM.in:** [localllm.in/graphs](https://localllm.in/graphs)

### Learning Resources
- **Proxmox Documentation:** [pve.proxmox.com/wiki](https://pve.proxmox.com/wiki)
- **Ollama Documentation:** [github.com/ollama/ollama](https://github.com/ollama/ollama)
- **OpenWebUI Docs:** [docs.openwebui.com](https://docs.openwebui.com)

### Price Tracking
- **PCPartPicker:** [pcpartpicker.com](https://pcpartpicker.com)
- **CamelCamelCamel:** Amazon price history
- **r/buildapcsales:** Real-time deal alerts

---

## Document Version

**Version:** 1.0
**Last Updated:** November 7, 2025
**Research Completed:** November 7, 2025
**Next Update:** March 2026 (or when significant price/product changes occur)

---

**Note:** Prices and availability subject to change. Always verify current prices before purchasing. This research represents market conditions as of November 2025.
