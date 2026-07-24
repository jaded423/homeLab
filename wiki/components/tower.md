---
type: component
title: tower (Proxmox Node 2)
tags:
  - proxmox
  - node
  - host
  - gpu
  - nfs
  - media
related:
  - book5
  - vm101-ubuntu
  - vm111-homeassistant
  - gpu-passthrough
  - watchdogs
  - access-model
  - network-topology
  - storage
host: tower
ip: 192.168.68.249
---

# tower (prox-tower)

Proxmox VE node 2 of the 2-node cluster. Lenovo ThinkStation P510 tower workstation —
the compute/media host. Runs [[vm101-ubuntu]] (media + Frigate + Mullvad, gets the M4000
GPU) and [[vm111-homeassistant]]. Node sibling = [[book5]].

**Access:** `ssh tower` (Tailscale bare alias) / `ssh root@192.168.68.249` / web UI
`https://prox-tower:8006`. Full access model → [[access-model]].

## Hardware

| Component | Details |
|-----------|---------|
| Model | Lenovo ThinkStation P510 |
| CPU | Intel Xeon E5-2667 v4 (16 cores / 32 threads, 3.2 GHz) |
| RAM | 78 GB DDR4 ECC |
| GPU | NVIDIA Quadro M4000 (8 GB VRAM) — **vfio-bound, passed through to [[vm101-ubuntu]]** |
| Storage | 370 GB SSD (ZFS `rpool`) + 4 TB HDD (`media-pool`) |

**RAM allocation:** VM 101 = 48 GB · ZFS ARC = 18 GB · host/overhead = 12 GB.

## Network interfaces (two NICs)

| Interface | Chipset / driver | Speed | Bridge | Role |
|-----------|------------------|-------|--------|------|
| `nic0` / Intel I218-LM | `e1000e` | 1 Gbps | vmbr0 | Internet, management, Twingate (192.168.68.249) |
| Realtek RTL8125 (TP-Link TX201) | `r8169` | 2.5 Gbps | vmbr1 (`enp2s0`) | **Primary** — VM taps + inter-node link to book5 |

> NOTE: The deep doc labels vmbr1 the "inter-node link (10.10.10.2/30)". Per the
> authoritative current state (2026-06-19), vmbr1 (2.5 G, r8169) is now the **primary**
> bridge that VM 101 + VM 111 taps attach to — see the tap-master gotcha below.

⚠️ **VM tap-master gotcha (2026-06-19):** during the post-outage cable reroute, tower's
VM taps were stranded on the 1 G `vmbr0` (VM 101 had silently been on 1 GbE the whole
time). Both VM 101 + VM 111 were merged onto the 2.5 G `vmbr1`. The runtime fix was:

```bash
ip link set tapNi0 master vmbr1
```

This is **runtime-only**. The VM `net0` configs already point at `vmbr1`, so a clean boot
*should* reattach — but they stranded once. **After any tower reboot / power event, verify
tap masters:**

```bash
bridge link show | grep tap
```

(~25% STO throughput gain was a side effect of the 2.5 G merge.)

### Intel I218-LM TSO bug

TCP Segmentation Offload on the Intel NIC causes network hangs requiring a physical reboot.
Fixed in `/etc/network/interfaces`:

```
post-up ethtool -K nic0 tso off gso off gro off
```

Verify after boot (all should read `off`):

```bash
ethtool -k nic0 | grep -E 'tcp-seg|generic'
```

## Storage

| Pool | Devices | Size | Purpose |
|------|---------|------|---------|
| `rpool` | 370 GB SSD | 370 GB | System, VM disks |
| `media-pool` | 4 TB HDD | 3.5 TB usable | Media, Ollama models, Frigate |

`media-pool` layout (`/media-pool/{media,ollama,frigate}`) is exported to VM 101 over NFS
(async, ~130 MB/s). More on tiers → [[storage]].

```bash
# /etc/exports (example)
# /media-pool/media   192.168.68.101(rw,async,no_subtree_check)
# /media-pool/ollama  192.168.68.101(rw,async,no_subtree_check)
# /media-pool/frigate 192.168.68.101(rw,async,no_subtree_check)
```

## GPU passthrough

Quadro M4000 is vfio-bound on the host and passed through to [[vm101-ubuntu]] (Ollama /
Frigate / steam-headless). Host must show `Kernel driver in use: vfio-pci`:

```bash
lspci -nnk | grep -A3 NVIDIA
```

Full setup, Maxwell-EOL NVENC limits, and the book5 iGPU counterpart → [[gpu-passthrough]].

## What it hosts

| VMID | Name | IP | Notes |
|------|------|-----|-------|
| 101 | Ubuntu Server | 192.168.68.101 | 48 GB / 28 vCPU, auto-start. Media + Frigate + Mullvad + M4000. → [[vm101-ubuntu]] |
| 111 | home-assistant | 192.168.68.111 | Renamed from 112 → 111 on 2026-05-27 (moved from book5). → [[vm111-homeassistant]] |

