# VM/Service Rebalance Plan — book5 ↔ tower (2026-06-27)

> Captured from the post-freeze design session on 2026-06-27. book5 froze (silent
> D-state I/O hang at 29-day uptime), which kicked off a "should omarchy/services
> move?" analysis. This doc is the parked decision set — review when ready to act.
> **Nothing here is applied yet** except the two emergency fixes noted below.

## Already applied this session (not parked)

- **`/etc/sysctl.d/99-book5-debug.conf`** on book5: `hung_task_panic=1`, `panic=30`,
  `hung_task_timeout_secs=120`, `softlockup_panic=1`. This is book5's only viable
  remote-recovery mechanism (see "book5 has no out-of-band recovery" below) — a
  soft I/O hang now auto-reboots in 30s instead of hanging forever.
- **VM100 (omarchy) memory 11264 → 10240** (config only; balloon:0 so the live VM
  holds 11.3 G until its next reboot). Gives the host ~1 G more headroom.

## Ground-truth findings (measured, not assumed)

**Hosts:**
| Host | RAM | GPU | Recoverable remotely? |
|---|---|---|---|
| book5 (laptop) | 15.5 G | Intel Arc 130V/140V iGPU (newer, good QSV/AV1) | **NO** — Core Ultra 7 256V (Lunar Lake), consumer, no vPro/AMT. Battery blocks the Tapo-plug trick. Self-reboot (panic) only. |
| tower | 78 G (60 used, ~17 free) | Quadro M4000 8 G (Maxwell, NVENC-walled) | **YES** — Tapo smart plug + ABM |

**VM101 (ubuntu) reality:**
- Allocated **36 G, actually uses ~5 G** (rest is cache). The 36 G was Ollama headroom — fantasy. Right-size to ~12 G.
- Disk: **scsi0 = local-zfs-tower:vm-101-disk-1, 300 G** on **rpool-tower (370 G pool, ~118 G free)**. This is the 300 G ceiling.
- **media-pool (3.62 T, 1.77 T free)** is already **NFS-exported** from tower and mounted in VM101 at `/mnt/media-pool` (and `/mnt/ollama`). Storage is NOT pool-locked — any host/VM can mount the same export.
- M4000 barely used: **303 MiB / 8192**. Consumers: Frigate + 2 transcode ffmpegs. Not gaming-bound.
- **15 containers** (more than the homelab docs list): steam-headless, autoheal, frigate,
  lpr-bridge, local-alpr, plate_recognizer (unhealthy), mosquitto, plex, **odoo, odoo-db,
  gitea** (undocumented), open-webui, portainer, qbittorrent, clamav (951 MB — biggest RAM hog).

## Revised priorities (from user, this session)

1. **Kill unrecoverable downtime** — the actual headache. Tower solved (Tapo + ABM). book5 is the weak link.
2. **Learning / homelab experimentation** — a lot of this is "see what I can do with what I have."
3. Gaming = **dead** (weekend hobby, machines not strong enough). LLMs = **vanity** (tower too weak). Both retire-able.

## The governing principle

Rank hosts by recoverability and place services accordingly:

| Tier | Host | Put here |
|---|---|---|
| **Production** | tower (recoverable) | Anything whose downtime hurts: Frigate/cameras, Plex, business (odoo/gitea), core services |
| **Expendable / lab** | book5 (no remote recovery) | Only things that can die without pain: omarchy desktop, GPU experiments, sandboxes |

**This inverts the "move Frigate to book5/Arc to free M4000" idea** — see below.

## Why NOT move Frigate to book5 (rejected option)

- Frigate is the **most critical** service (cameras, porch watchdog, HA automations).
  Putting it on the **least-recoverable host** maximizes the exact risk we're killing.
- M4000 is at **4% load** — freeing it solves a non-problem.
- Arc passes to one VM only → Frigate would run *inside* omarchy → a desktop update can
  take down cameras. Bad blast radius.
- **Keep Frigate/Plex on tower.** Weaker GPU is fine for this load.

## Recommended plan (move containers, not VMs — user's instinct, correct)

### Phase 1 — free, safe, reversible wins (do anytime)
- [ ] **Trim VM101 36 G → 12 G** (`qm set 101 -memory 12288`; needs VM101 reboot to free). Reclaims 24 G on tower.
- [ ] **Retire vanity containers** (stop + disable): `steam-headless` (gaming dead),
      `ollama` + `open-webui` (LLM vanity). Shrinks VM101 blast radius + RAM.
- [ ] Investigate `plate_recognizer` **unhealthy** (separate gremlin).

