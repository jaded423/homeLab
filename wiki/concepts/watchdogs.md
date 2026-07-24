---
type: concept
title: Watchdogs & Crash Instrumentation
tags: [watchdog, self-healing, crash, monitoring, rsyslog, panic, autoheal, netconsole, pstore]
related: [book5, tower, vm101-ubuntu, vm111-homeassistant, dns-adblocking, troubleshooting]
---

Every self-healing, crash-forensics, and monitoring mechanism across the homelab, grouped by host. Exact paths/filenames/log commands are the operational value — preserved verbatim. When a host is down, the `homelab-host-recovery` skill is the runbook that walks these checks in order.

## [[book5]] — watchdog services

> These scripts contain hardcoded IPs — update them if the subnet changes.

| Mechanism | Path | What it does |
|-----------|------|--------------|
| Network health monitor | `/usr/local/bin/network-health-monitor.sh` | **v2.1** (2026-05-20) — graduated escalation + rate-limiting |
| CPU watchdog | `/usr/local/bin/cpu-watchdog.sh` | Suspends first running VM if CPU >99% for 3 min |
| VM101 route fix | `/etc/systemd/system/fix-vm101-route.service` | Overrides Twingate route to VM 101 (via tower on vmbr1) |
| Tower syslog receiver | `/etc/rsyslog.d/10-receive-from-tower.conf` | rsyslog UDP 514 receiver → `/var/log/tower-remote.log` |
| **Tower watchdog** (2026-07-20) | `/opt/tower-watchdog/tower-watchdog.sh` (+ `.timer`) | Probes tower LAN+Tailscale; power-cycles its Tapo P105 after ~15 min down (local python-kasa, no IFTTT) — tower's PRIMARY recovery |
| Tower flight-recorder sink | `/var/log/tower-flightrec.log` (+ `logrotate.d/tower-flightrec`) | Receives tower's 3s state stream, ring-buffered ~1 week |

**network-health-monitor.sh v2.1**: Graduated escalation with rate-limiting. Socket issues restart the Twingate client only (never NetworkManager). NM restart happens only on true isolation (both internet AND peers down, 6+ consecutive failures). Also probes DNS resolution (`check_dns`) — if DNS fails while inet+peers are OK, logs `action=dns_broken` (no auto-remediation).
- JSON state file: `/var/lib/network-health-monitor/state.json`
- Logs: `journalctl -t net-health`
- Pre-2026-05-20 backup: `/usr/local/bin/network-health-monitor.sh.bak-2026-05-20`

**cpu-watchdog.sh**: Suspends the first running VM if CPU stays >99% for 3 minutes.

**fix-vm101-route.service**: systemd unit that overrides the Twingate route to VM 101, sending it via tower on vmbr1.

