# HomeLab Project Changelog

## 2026-09-18 — `.lab` names move from Twingate aliases to Pi-hole Local DNS Records

**What changed:**
- **pihole (.248)**: 20 Local DNS Records loaded (`pihole-FTL --config dns.hosts`) from the git-tracked `docs/lab-dns-records.list`, which gained the service aliases `frig` · `plex` · `qbit` · `portainer` · `odoo` · `ollama` · `jit` (Gitea) → VM101, `prox` → book5. Phase 1.0 TODO closed.
- **Pocket**: home Wi-Fi profile pinned to pihole only (`ipv4.ignore-auto-dns yes`) — the Deco hands out `.1` as a second DNS and systemd-resolved had drifted to it, which NXDOMAINs every `.lab` name.
- Wiki: [[dns-adblocking]] § `.lab` names (mechanism + the Deco-secondary gotcha).

**Why:** `frig.lab:5000` failed on the Pocket with ERR_NAME_NOT_RESOLVED. The aliases had only ever lived in the Mac's Twingate client; Tailscale was never involved. Decision: Twingate stays off on the Pocket — Tailscale + pihole plug the hole until something proves unreachable.


## 2026-09-17 — `gmail-at`: real scheduled mail from VM101 (the Point4 reminder that never fired)

**What changed:**
- **ubuntu (VM101)**: new `~/.local/bin/gmail-at "YYYY-MM-DD HH:MM" TO "SUBJECT" < body.txt` — writes a **persistent** systemd user timer + service pair (`~/.config/systemd/user/mail-<stamp>-<slug>.{timer,service}`) and a runner + body under `~/.local/share/mail-at/`. `Persistent=true` (sends on next boot if the box was down), linger already ON, units self-remove after a good send, a failed send leaves them visible. `--list` / `--cancel NAME`.
- **First real job proven end to end:** the Point4 reminder armed for 09:45 CDT, fired 09:45:03, `sent … -> joshua@elevatedtrading.com` in the journal, units gone afterwards, message present in the Elevated mailbox from j@jadedviber.com (SPF pass, DKIM pass).
- **Gotcha found:** Gmail filed that first jadedviber.com → Elevated message under **Spam** despite SPF+DKIM passing (day-old domain, first mail to that mailbox). Rescued by hand; a "never send to spam" filter for j@ in the Elevated account was blocked by auto mode — Joshua to add it in the UI. Expect the same once with jaded423 / brown.
- Wiki: [[vm101-ubuntu]] § *Scheduled mail* — the `systemd-run` one-liner is replaced by the `gmail-at` runbook.

**Why:** the 2026-09-16 "send me a reminder at 9" never fired — it ended as a Gmail draft in the Elevated account with "click Schedule send", which Joshua rightly called useless. The evening's Workspace + own-consent work on ubuntu existed precisely so timed mail has an unattended home; this closes the loop. Rule captured in global memory `feedback_schedule_email_means_arm_it`.

**Files modified:**
- `ubuntu:~/.local/bin/gmail-at` — new
- `wiki/components/vm101-ubuntu.md` — Scheduled-mail section, timer pattern → gmail-at

## 2026-09-16 — VM101 becomes the "home email" sender: own OAuth consent via tunnel, `gmail-send`, linger on

**What changed:**
- **ubuntu (VM101)**: `~/projects/gsuite` cloned (jaded423/gsuite) into `~/.venvs/gsuite`; `~/.config/gsuite/` holds the Internal client file + settings and a token the box obtained **itself**: `ssh -t -L 8765:localhost:8765 ubuntu 'GSUITE_AUTH_PORT=8765 ~/.venvs/gsuite/bin/gsuite auth'` with the consent page opened on the Pocket. Identity = **j@jadedviber.com**; token never expires (Internal app).
- **`~/.local/bin/gmail-send TO "SUBJECT" < body`** — plain-text send as j@. Verified with a test to jaded423.
- **`loginctl enable-linger jaded`** — user timers now fire with nobody logged in (no sudo needed). Proven with `systemd-run --user --on-active=2min …` → mail arrived on schedule.
- Wiki: [[vm101-ubuntu]] § *Scheduled mail* (recipe, helper, timer pattern, why-not-consumer-Gmail).

**Why:** timed/automated mail from Joshua's own identity should run from the always-on box, not a laptop. The first attempt (copy the Elevated OAuth token to ubuntu) was refused by Claude Code's auto mode as credential leakage — correctly; own-consent-per-host is the pattern.