### Phase 2 — the gradual VM102 migration (user's chosen path)
- [ ] Create **VM102 on tower** = clean target + learning sandbox. Tower is recoverable, so experiments are safe.
- [ ] Move services **one at a time** 101 → 102 (containers, with their NFS mounts). Validate each before the next.
- [ ] Candidate split when done:
  - **102 (or stays 101) — media/camera:** frigate, plex, qbittorrent, mosquitto, ALPR stack (needs M4000 + NFS)
  - **infra:** odoo, odoo-db, gitea (no GPU) — could be its own VM for isolation
- [ ] Goal: smaller, single-purpose VMs = smaller blast radius per reboot.

### Phase 3 — M4000 experimentation (the "learning" goal)
- M4000 is a fine toy. To free it for VM102 GPU play: either **timeshare** (detach from
  101, attach to 102, reattach) or **drop Frigate to CPU detection** (Xeon 32 threads
  handles a few cams easily) to free M4000 fully.
- Do **GPU experiments on book5/Arc** (expendable) — Arc is the better GPU and a crash there costs nothing. Keep production GPU work (Frigate/Plex) on tower/M4000.

## Storage — the qbit "download → near-full SSD" issue (RESOLVED 2026-06-27)

**Real layout (corrected):**
- Tower SSD = Samsung 850 PRO **512 G** (sda) → rpool-tower system pool. Holds Proxmox + VM disks.
- Tower HDD = Seagate **4 TB SMR** (sdb, ST4000DM004) → media-pool, ~1.6 T free. NFS-exported.
- VM101 OS disk = 300 G LV on the SSD. qbit `/downloads` → `/home/jaded/downloads` (SSD).

**The pipeline already exists and is correct:** qbit downloads incomplete → SSD; on
completion the **clamav `scan-and-move` script** scans the file and moves it to media-pool
(HDD). This is the right design (incomplete on fast SSD, completed bulk on big HDD — also
the correct choice for the SMR drive, which hates the small random writes of in-progress torrents).

**The only real limit = peak in-flight size.** The incomplete file sits on the SSD until
100%, then scan-and-move evicts it. So free SSD space = max single-file download you can run.
User hit this downloading an 80 GB file with only ~90 G free.

**Fix applied 2026-06-27 — reclaimed ~34 G of dead experiment cruft from VM101 SSD:**
deleted `sd.cpp` (12 G), `iopaint-env` (5.7 G), `whisper-env` (2.3 G), `.cache/pip` (4.2 G),
`.cache/huggingface` (4 G); `docker builder prune -af` (9.85 G). **Root fs 190 G→156 G used,
90 G→124 G free (68%→56%).** An 80 GB file now fits with ~44 G margin.

**Further headroom if needed (no resize):**
- Retire steam-headless → frees `/home/jaded/docker/steam-headless/games` (20 G) + its image
  (user checking whether to keep for small OLD games omarchy can't run).
- Retiring ollama/open-webui frees their image layers from the 47.9 G image store.

**Do NOT grow the VM disk:** it can only grow into the SSD's free space (pushing rpool-tower
toward the 80% ZFS perf cliff), it's a one-way door (zvol/LV can't shrink), and it'd put bulk
on the precious SSD. Reclaiming cruft + the existing scan-and-move pipeline is the right lever.

**Note:** media-pool is a **single 4 TB drive, no redundancy** — fine for replaceable
downloads/media, but back up anything irreplaceable. A 2nd 4 TB → mirror is the next reliability step.

## book5 hardening checklist (it's a server now, not a laptop)

- [x] `hung_task_panic=1` (done) — soft-hang auto-reboot.
- [ ] **Hardware watchdog (`iTCO_wdt`)** — layer-2 net for a freeze so hard the kernel
      can't run the panic handler. Proxmox watchdog subsystem (HA fencing) — **discuss
      before arming** (HA interaction).
- [ ] **BIOS: power-on-when-AC-restored + battery charge-limit ~80%** (next time physical).
      24/7 plugged at 100% swells the battery → fire risk + degrades the free-UPS asset.
- [ ] **WoL** for remote power-*on* after clean shutdown (completes the remote story; doesn't help freezes).

## Open questions to decide later

1. **What is omarchy FOR now that gaming's dead?** If the desktop isn't used (office not
   set up), omarchy could shrink hard (less book5 freeze risk) or become a pure experiment VM.
2. Future **tower GPU upgrade** would unlock real Steam + LLMs on the recoverable host and
   could retire book5 from gaming entirely. Parked.
3. Split VM101 into media-VM + infra-VM for blast-radius isolation, or keep one box? (Phase 2 decision.)

## Bottom line

The freeze is ~80% solved by `hung_task_panic` (book5's stand-in for a Tapo plug). The
real architecture work is **retiring vanity + right-sizing VM101 + gradual VM102 split**,
keeping critical services on the recoverable host (tower) and using book5 as the
expendable lab. Not relocating critical services onto the fragile laptop.