**rsyslog receiver (tower's remote logs)**: book5 receives tower's full syslog over UDP 514 → `/var/log/tower-remote.log`. Config `/etc/rsyslog.d/10-receive-from-tower.conf` (set up 2026-05-06). Tail this after a tower hang to see the last messages before the crash — it is the working forensics channel since tower's netconsole doesn't work (see below).

**sdwan0 DNS pin** (Twingate connector self-heal): NM dispatcher hook `/etc/NetworkManager/dispatcher.d/90-twingate-dns-pin` re-pins the sdwan0 DNS to pihole and restarts the connector whenever a Twingate update resurrects it with dead resolvers. Logs `journalctl -t twingate-dns-pin`. This is a watchdog but the full detail lives in [[dns-adblocking]].

**Tower watchdog — book5 → Tapo P105 auto-heal (2026-07-20)**: `tower-watchdog.timer` runs `/opt/tower-watchdog/tower-watchdog.sh` every 3 min. Probes tower on LAN (`192.168.68.249:22`) **AND** Tailscale (`100.88.38.86:22`) — "down" only if BOTH fail (a single-path blip won't trigger a cut). After 5 consecutive fails (~15 min) it power-cycles tower's **Tapo P105 at `192.168.69.178`** via `python-kasa` (venv `/opt/tower-watchdog/venv`, creds `/etc/tower-watchdog.env` 600) — local LAN, no IFTTT/cloud. Sequence `kasa off → 15s → on` (absolute setpoints, always ends ON). Max 2 cycles / 30-min cooldown, then ntfy alert (topic `homelab-tower-watchdog-8x4k2`) for a human. State in `/opt/tower-watchdog/state/`. **This is tower's PRIMARY recovery** because its iTCO hardware watchdog is BIOS-locked (see [[tower]] below). User is the backstop (Tapo app). Plug IP is DHCP (`.69`) — pin via a router reservation. Needs tower BIOS "power-on-after-AC" (already set).

## [[tower]] — crash instrumentation & services

Added 2026-05-06 because tower was hanging silently every 1–3 days after the 2026-03-24 kernel upgrade to 6.17.13-2-pve. The goal: convert silent hangs into loud panics + auto-recovery, and capture forensics off-box.

**Kernel pin** — pinned to `6.17.4-2-pve` via `proxmox-boot-tool kernel pin 6.17.4-2-pve`. Hypothesis: a 6.17.13 regression (likely VFIO/IOMMU on the M4000 passthrough). If tower stays up >5 days the regression is confirmed; unpin only after 6.17.14+ ships and is verified.

| Mechanism | Path | What it does |
|-----------|------|--------------|
| Panic-on-hang sysctls | `/etc/sysctl.d/99-tower-debug.conf` | `softlockup_panic=1`, `hardlockup_panic=1`, `panic=30`, `panic_print=13` |
| Syslog forward to book5 | `/etc/rsyslog.d/30-forward-to-book5.conf` | Forwards all syslog (incl. kernel via `/dev/kmsg`) → book5:514/UDP |
| Persistent panic store | `pstore` at `/sys/fs/pstore` (in `/etc/fstab`) | After a panic+reboot, panic info lands as `dmesg-*` files |
| Docker FORWARD fix | `/etc/systemd/system/fix-docker-forward.service` | iptables FORWARD between book5 (.250) and VM 101 (.101) |
| Temperature sensors | `lm-sensors` | Cores ~45°C idle, NIC PHY ~60°C; thresholds 92/120°C |

**99-tower-debug.conf**: `softlockup_panic=1` + `hardlockup_panic=1` turn a lockup into a kernel panic; `panic=30` auto-reboots 30s after a panic; `panic_print=13` dumps extra state. Converts silent hangs into loud panics with auto-recovery.

**Reading a panic**: after a panic+reboot, check `/sys/fs/pstore` for `dmesg-*` files (the kernel's last words), and tail `/var/log/tower-remote.log` on [[book5]] for the syslog leading up to the crash. **But the silent hangs leave pstore EMPTY every time** (2026-07-19: froze 15:26 after 16 d uptime on the pinned kernel, journal stopped mid-stream, nothing in pstore) — the freeze is below what the panic knobs detect. Hence the two additions below.

**Flight recorder (2026-07-20)** — `tower-flightrec.service` samples state every 3s (load, PSI `/proc/pressure/*`, D-state/stuck tasks, top-CPU, temp) and streams it over a persistent SSH pipe to [[book5]] `/var/log/tower-flightrec.log` (ring-buffered ~1 week). Captures the *pre-freeze* state the panic-only setup never did — the last-seconds autopsy. `ssh book5 'tail -50 /var/log/tower-flightrec.log'`.

**hung_task_panic (2026-07-20)** — `/etc/sysctl.d/99-tower-hungtask.conf` sets `kernel.hung_task_panic=1`: a stuck (D-state >120 s) task now panics → pstore dump + reboot (`panic=30`). Complements `softlockup_panic`/`hardlockup_panic`, which have never fired on the silent hangs; may catch the hang if it's a driver/IO stall.

⚠️ **iTCO hardware watchdog = DEAD END (2026-07-20)** — the chipset watchdog (`iTCO_wdt`) is **BIOS-locked**: `modprobe iTCO_wdt` → `unable to reset NO_REBOOT flag, device disabled by hardware/BIOS`, no device registers. Board is a **Lenovo ThinkStation P510** (`30B5`), **no BMC/IPMI** — Lenovo locks the TCO watchdog with no user toggle. So tower CANNOT self-reboot in hardware; recovery falls to book5's Tapo plug-cycle (above). Don't re-chase this.

**fix-docker-forward.service**: Allows iptables FORWARD between book5 (192.168.68.250) and VM 101 (192.168.68.101). Required because Docker sets the FORWARD policy to DROP, which otherwise blocks Twingate-routed cross-host traffic. (Contains iptables rules — update if Docker or the subnet changes.)

**NICs / netconsole**: vmbr0 = Intel I218-LM (e1000e, 1G); vmbr1 = Realtek RTL8125 (r8169, 2.5G, primary). **netconsole on the bridge does NOT work — don't try.** The rsyslog forward to book5 is the working channel.

## [[vm101-ubuntu]] — autoheal (Docker self-healing)

`willfarrell/autoheal` container in the frigate compose stack (`/home/jaded/docker/frigate/docker-compose.yml`) restarts any container labeled `autoheal=true` when Docker marks it unhealthy (poll 15s, 120s start-period grace). Frigate is labeled.

**Notify chain** — on restart it POSTs `WEBHOOK_URL` → [[vm111-homeassistant]] webhook `autoheal_frigate_restart` → automation `autoheal_frigate_notify` → HA persistent notification, so you see *when* it fires.

**Failure mode it catches**: Frigate's nginx (5000) can serve the page shell while the backend (5001) is wedged → "unhealthy" but UI blank. If autoheal fires often, root-cause the `plate_recognizer` → `/api/events/.../clip.mp4` export stall.

## Cross-cutting

- **sdwan0 DNS pin / `journalctl -t twingate-dns-pin`** → the connector-DNS self-heal detail lives in [[dns-adblocking]].
- **Recovery runbook** — when a host is actually down, the `homelab-host-recovery` skill walks reachability → web UI → service health → these watchdog logs → kernel/panic forensics → guarded restart. It knows tower's kernel pin, book5's net-health watchdog, the tower rsyslog forward, and the pstore dumps. See also [[troubleshooting]].

## Sources

- `~/projects/homeLab/CLAUDE.md` — "Operational Current State" (Book5 Watchdog Services, Tower Services, Tower Crash Instrumentation, VM 101 self-healing)