**Files modified:** `wiki/components/vm101-ubuntu.md`, `wiki/log.md`. Remote: `ubuntu:~/.local/bin/gmail-send`, `~/.venvs/gsuite`, `~/.config/gsuite/`, linger flag.

---

## 2026-09-15 — Tower: `media-pool/backups/pocket` dataset + GPD Pocket 4 factory image

**What changed:**
- New ZFS dataset `media-pool/backups/pocket` (compression=off; contents are zstd already). First payload: the Pocket's factory Windows side — GPT table, layout, EFI/MSR raw, Windows + Recovery via partclone.ntfs, SHA256SUMS; 71 GB in `2026-09-15/`; snapshot `media-pool/backups/pocket@2026-09-15-factory-windows`.
- `j@pocket` ed25519 key added to tower root's `authorized_keys` so the Pocket can stream backups directly (no shell export; key file only).
- Tailnet: the Pocket's two nodes renamed — Linux `pocket`, Windows `pocket-win`.

**Why:** return-window insurance for the Pocket without buying an external SSD; Tower had 1.29 TB free. Streamed over the 2.5 GbE wire at 261 MB/s through ssh. Script + restore recipe live in `~/projects/pocket/linux/`.

**Files modified:** none on disk here — ZFS + `/root/.ssh/authorized_keys` on tower.

---

## 2026-09-13 — book5 becomes a USB host for piGate Pis (pigw0)

**What changed:**
- book5 now adopts a piGate Pi 5 plugged into the dock's USB-C port as a network device: udev names the fleet gadget MAC `pigw0` and starts `pigw-usb.service` (192.168.7.1/24, `ip_forward=1`, iptables MASQUERADE `192.168.7.0/24 → vmbr1`, dnsmasq DHCP+DNS bound to 192.168.7.1 only). Unplug ⇒ unit stops, rules removed.
- `/etc/NetworkManager/conf.d/90-pigw-unmanaged.conf` — book5 runs NetworkManager (laptop); it grabbed `pigw0` and flushed the static address once.
- Full detail on the [[book5]] page § "piGate USB host".

**Why:**
- The Mac stopped enumerating pi-gw2's USB gadget; book5 enumerated it in 72 s and proved the Pi was fine. It stays as the reference USB host (and the model for a future Linux desk-Pi dock). Story → piGate changelog 2026-09-13 + brain `pi5-usb-gadget-mac-cold-plug-needs-bridge100`.

**Files modified (on book5):**
- `/etc/udev/rules.d/86-pigw-usb.rules`, `/usr/local/sbin/pigw-usb.sh`, `/etc/pigw-dnsmasq.conf`, `/etc/systemd/system/pigw-usb.service`, `/etc/NetworkManager/conf.d/90-pigw-unmanaged.conf`

**Technical notes:**
- udev `ENV{SYSTEMD_WANTS}` on the net device did not start the unit; `RUN+="/bin/systemctl --no-block start pigw-usb.service"` does.
- `net.ipv4.ip_forward=1` stays on host-wide after the first plug (nothing else on book5 relied on it being 0).

## 2026-09-11 — Terminal lab: TERM / terminfo / ncurses study page beside the network lab

**What changed:**
- New `wiki/concepts/terminal-lab.md` — the stack (emulator ← escape sequences ← terminfo keyed by TERM ← ncurses ← program), instruments, man-page reading order, and 10 tier-0 exercises in the network-lab shape. Pointer from `network-lab.md` ("sibling lab"), `wiki/index.md` row.

**Why:**
- `clear` from Ghostty on pi-gw1 failed with `'xterm-ghostty': unknown terminal type` (trixie's `ncurses-term` predates Ghostty's entry; fixed by `infocmp -x | tic -x`, baked into the piGate card). Joshua asked for the rabbit hole to be kept with his networking studies; the lab pages in this wiki are that study home.

: tiered, repeatable experiments around the Flint 3 rebuild

