---
type: concept
title: GPU Passthrough (two setups)
tags: [gpu, passthrough, vfio, nvidia, m4000, intel-arc, nvenc, maxwell, ollama, nvidia-smi]
related: [vm101-ubuntu, vm100-omarchy, tower, book5]
---

Two GPUs in the homelab are passed through to VMs, each vfio-bound on its host and handed to exactly one guest. **tower's Quadro M4000 → [[vm101-ubuntu]]** (compute: Ollama, steam-headless, whisper). **book5's Intel Arc iGPU → [[vm100-omarchy]]** (desktop/game rig). The recurring theme across both is a driver/encoder wall: the M4000's Maxwell architecture is EOL, so its NVENC is blocked and GPU-accelerated workloads that need the encoder fall back to CPU.

## The two setups at a glance

| GPU | Host | → VM | Host binding | Guest driver | Encoder / limitation |
|-----|------|------|--------------|--------------|----------------------|
| NVIDIA Quadro M4000 (8GB, Maxwell) | [[tower]] | [[vm101-ubuntu]] (101) | vfio-pci | nvidia-driver-535 / CUDA 12.2 | NVENC walled by Maxwell EOL → software x264 |
| Intel Arc iGPU (Lunar Lake) | [[book5]] | [[vm100-omarchy]] (100) | passthrough | `xe` | works for desktop/encode; btop reads only `i915` → no GPU panel |

---

## M4000 → VM101 (on tower)

The Quadro M4000 (8GB GDDR5, 1664 CUDA cores, Maxwell) is vfio-bound on [[tower]] and passed to VM 101 for LLM inference (Ollama), the steam-headless game-stream rig, and whisper transcription.

**Status:** Fully operational (completed Dec 20, 2025).

| Component | Setting |
|-----------|---------|
| Host driver | vfio-pci (passthrough to VM) |
| VM driver | nvidia-driver-535.274.02, CUDA 12.2 |
| IOMMU group | 45 (GPU + Audio isolated) |
| VM machine type | q35 (required for PCIe passthrough) |
| VM network interface | `enp6s18` (changed from `ens18` due to q35) |

### Host configuration (tower)

`/etc/default/grub`:
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"
```

`/etc/modprobe.d/vfio.conf`:
```
options vfio-pci ids=10de:13f1,10de:0fbb
softdep nouveau pre: vfio-pci
softdep snd_hda_intel pre: vfio-pci
```

`/etc/modprobe.d/blacklist-nouveau.conf`:
```
blacklist nouveau
blacklist nvidiafb
options nouveau modeset=0
```

VM 101 PCI config:
```
hostpci0: 0000:01:00,pcie=1,x-vga=1
machine: q35
```

### Maxwell EOL — the NVENC wall

The M4000 is **Maxwell**, which NVIDIA has declared EOL. **Its NVENC hardware encoder is walled off**, so anything on VM101 that would normally offload encode to the GPU falls back to CPU:

- **steam-headless** (Sunshine game-stream rig) — NVENC blocked → **software x264** encode.
- **whisper** (faster-whisper transcription) — GPU walled by Maxwell → **CPU-only** (distil-large-v3 int8, 24-thread ≈ 4.1× realtime).

The GPU still works for **CUDA compute** (Ollama inference is unaffected — see below); it's specifically the video encoder that's off-limits.

### btop GPU panel (1.4.7 source build)

VM101 is the **only** VM with a host-visible GPU, so it's the only one that gets a GPU panel in btop. Getting it required a source build:

- GPU-enabled btop **1.4.7** built from source (`GPU_SUPPORT=true`, `CXX=g++-14`) at **`/usr/local/bin/btop`** — renders the M4000 box (util / vram / temp / clocks).
- Old **snap btop removed** — `/snap/bin` beat `/usr/local/bin` in the login-shell PATH and shadowed the source build, so the GPU box went missing.
- **GOTCHA:** the official btop **static release ships `GPU_SUPPORT=false`** (musl can't dlopen glibc NVML) → must build from source. Needs **g++ ≥ 14** (1.4.7 uses C++23 `std::ranges::to`; stock g++-13 fails).

> Neither host (tower, book5) shows a btop GPU panel — tower's M4000 is vfio-bound to the VM, and book5's iGPU is passed through to omarchy. See the omarchy `xe`-driver note below for why VM100 has no panel either.

### Ollama LLM inference

CUDA compute is fully available. Models that fit in 8GB VRAM run entirely on GPU; larger ones use hybrid GPU/CPU offload via `num_gpu`.

| Model | VRAM Used | Prompt Eval | Token Gen |
|-------|-----------|-------------|-----------|
| llama3.2:3b | 4.2 GB | 78 tok/s | 25 tok/s |
| qwen2.5:7b | 6.8 GB | 104 tok/s | 12 tok/s |
| phi4:14b | N/A | N/A | Exceeds 8GB |

- **Full GPU:** all models ≤7B
- **Hybrid GPU/CPU:** 14B–18B via `-hybrid` variants (`num_gpu 24` or lower)
- **CPU only:** 19GB+ models (slow: 70B = 1.47 tok/s)

Pre-configured hybrid models: `phi4-hybrid` (24 layers, ~7.9GB, 2x), `qwen3-hybrid` (24, ~7.9GB, ~2x), `devstral-hybrid` (20, ~6GB, ~1.5x).

```bash
# Pre-configured hybrid
ollama run phi4-hybrid "Your prompt"