## Services

| Service | Purpose |
|---------|---------|
| Proxmox web UI (8006) | Cluster management |
| SSH (22) | Remote management |
| NFS server | `media-pool` exports to VM 101 |
| Twingate connector | jaded423 network access |
| `fix-docker-forward.service` | iptables FORWARD fix (below) |

### fix-docker-forward.service

`/etc/systemd/system/fix-docker-forward.service` — allows iptables FORWARD between
[[book5]] (192.168.68.250) and VM 101 (192.168.68.101). Required because Docker sets the
FORWARD policy to DROP, which blocks Twingate-routed cross-host traffic. *(Contains
iptables rules — update if Docker or the subnet changes.)*

### Twingate connector

```bash
systemctl status twingate-connector
systemctl restart twingate-connector
journalctl -u twingate-connector -f
```

Weekly auto-update: Sunday 3:15 AM (15 min after book5), log `/var/log/twingate-upgrade.log`.
Skip before travel with `OOO` (creates `/var/log/twingate-skip-upgrade`).

## Crash instrumentation + kernel pin

Tower hung hard every 1–3 days with **no logs** after the 2026-03-24 dist-upgrade
(kernel 6.17.4 → 6.17.13) — suspected kernel regression interacting with the VFIO M4000
passthrough. Mitigation is a **pinned known-good kernel + loud-panic + remote-syslog**
instrumentation so the next hang isn't silent. One-line summary here; full runbook,
book5 receiver, and pstore forensics → [[watchdogs]].

- **Kernel pinned to `6.17.4-2-pve`:**
  ```bash
  proxmox-boot-tool kernel pin 6.17.4-2-pve
  ```
  Do NOT unpin until 6.17.14+ ships AND is verified several days on [[book5]] first.
  (>5 days uptime on 6.17.4 confirms the regression hypothesis.)
- **Loud panics + auto-reboot:** `/etc/sysctl.d/99-tower-debug.conf` sets
  `softlockup_panic=1`, `hardlockup_panic=1`, `panic=30`, `panic_print=13`.
- **Remote syslog → book5:** `/etc/rsyslog.d/30-forward-to-book5.conf` forwards all syslog
  (incl. kernel via `/dev/kmsg`) to `book5:514/UDP`. After a hang, on book5:
  ```bash
  tail -200 /var/log/tower-remote.log
  ```
- **pstore** mounted at `/sys/fs/pstore` (in `/etc/fstab`) — panic logs survive reboot as
  `dmesg-*` files.
- `lm-sensors` installed (cores ~45 °C idle, NIC PHY ~60 °C; thresholds 92/120 °C).
- **Flight recorder (2026-07-20):** `tower-flightrec.service` streams live state (load, PSI,
  D-state tasks, top-CPU, temp) every 3s to [[book5]] `/var/log/tower-flightrec.log`
  (ring-buffered ~1 week) — the pre-freeze autopsy data the panic-only setup never captured
  (the silent hangs leave pstore empty). → [[watchdogs]].
- **`hung_task_panic=1`** (`/etc/sysctl.d/99-tower-hungtask.conf`) — a stuck D-state task now
  panics + dumps, complementing the softlockup/hardlockup knobs (which never fire on these hangs).
- ⚠️ **iTCO hardware watchdog is BIOS-locked (dead end):** `iTCO_wdt` can't reset the
  `NO_REBOOT` flag on this Lenovo P510 (no BMC), so tower can't self-reboot in hardware.
  Recovery is [[book5]]'s **Tapo P105 plug-cycle** (`192.168.69.178`, via `tower-watchdog.timer`).
- **2026-07-19 hang:** froze 15:26 after 16 d uptime on the pinned kernel; pstore empty again,
  journal stopped mid-stream, found ~3.5 h later via blank Frigate. The pin **reduced** frequency
  (1–3 d → 16 d) but did not eliminate it — root cause remains invisible / hardware-level.

⚠️ **Do NOT try netconsole on tower** — netpoll on the bridge silently fails on this
hardware/kernel combo (kernel says "network logging started" but no packets hit the wire,
verified with tcpdump). The rsyslog-to-book5 path is the working channel.

## Quick commands

```bash
zpool status media-pool      # ZFS pool health
zfs list                     # disk usage
showmount -a                 # NFS clients
lspci -nnk | grep -A3 NVIDIA # GPU vfio binding
pvecm status                 # cluster status
bridge link show | grep tap  # verify VM tap masters (after any reboot)
```

## Sources

- `~/.claude/docs/homelab/tower.md` (deep doc — hardware, NICs, TSO fix, NFS, kernel
  forensics)
- `~/projects/homeLab/CLAUDE.md` "Operational Current State" lines 45–119 (authoritative:
  2.5 G tap-master merge, kernel pin, fix-docker-forward, VM 111 rename, crash
  instrumentation)