**What changed:**
- New `wiki/concepts/network-lab.md`: the rebuild (Flint 3 replaces the Archer as gateway, Archer + Decos become APs, VLANs) treated as a career-practice lab. Three tiers fix the blast radius — tier 0 = the existing tower `vmbr9` sandbox, tier 1 = a Flint 3 **island** (WAN into a house port, LAN on `10.68.0.0/16` so it can never collide with the live `192.168.68.0/22`, WAN zone drops RFC1918), tier 2 = production with the old gateway kept intact as rollback. Instruments named (pi-gw2 + Uptime Kuma, netwatch, OpenWrt CLI), notebook format, 12 exercises (island bring-up, DHCP + rogue DHCP, duplicate gateway, broadcast storm, the three layers on wire, 802.1Q trunk, Deco-as-AP + the pairing trap, DNS redirect, gateway-Pi placement in VLANs, timed restore drill, failure drills, the cutover itself), and a "never in the real world" list that grows with the log.
- `wiki/index.md` row, `wiki/log.md` line, `TODO.md`: Flint 3 cutover item gains the lab as its precondition.
- Office switch identified remotely from book5 (no LLDP/STP, no IP, Realtek RRCP broadcasts from a TP-Link MAC, 2500 Mb/s links) → **unmanaged TP-Link 2.5G**; row in `network-topology.md`, method in `network-lab.md` § Instruments.