# Manual GPU layers
ollama run phi4:14b "prompt" --num-gpu 24

# Via API
curl http://localhost:11434/api/generate -d '{
  "model": "phi4:14b",
  "prompt": "...",
  "options": {"num_gpu": 24}
}'
```

Quick hybrid variant (only stores config, not duplicate weights):
```bash
ssh jaded@192.168.68.101 'cat > /tmp/Modelfile << EOF
FROM model-name:tag
PARAMETER num_gpu 24
EOF
ollama create model-hybrid -f /tmp/Modelfile'
```

`num_gpu` guidelines: 1–3B → 99 (all, 2–4GB) · 7B → 30–35 (6–8GB) · 14B → 24–26 (7–8GB) · 30B+ → 18–22 (7–8GB).

### Verification

```bash
# GPU status in VM
ssh jaded@192.168.68.101 "nvidia-smi"

# VRAM usage
ssh jaded@192.168.68.101 "nvidia-smi --query-gpu=memory.used,memory.total --format=csv"

# Test Ollama GPU
ssh jaded@192.168.68.101 "ollama run llama3.2:3b 'Hello' --verbose 2>&1 | grep 'eval rate'"

# Check host vfio binding
ssh root@192.168.68.249 "lspci -nnk -s 01:00 | grep 'driver in use'"
# Should show: vfio-pci
```

### Troubleshooting

**GPU not showing in VM:**
```bash
lspci -nnk -s 01:00       # Host: check vfio binding
dmesg | grep -i dmar      # Verify IOMMU enabled
```

**nvidia-smi not working:**
```bash
lspci | grep -i nvidia    # Check visible
lsmod | grep nvidia       # Check driver
sudo apt install --reinstall nvidia-driver-535
```

**Network broken after passthrough:** q35 changes network device names. Check `ip link` for the new name (e.g. `enp6s18`), update `/etc/netplan/*.yaml`, then `sudo netplan apply`.

**14B+ models crashing:** M4000 = 8GB VRAM. Use hybrid mode (`num_gpu 24` or lower); 19GB+ models require `num_gpu 0` (CPU only).

> **VFIO/IOMMU regression note:** tower's kernel is pinned to `6.17.4-2-pve` because 6.17.13 was hanging the host every 1–3 days — hypothesized to be a VFIO/IOMMU regression on this M4000 passthrough. Details on [[tower]].

---

## Intel Arc iGPU → VM100 (on book5)

book5's Intel Arc integrated GPU (Lunar Lake — Arc 130V/140V) is passed through to VM 100 (omarchy), the desktop / game-stream rig. Full working GPU passthrough with hardware VAAPI encode.

- **Guest driver:** `xe` (Intel's newer Xe kernel driver).
- **btop has no GPU panel:** omarchy runs GPU-enabled btop, but its Arc uses the **`xe` driver** while **btop only reads `i915`** → no panel renders. (This is a btop limitation, not a passthrough fault — the GPU itself works.)

Detail on the omarchy side — VAAPI encode, Sunshine/Moonlight game-streaming, GPU-fixed RAM allocation — lives on [[vm100-omarchy]] and [[book5]].

---

## Sources

- `~/.claude/docs/homelab/gpu-passthrough.md`
- `~/projects/homeLab/CLAUDE.md` — Operational Current State (VM101 services, btop GPU panel note, tower kernel pin)