**Why:**
- Joshua wants networking as a career and wants to add/remove APs, switches, and VLANs in a way that is repeatable, sometimes destructive, and never at the family's expense. The Flint 3 is already partially configured on `.68.*` — the island scheme is the guard against plugging that into the live house.
- Home decision: lab lives here (the LAN's one home), piGate points at it and supplies the probe.

---

## 2026-09-09 — pi1: TFT screen leaving (back to the Pi 400)

**What changed:**
- `wiki/components/pi1.md` § TFT Screen: dated note — the Hosyond 3.5" SPI TFT's job on pi1 is done; it is the Pi 400's screen (cyberdeck hat) and goes back to mom's Pi 400 on the next visit. Tried on pi-gw1 (Pi 5, official case + lid fan): no fitment. Overlay config kept as the reference.

**Why:**
- Joshua's call after the piGate screen test; pi1's runtime is unchanged, only the accessory's future.

---

## 2026-09-09 — Personal tailnet: ACL tags + auto-approvers; pi-gw1 subnet router on the home LAN

**What changed:**
- `jaded423@` tailnet policy: added `tagOwners` `tag:gateway` (admins) and `autoApprovers.routes` for
  10/8, 172.16/12, 192.168/16 → `tag:gateway`. Allow-all grant + SSH check rule unchanged.
- `pi-gw1` (piGate Tailscale gateway kit #1, Pi 5) joined the tailnet tagged and advertises
  `192.168.68.0/22`; route auto-approved. Verified from a phone on 5G reaching 192.168.68.1.
- Wired into the BE9700 (the GL.iNet swap is still pending — cable not run yet).

**Why:** piGate's client-site appliance needed a real LAN to prove plug-and-play; home was the test bench.
The ACL change is permanent (every future gateway on this tailnet rides it); the Pi itself is temporary.

**Where the current state lives:** [[access-model]] (new section) + `wiki/log.md`. Build story →
`~/projects/piGate/docs/changelog.md` (2026-09-08/09 entry).

## 2026-08-21 — pc (`etintake`) retired from production

**What changed:**
- The Elevated photos→web pipeline and all the Odoo report crons moved off this box to **m3lv**
  (an M3 MacBook Air that stopped travelling to become the always-on prod runner).
- Its pipeline crontab was removed — backed up in place at `~/crontab.bak-cutover-2026-08-21`.
  **Only the pc-heartbeat still runs**, kept deliberately: the box stays powered, so silencing
  its heartbeat would make the n8n "PC Health Monitor" alert on a machine that is deliberately alive.
- `wiki/components/pc.md` retitled and re-scoped; the Roles table no longer claims WSL is prod.

**Why:**
- Joshua is retiring the PC to a new project. Detail on the pipeline side lives in
  `elevatedWeb/docs/changelog.md` 2026-08-21 and `~/.claude/plans/i-would-like-to-cosmic-dongarra.md`.

**⚠️ Do NOT power this box down yet — the local consequence that does not travel with the
pipeline story:** its ONLY physical Ethernet port is [[pi1]]'s ICS gateway (`192.168.137.1`).
Powering it off takes pi1 offline. Move pi1 to a LAN switch port first — that is the gate on
decommissioning. The Twingate connector (Docker inside WSL) also still needs a new home.

**Files modified:**
- `wiki/components/pc.md` — retired-from-prod header, ICS warning, Roles table
- `wiki/log.md` — entry

---

## 2026-07-31 - PC 11h blackout root-caused: Windows ephemeral port exhaustion (not a crash)

### What changed
Diagnosed the 2026-07-29 23:08 → 2026-07-30 10:54 outage that stopped the Live Ref pipeline for 11 hours, and recorded the signature + recovery on [[pc]].

**The machine never went down.** Lights on, console fine, event log writing throughout (SCM 07:36, Volsnap 09:40, Kernel-General 09:51). What died was the ability to open *any* new socket: Windows exhausted its ephemeral TCP ports, so DNS failed (`No such host is known`, 0x80072AF9 against time.google.com / time.windows.com / time1.aliyun.com), both `pc-windows` and `pc-wsl` dropped off the tailnet at 23:09, and there was no path in. Smoking gun = `Tcpip` event **4231** at 00:18:09.

WSL cron kept firing blind for 11 hours — every `run_full_sync.sh` tick got through STEP 1 (the Drive crawler reads `/mnt/h` locally) then died at STEP 2 on `Temporary failure in name resolution`.

Joshua's manual reboot at 10:54 cleared it (boot releases winnat's reservations); it logged `Kernel-Power 41` with no `1074`, i.e. power-cycled while hung, which is expected.

### Why it wasn't caught
The 2-minute n8n heartbeat (`webhook/pc-heartbeat`) stopped at 23:09 and nothing downstream alerted. The outage was found by eye the next morning.

### Suspected cause + open question
winnat/Hyper-V reserving 100-port blocks inside the 49152–65535 dynamic range — signature is adjacent runs (49678–49977, 64064–64663). Whether those **accumulate over uptime** is inferred from the block pattern, **not measured**: no pre-reboot count was ever taken. Baseline recorded at **20 blocks, T+1.5h uptime** (boot 2026-07-30 10:54) so a recheck can settle it. Standing decision is **reboot-on-Tailscale-drop**, not a preventive fix — the cure (`netsh int ipv4 set dynamicport tcp start=10000 num=16384`) is documented on [[pc]] for if it recurs.

### Files modified
- `wiki/components/pc.md` — new Troubleshooting entry (signature, confirm, recover, cure, detection gap)
- `TODO.md` — recheck item with baseline + `verify:` one-liner

### Technical notes
- Both tailnet nodes dropping on the same second is the tell for a host-level network death rather than a WSL or service failure.
- `pgrep -f <pattern>` run over SSH matches its own `bash -c` wrapper — it reported a phantom "run in progress" during this work. Use `ps -eo pid,etime,cmd | grep -v grep`.

---

## 2026-07-20 - Tower silent-hang recovery stack: iTCO dead-end, flight recorder, hung_task_panic, book5→Tapo watchdog

### What changed
Deployed a 3-part recovery/forensics stack for tower's silent hangs (root cause still invisible after ~6 months — a full freeze that leaves pstore empty and no kernel log):

1. **Flight recorder** — `tower-flightrec.service` on tower samples state every 3s (load, PSI `/proc/pressure/*`, D-state/stuck tasks, top-CPU, temp) and **streams it off-box to book5** over a persistent SSH pipe → `/var/log/tower-flightrec.log` (logrotate 20M×5 ≈ ~1 week of 3s samples). A frozen box can't flush its own disk, so on-box logging always had the same blind spot; this is the pre-freeze autopsy data we never had. Autopsy: `ssh book5 'tail -50 /var/log/tower-flightrec.log'`.
2. **`hung_task_panic=1`** on tower (`/etc/sysctl.d/99-tower-hungtask.conf`) — converts a stuck-task (D-state >120s) stall into a real panic → pstore dump + reboot (`panic=30` already set). May finally catch the hang if it's a driver/IO stall (likely, given VFIO).
3. **book5 tower-watchdog** — `tower-watchdog.timer` (every 3 min) runs `/opt/tower-watchdog/tower-watchdog.sh`: probes tower on LAN (`.68.249:22`) AND Tailscale (`100.88.38.86:22`); after 5 consecutive fails (~15 min, **both** paths down) power-cycles tower's Tapo P105 **locally via python-kasa** (LAN, no IFTTT/cloud), ntfy-alerts, max 2 cycles then hands off to a human (30-min cooldown). First-line auto-heal; user is the backstop (Tapo app).

Support: new tower→book5 SSH key (root ed25519) for the stream; python-kasa 0.10.2 in a venv (`book5:/opt/tower-watchdog/venv`); Tapo creds root-only (`book5:/etc/tower-watchdog.env`, 600); ntfy topic `homelab-tower-watchdog-8x4k2` (alerting verified end-to-end).

### Why
2026-07-19 tower hung again — froze 15:26 after **16 days uptime on the pinned 6.17.4 kernel**, discovered ~3.5 h later only because Frigate went blank. book5's corosync saw the token-timeout at 15:28:12; tower's own journal stopped dead mid-stream at 15:26:36; **pstore empty again, no MCE/GPU-XID/OOM/panic**. The softlockup/hardlockup panic knobs have never fired — the hang is below what the kernel lockup detectors see. Tower had **no recovery path** (softdog can't fire on a frozen kernel; the n8n/IFTTT plug-cycle everyone "remembered" only ever watched the PC).

### The iTCO dead-end (don't re-chase)
The textbook fix — the Intel chipset hardware watchdog (`iTCO_wdt`) — is **BIOS-locked** on this box. Test-loading it returned `unable to reset NO_REBOOT flag, device disabled by hardware/BIOS`; no watchdog device registers. Board = **Lenovo ThinkStation P510** (machine type `30B5`), **no BMC/IPMI** — Lenovo locks the TCO watchdog with no user toggle. So hardware self-reboot is off the table for tower; the book5→Tapo plug-cycle is the actual recovery mechanism.

### Files modified / created
- `tower:/usr/local/bin/tower-flightrec.sh` + `tower:/etc/systemd/system/tower-flightrec.service` (new)
- `tower:/etc/sysctl.d/99-tower-hungtask.conf` (new — `hung_task_panic=1`)
- `book5:/opt/tower-watchdog/{tower-watchdog.sh,venv/,state/}` + `book5:/etc/systemd/system/tower-watchdog.{service,timer}` (new)
- `book5:/var/log/tower-flightrec.log` + `book5:/etc/logrotate.d/tower-flightrec` (new ring-buffer)
- `book5:/etc/tower-watchdog.env` (new, 600 — Tapo creds, NOT committed)
- wiki: `concepts/watchdogs.md`, `components/tower.md`, `components/book5.md`

### Technical notes / decisions
- **Tower's Tapo plug = "Prox-Tower Tapo Plug" P105 at `192.168.69.178`** (MAC `E0-D3-62-D0-49-2D`), on "Spaceballs" wifi. It's in the DHCP pool (`.69`) so the IP can drift → needs a router reservation (TODO, low-prio). BIOS "power-on-after-AC" is **already set** (plug on_since 7/19 18:52 → tower booted 18:53, i.e. it was recovered via the plug once).
- **`kasa off/on` are absolute setpoints, not toggles** → the cycle always ends ON regardless of start state (a key advantage of local Tapo over IFTTT's blind one-way triggers).
- **Local-Tapo chosen over reviving n8n→IFTTT:** the IFTTT tower applets don't exist / are offline, and IFTTT returns HTTP 200 even for disconnected applets (silent-fail trap the wiki already warns about). An n8n "Tower Health Monitor" clone was built but **abandoned unactivated** — the n8n CLI can't import into a running instance (SQLite lock), and n8n's publish≠active clobber-on-restart is the fragility being escaped.
- **Discovery gotcha:** the plug is on an isolation-enabled wifi SSID — `kasa discover` (UDP broadcast) misses it; direct unicast `kasa --host` works.
- **PC watchdog reality (aside):** 3-tier (Tier-1 LaunchAgent on **Brad's Mac**, Tier-2 n8n on omarchy), both actuate via IFTTT → so the PC's auto-reboot is **currently DEAD** while those IFTTT applets are offline (ntfy alerts may still work). Not fixed this session.
- The pinned 6.17.4 kernel **reduced** hang frequency (1–3 days → 16 days) but did NOT eliminate it; root cause remains invisible/hardware-level. See memory `tower_hang_kernel_pin_not_root_cause`.
- **DHCP server = the router at `192.168.68.1`** (TP-Link), not pihole (pihole DHCP is off). IoT reservations are a router-app job.
- **Not yet done:** a live power-cycle test (proves the full loop but hard-resets tower) — left for user go-ahead.

---

## 2026-07-16 - HA (VM111) DHCP drift → pinned static 192.168.68.111 in-guest

### What changed
- **VM111 (Home Assistant) had silently moved off `192.168.68.111` to `192.168.71.49`.** HA OS was running on `ipv4.method: auto` (pure DHCP) — `.68.111` was never actually pinned, it just held by lease luck. After ~12.7d uptime a renewal dropped it into the Deco's DHCP pool. Presented as a dead VM from the Mac (no ping, no web UI, `ssh ha` → "No route to host") while `qm status 111` said `running`.
- **Fix — pinned static in-guest** via the Supervisor-supported CLI (iface `enp6s18`, profile `Supervisor enp6s18`):
  ```bash
  ha network update enp6s18 --ipv4-method static \
    --ipv4-address 192.168.68.111/22 --ipv4-gateway 192.168.68.1 \
    --ipv4-nameserver 192.168.68.248 --ipv4-nameserver 192.168.68.1
  ```
- **Verified:** `ha network info` → `method: static`, `192.168.68.111/22`; on-disk NM profile `ipv4.method: manual` (survives reboot, not just runtime); ping + `:8123` → 200 from tower AND Mac; `ssh ha` → `a0d7b954-ssh`; `ha.lab:8123` loads in-browser (Twingate resource found its target again); old `.71.49` released.

### Why
- `.68.111` is what the Twingate `.lab` resource, `ssh ha`, shortcuts, and scripts all point at — the address is load-bearing, so it must be pinned, not leased.

### Technical notes / gotchas
- **Corrected a wrong fact in the wiki:** `wiki/concepts/network-topology.md` claimed the DHCP pool was `.50`–`71.250` and that infra `.248`–`.250` sat *inside* the pool held by **Address Reservation**. Both wrong. Truth: **pool = `192.168.69.0`–`192.168.71.254`; `.68.x` is static space the pool cannot reach; statics are set PER-MACHINE (client-side), not via router reservation** — so statics can't collide with DHCP and there is no Deco-side reservation to check. Page rewritten.
- **The guest agent is the diagnostic key.** It rides virtio-serial, not the network, so it answers even when the guest is unreachable by IP. `qm agent 111 network-get-interfaces` reported the real address instantly — the difference between "HA is down" and "HA moved".
- **Distinct from the tower tap-stranding bug** (`ip link set tapNi0 master vmbr1`). Checked first and ruled out: `tap111i0` was correctly `master vmbr1` and matched `qm config`. Same symptom, different cause — tap-stranding = wrong bridge; this = right bridge, wrong address.
- **Use `ha network update`, not bare `nmcli`** — the Supervisor owns the `Supervisor enp6s18` profile and will fight/overwrite a raw nmcli edit.
- **Latent risk elsewhere:** any other `.68.x` host still on `ipv4.method: auto` is one lease renewal from the same outage. Not audited this session.

### Files modified
- `VM111` — NM profile `Supervisor enp6s18` → static `192.168.68.111/22`
- `wiki/concepts/network-topology.md` — corrected DHCP pool range + static-space model
- `wiki/components/vm111-homeassistant.md` — static pin + DHCP-drift gotcha + agent-based diagnosis

---

## 2026-07-03 - btop GPU panel enabled on VM101 (M4000 readout)

### What changed
- **GPU-enabled btop on VM101 (ubuntu)**: source-built btop **1.4.7** with `make GPU_SUPPORT=true CXX=g++-14`, installed to **`/usr/local/bin/btop`**. **Removed the old snap btop** (`sudo snap remove btop`) — `/snap/bin` preceded `/usr/local/bin` in the *login-shell* PATH, so the snap (GPU_SUPPORT=false) was shadowing the new binary and the GPU box didn't appear; removing it makes `/usr/local/bin/btop` the sole btop. btop's GPU box now renders the **Quadro M4000** live — util / vram / temp / clocks (verified via tmux `capture-pane`: `Quadro M4000`, ~1% util, 54°C, 400 MiB vram, 772/3004 MHz). Installed **`g++-14`** (14.2.0, noble-updates/universe) as a build dep.
- Surveyed btop build flag + GPU visibility on all 4 hosts (ubuntu, omarchy, tower, book5) — only VM101 needed the fix.

### Why
- Installed btop reported `GPU_SUPPORT=false` → no GPU panel, even though `nvidia-smi` sees the M4000 (driver 535.309.01) and ollama holds VRAM. Goal: a GPU panel wherever a real GPU is visible.

### Technical notes / gotchas
- **The official btop static release ships `GPU_SUPPORT=false`.** Only asset now is `btop-x86_64-unknown-linux-musl.tar.gz`, and musl-static can't `dlopen` glibc's `libnvidia-ml.so` → upstream disables GPU in it. Grabbing the release binary does NOT fix this; a **source build** (dynamic, GPU_SUPPORT=true default) that dlopens `libnvidia-ml.so.1` at runtime is required.
- **btop 1.4.7 needs g++ ≥ 14** (uses C++23 `std::ranges::to`). VM101's stock g++-13.3 fails with `'to' is not a member of 'std::ranges'`. Fix: `apt install g++-14` + `make CXX=g++-14`.
- **Per-host GPU reality** (why only VM101 got a panel):
  - **omarchy (VM100)** — has `GPU_SUPPORT=true` (pacman build) + book5's Lunar Lake **Intel Arc iGPU via passthrough**, BUT **no GPU panel renders**: the card uses the newer **`xe`** kernel driver, and btop 1.4.7's Intel readout only supports **`i915`** (no `gt_*`/engine busy sysfs on `xe`). Forcing `gpu0` into `shown_boxes` still shows nothing — btop drops it. Nothing to fix until btop gains `xe` support. (Earlier assumption that omarchy "already shows the box" was wrong — never verified.)
  - **tower** — M4000 is **vfio-bound** (passed through to VM101); host has no other GPU → NVML/panel can't see it. btop still 1.3.2. Expected empty; left as-is (user chose ubuntu-only).
  - **book5** — its iGPU is fully **passed through to omarchy**, so host `/sys/class/drm` has **no card** at all → no panel possible. btop still 1.3.2. Left as-is.

### Files modified
- `VM101:/usr/local/bin/btop` — new GPU-enabled 1.4.7 binary (source-built)
- `VM101` — `g++-14` package installed (build dep)

---

## 2026-07-02 - VM101 sermon transcription pipeline + IPv6 disabled

### What changed
- **IPv6 disabled on VM101** (`/etc/sysctl.d/99-disable-ipv6.conf`): `disable_ipv6=1` + `accept_ra=0` on `enp6s18` + default; loopback `::1` kept. Removes the router-RA ULA (`fd24:…`) so outbound uses IPv4.
- **Whisper transcription stack on VM101** (`~/docker/whisper`): `local/faster-whisper` image (python:3.11-slim + faster-whisper 1.1.1 + requests + nvidia-cublas/cudnn-cu12), on-demand `docker compose run` (profile `manual`). Model **distil-large-v3, CPU int8, 24 threads, beam 1 ≈ 4.1× realtime**. `yt-dlp` standalone at `~/.local/bin/yt-dlp`.
- **p10k prompt** (`~/.p10k.zsh`): dropped `time` (current clock), added custom `cmd_start` segment (command start time; pairs with `command_execution_time`).

### Why
- IPv6-through-Mullvad tarpitted the Debian mirror at ~52 KB/s (build/download crawl); IPv4-through-Mullvad = 5.4 MB/s. Disabling v6 makes it deterministic and matches the router (v6 off).
- Sermon → transcript engine feeding the Mac `trans -sermon` Obsidian study-aid tool (see scripts changelog).

### Technical notes
- **GPU whisper walled by Maxwell**: M4000 (compute 5.2, driver 535) — ct2 4.8.0 + cuDNN 9 reject fp16 (no fast FP16) + int8 (no DP4A); fp32 crashes at encode (no sm_52 kernels). CPU-only. distil-large-v3 ≈ large-v3 quality at ~4× speed. Same Maxwell EOL as NVENC (2026-06-05).
- ct2 `cpu_threads=0` caps at ~4 threads (set explicitly); even at 24, autoregressive decode caps effective use ~5 cores (algorithmic).
- `99-disable-ipv6.conf` hardcodes iface `enp6s18` — update if NIC changes.

### Files modified
- VM101 `/etc/sysctl.d/99-disable-ipv6.conf` (new)
- VM101 `~/docker/whisper/{Dockerfile,docker-compose.yml,transcribe.py}` + `local/faster-whisper` image
- VM101 `~/.local/bin/yt-dlp` (new), `~/.p10k.zsh` (cmd_start segment)

---

---

**Older entries:** see [docs/changelog-archive-2026.md](changelog-archive-2026.md) (entries before 2026-07-02).
