# HomeLab Project Changelog

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

## 2026-06-28 - Pixelbook Go: CachyOS rolling upgrade, DNS-hijack fix, static `.247`, Hyprland 0.55 + GRUB/console fonts

### Context
- Goal was "update Go to newest CachyOS." CachyOS is **Arch-based rolling** — no release versions; "newest" = `pacman -Syu`. Last full upgrade was 2026-03-10 (~3.5-month gap → keyring-first + multi-mirror hazards).
- Go = Pixelbook 2019, CachyOS via SeaBIOS Legacy (ctrl-L → 1 at firmware). Reached over Tailscale (`100.114.126.32`), so all fixes below were doable headless even while LAN DNS was broken.

### DNS hijack (root cause of the failed first `-Syu`)
- First `-Syu` died at `cachyos-v3.db failed to download`. Not the CDN — **Go's resolver was dead**. `getent` hung; `resolv.conf` = `127.0.0.53` (systemd-resolved stub) but resolved wasn't forwarding.
- **Root cause:** Go runs a Twingate connector (`sdwan0`). That link claimed `~.` (authoritative for ALL domains) + default route, pointing at Twingate's **dead `100.95.0.251-254` resolvers** — the *same disease book5 hit* 3× (changelog 2026-05-20/27). pihole `.248` answered fine on direct query; the hijack starved every system lookup.
- **Fix (book5's proven remedy):** `sudo nmcli con mod sdwan0 ipv4.dns 192.168.68.248 ipv4.ignore-auto-dns yes && sudo nmcli device reapply sdwan0` → resolved's sdwan0 link now forwards to pihole → resolution restored. (A failed `tailscale set --accept-dns=false` attempt en route — see book5 scare below.)
- **Persistence caveat:** a Twingate client update can revert the sdwan0 DNS (book5 needed a dispatcher hook). If Go's DNS breaks again, re-run the pin. Better long-term: Go is on Tailscale (5/27) and may not need the Twingate connector at all — killing it removes the whole failure mode (deferred).

### Static IP `.247` (client-side)
- New router (TP-Link **Archer**) DHCP pool = `192.168.69.0`–`192.168.71.254`; the entire `192.168.68.x` zone is **outside the pool** = free for static pins (where book5 `.250`, tower `.249`, pihole `.248` already sit). **No router reservation needed** — set it client-side.
- Go pinned via NetworkManager (Wi-Fi conn "Spaceballs"): `ipv4.method manual`, `192.168.68.247/22`, gw `192.168.68.1`, DNS `192.168.68.248`, `ignore-auto-dns yes`, plus `802-11-wireless.cloned-mac-address permanent` (MAC randomization would dodge any future reservation). Survives router swaps.
- **`.247` was the Mac's documented slot** — but the Mac actually roams on DHCP (was at `.71.82`), never statically held `.247`. Reassigned to Go; network table updated (Go=.247 static, Mac=roaming).

### Upgrade
- After DNS fix: `cachyos-rate-mirrors` → keyring-first (`pacman -Sy archlinux-keyring cachyos-keyring`) → `pacman -Syu` (721 pkgs, 2.4 GiB).
- **4× `404` from `cdn77.cachyos.org`** (gcc/glibc/lib32-gcc-libs/ttf-dejavu) — CDN file-sync lag, not fatal: pacman's **multi-mirror fallback** re-fetched them from krfoss/us mirrors and committed cleanly. (Misjudged this mid-run as an abort — it had already moved to post-install hooks. pacman is atomic: partial *download* failure that recovers via other mirrors still installs; only an unrecoverable retrieval aborts with zero changes.)
- Booted new **LTS `6.18.37-1-cachyos-lts`** (GRUB defaulted to LTS on its own). Main kernel also installed (`linux-cachyos 7.1.2`) but LTS preferred for the quirky Pixelbook + headless reliability. Old `6.18.16` stays in GRUB as fallback.
- **7 `.pacnew`** — all resolved by keeping the live versions (mirrorlists = rate-mirrors-ranked > stock defaults; `mkinitcpio.conf` live has `plymouth`+`resume` hooks the default drops; locale/resolv.conf inert). Backed up to Mac `~/projects/homeLab/backups/go-pacnew-20260628.tar.gz`, then deleted from Go. Initramfs rebuilt clean from the *good* config before reboot.

### Hyprland 0.55 breaking changes
- Boot showed 2 red config errors: `dwindle:pseudotile does not exist` (l.195) + `Invalid dispatcher "togglesplit"` (l.262).
- Fixes: `pseudotile` was **removed in 0.55** (no-op; pseudotiling now per-window via the `pseudo` dispatcher, already bound) → commented out. `togglesplit` is **no longer a direct dispatcher since 0.54** → `bind = $mainMod, J, layoutmsg, togglesplit`. Backup `hyprland.conf.bak-20260628`. Reloaded remotely via `XDG_RUNTIME_DIR=/run/user/1000 HYPRLAND_INSTANCE_SIGNATURE=<sig> hyprctl reload` (signature pulled from `/run/user/1000/hypr/`); `configerrors` now empty.

### Readable boot text (GRUB too small to pick a kernel on the HiDPI panel)
- **GRUB menu:** `grub-mkfont -s 32 -o /boot/grub/fonts/dejavu32.pf2 /usr/share/fonts/TTF/DejaVuSansMono.ttf` + `GRUB_FONT=` in `/etc/default/grub` + `grub-mkconfig` (verified `loadfont` line in grub.cfg). GRUB loads its own font early — no waiting on a later boot stage. The pre-GRUB SeaBIOS/ctrl-L prompt is firmware, unchangeable.
- **Post-GRUB console:** `/etc/vconsole.conf` → `FONT=latarcyrheb-sun32` (16×32), applied early via the `sd-vconsole` initramfs hook (`mkinitcpio -P`). Both effective next boot.

### book5 scare (accidental, fully reverted)
- The `tailscale set --accept-dns=false` meant for Go was run while SSH'd into **book5** by mistake. Harmless: book5 is wired (no Wi-Fi/"Spaceballs"), and its `resolv.conf` is pihole-pinned via `sdwan0` regardless — DNS never broke. Restored `--accept-dns=true`; verified sdwan0 pihole pin intact, twingate-connector active, Tailscale online, VM running. One cosmetic drift: Wi-Fi radio left `enabled` (device `wlo1` disconnected, no route) — left as-is pending confirmation of its prior state.

### Files modified
- `CLAUDE.md` (homeLab) — network table: Go row → `.247` static + CachyOS; Mac row → roaming/DHCP.
- On Go: `/etc/NetworkManager` (Spaceballs static + sdwan0 DNS pin), `/etc/default/grub`, `/boot/grub/fonts/dejavu32.pf2`, `/etc/vconsole.conf`, `~/.config/hypr/hyprland.conf`.
- Mac: `~/projects/homeLab/backups/go-pacnew-20260628.tar.gz` (7-file `.pacnew` backup).

---

## 2026-06-21 - Network-wide ad-blocking restored: Deco DHCP DNS field went blank after the outage

### What happened
- **Symptom:** ads everywhere (phone mid-game, Mac), pihole screen black → first guess "pihole down." Pihole was fine — clients just weren't pointed at it.
- **Root cause:** the 2026-06-19 outage fried the Spectrum modem. New modem + Deco re-setup **wiped the Deco's DHCP-Server → Primary DNS field** (had been pihole `192.168.68.248`). Blank field → Deco handed clients its WAN-learned **ISP DNS `209.18.47.63/.61`** (CenturyLink/Lumen) → zero blocking on every DHCP client. Statically-DNS'd infra (book5, tower, VM101, cameras) kept blocking.
- **Proof:** pihole FTL DB (`/etc/pihole/pihole-FTL.db`) per-client last-seen showed ~20 clients flatline at **06-19 ~07:21:34** (single-second mass cutoff = power event), survivors = only the static-DNS boxes. Daily query volume had *climbed* across the 5/27 TG→TS cutover — exonerating the cutover.

### Ruled out
- TG→TS cutover (no cliff at 5/27), Deco cloud-config wipe (config intact), double-NAT (Deco WAN = public Spectrum IP `68.203.135.83` → modem confirmed **bridge mode**), the March Mac Wi-Fi `8.8.8.8` hardcode (separate jadedViber-launch workaround; cleared this session anyway).

### Fix (Deco app — must be on home Deco Wi-Fi to edit; on Tailscale, Deco thinks you're remote → settings go read-only)
1. **DHCP Server** → **Primary DNS = `192.168.68.248`**, Secondary **blank** (public secondary = bypass leak). ← the lever.
2. **Internet → IPv4 (WAN) DNS** → leave **Auto**. Deco *rejects* a LAN IP here ("This IP conflicts with the LAN IP subnet… set it at DHCP Server") — pihole belongs in DHCP only.
3. **IPv6 → Off** (confirmed) — else v6 lookups leak past pihole.

### Confirmed good state
- DHCP now hands `.248`; `dig doubleclick.net` → `0.0.0.0`, `github.com` resolves. Tailscale MagicDNS (`100.100.100.100`, resolver #1) is transparent — forwards public lookups to DHCP DNS = pihole.
- **pihole `.248` is static** (required — it sits inside the DHCP pool `.50`–`192.168.71.250`; non-static would risk it being handed out and breaking DNS).
- Clients pick up the fix on DHCP renew (~2hr lease) or Wi-Fi reconnect.

### Notes
- pihole = Raspberry Pi 2 Model B (2015) — slow. FTL DB analysis: stream to a fast box (`ssh pihole "sudo cat /etc/pihole/pihole-FTL.db" > /tmp/x.db`, then local sqlite3); **skip `-C`** on the Pi 2 (A7 CPU can't gzip at line rate — raw cat over 100Mb wins; the `-C` pull took 3:28 for 294MB).
- Stale SSH alias: memory claimed `s25-tunnel` exists; `~/.ssh/config` only has `s25` / `s25-home` / `s25-work`. Phone's home DHCP IP drifts (landed on `.59` after dropping TS) — `s25-home` `.200` is stale.
- Memory: brain `deco-dhcp-dns-pihole` (id 630424).

---

## 2026-06-19 - Power outage: mesh AP fried, CT102 retired, VM101 unhealthy

### What happened
- **Power surge / outage** took down the network. Post-event reachability scan (homelab-net-check) from Mac (roamed to 192.168.68.62/22):
- 🔴 **TP-Link secondary mesh AP (192.168.71.250) DESTROYED** — fried in the surge, no LED, confirmed dead in person. Was the last node still on the surge protector. Replacement node TBD. Cameras PetCam (.75) + Porch (.76) rerouted cleanly onto the primary AP — both reachable.
- 🟢 Core infra survived: book5, tower, omarchy (VM100), pihole all UP (LAN + Tailscale + tunnel). Tower rebooted in the event (uptime ~59 min at scan).
- 🟡→✅ **VM101 (ubuntu) was unreachable — ROOT-CAUSED + FIXED this session.** `qm status 101` = running, but no L2 from tower (`ip neigh` FAILED, .101:22 "No route to host"). Misdiagnosed first as Mullvad lockdown (status stuck "Connecting", even single-hop Stockholm cycling relays). Real cause: **the cable reroute stranded tower's VM taps** — `tap101i0` parked on the dead stock-1G `vmbr0`, `tap111i0` on **no bridge at all** (HA/VM111 was also dark). Mullvad "Connecting" was a *symptom* of zero upstream, not the disease. Fix: `ip link set tap101i0 master vmbr1` + `tap111i0 master vmbr1` → both onto the 2.5G `enp2s0`. Both VMs immediately reachable. Then re-armed Mullvad (single-hop Stockholm, lockdown ON, LAN allow) — SSH persists through the killswitch.

### Bonus: VM101 silently upgraded 1G → 2.5G
- VM101 had been on the stock **1.0GbE** (`vmbr0`/`nic0`) the entire time — Joshua meant to merge it onto 2.5G in a prior reroute and never did. The outage forced it. Post-fix speedtests from VM101: **single-hop Stockholm (VPN) 1178↓/583↑ Mbps** (was ~950 capped on 1G), **direct/no-VPN from tower 2005↓/633↑**. ~25% gain on the everyday STO path. Mullvad exit is now hop-swappable (default STO; SE→DAL for US/gaming) — see CLAUDE.md.
- ⚠️ **Persistence caveat**: the tap→`vmbr1` move is runtime-only. net0 configs already = `vmbr1`, so a clean boot should reattach, but they stranded once — verify `bridge link show | grep tap` after the next tower reboot/power event. Tracked in TODO.

### CT102 retired (separate, deliberate)
- **CT 102 `trans` LXC (192.168.68.65) DESTROYED** — deleted to free book5 resources (not a casualty — intentional). `trans` transcript work now runs ad-hoc, no dedicated container. Doc rows for CT102 may have been missed in a prior `/log`; corrected this session.

### Elevated tailnet note
- "PC tail down but WSL up" explained: PC Windows host carries **two Tailscale identities** — `jaded423@ pc-windows` (100.99.217.17, offline 6d) and `joshua@ pc-windows` on tailnet `tail275437` (100.105.93.121, ONLINE). Working path (`ssh pc`) rides the online joshua@ node; `ssh wsl` (workhorse `etintake`, up 2d10h) UP. WSL runs its own tailscaled (joshua@, online) so it was unaffected by the jaded423@ node dropping. `go` offline (expected — side project). `shippingpc` offline 14d (never fully set up — TODO).

### Mullvad hop-swap aliases (VM101 `~/.zshrc`, user jaded)
- Added + tested `mv-sto` (single-hop Stockholm, everyday default) and `mv-dal` (multihop `se sto`→`us dal` US exit, gaming-only). VM101 is the only Mullvad box; tower/host never on VPN. `mv-dal` exists because Rockstar/Steam reject a Sweden exit IP ("unusual activity detected") — Dallas was the only way to log into Steam. Both aliases force lockdown ON + LAN allow; there is no VPN-off mode. `mv` = quick status. Tested live: mv-dal → 23.234.106.240 (Dallas), mv-sto → 89.37.63.246 (Stockholm), left on STO.

### qemu-guest-agent staged on VM101
- VM101 was the only VM **without** the guest agent (VM100 omarchy + VM111 HA already had it) — ironic, since its Mullvad killswitch makes it the hardest box to reach and the agent rides virtio-serial (not the LAN), so it'd have let the host introspect VM101 while the network was dark. Installed `qemu-guest-agent` in the guest + `qm set 101 --agent 1` on tower. Service is `static` (udev-activated by the virtio-serial port). **Channel only attaches on a full VM stop→start (not a reboot)** — activation deferred to the next VM101 power-cycle; verify then with `qm agent 101 ping`. Tracked in TODO alongside the tap-persistence check.

### Files modified
- `CLAUDE.md` (homeLab + global `~/.claude/CLAUDE.md`) — mesh AP + CT102 rows DESTROYED; VM101 Mullvad section rewritten (hop-swappable, STO default); added 2.5G NIC-merge + tap-strand gotcha.
- `TODO.md` — VM101 recovery DONE; added tap-persistence + guest-agent-activation + replace-mesh-AP + finish-shippingpc items.
- `VM101:~/.zshrc` — `mv-sto`/`mv-dal`/`mv` aliases.
- Memory: `vm-tap-stranded-wrong-bridge`, `pc-dual-tailscale-identity` (+ MEMORY.md index).

---

## 2026-06-19 - Removed Tailscale from VM101 (ubuntu) + deleted tailnet node

### What changed
- Purged Tailscale from VM101 (`ssh ubuntu`): `tailscale logout` (timed out, rc=124 — see below), `systemctl disable --now tailscaled`, `apt-get remove --purge tailscale` (1.98.3, 73 MB freed). Daemon + binary gone.
- Deleted the `vm101-ubuntu` node (`100.120.104.11`) from the tailnet via admin console GUI.

### Why
- VM101 always showed **offline** in the Tailscale admin console. Diagnosis: daemon was up (had IP, saw peers) but the health check reported "Unable to connect to the Tailscale coordination server." Mullvad **lockdown mode** (block traffic when VPN disconnected) blocks all non-VPN egress, including Tailscale's outbound to `controlplane.tailscale.net` — so the node could never sync.
- Access to VM101 was never via Tailscale anyway (Mullvad lockdown also drops inbound CGNAT 100.64/10 on tailscale0). It's reached via `ssh ubuntu` → ProxyJump tower (Twingate/Mullvad path), which is **unchanged**. The Tailscale node was dead weight + console noise.
- User wants to keep both the ProxyJump and Mullvad lockdown → removing Tailscale is the clean resolution.

### Technical notes
- `tailscale logout` timed out (rc=124) because lockdown blocked it reaching the control server to deregister — expected. So the node stayed registered until the manual GUI delete. **Uninstalling does NOT auto-remove a node from the tailnet**; it just shows offline/expired until deleted server-side.
- Mullvad state on VM101 at time of removal: multihop `se sto` entry → `us dal` exit (23.234.105.249), lockdown ON.

### Files modified
- `CLAUDE.md` — VM ProxyJump note: added Tailscale-removed-2026-06-19; Tailnet line: VM101 now an exception.

---

## 2026-06-18 - CLAUDE.md becomes the homelab single source of truth

### Outcome
- **`~/projects/homeLab/CLAUDE.md` is now the authoritative home for homelab current-state.** Added a new top section **"Operational Current State (AUTHORITATIVE — homelab source of truth, 2026-06-18)"** holding the full operational reference: 192.168.68.0/22 SSH/IP table, Tailscale/SSH inversion (2026-05-27), VM ProxyJump rules, web UIs, VM-101 services (incl. steam-headless), Mullvad multihop `se sto`→`us dal`, autoheal, roaming reverse tunnels, Pi1, tailnet, book5 watchdogs + DNS-pin hook, tower services + crash instrumentation (kernel pin 6.17.4-2-pve).
- The stale pre-Feb-2026 `192.168.2.x` "Network Cheat Sheet" lower in the file is now explicitly marked **historical** (the deferral note that pointed at `~/.claude/CLAUDE.md` is gone).

### Why
- Decided 2026-06-18: homelab current-state was drifting across 3 docs because `/log` wrote to cwd, not the owning dir. Fix = one current-state home (here) + locale-aware `/log` (Step 0). Global `~/.claude/CLAUDE.md` keeps only a quick-ref + pointer; `~/.claude/docs/homelab.md` + `docs/homelab/` stay as deep reference.

### Files modified
- `CLAUDE.md` — new authoritative "Operational Current State" section (209→277 lines); old 192.168.2.x tables demoted to historical.
- (Cross-repo: global `~/.claude/CLAUDE.md` slimmed + `commands/log.md` Step 0 routing — logged in `~/.claude/docs/changelog.md`.)

---

## 2026-06-15 - PC watchdog 3-tier finished (Tier-2 published) + Elevated Twingate HA connector pair

### Outcome
- **Weekend verdict — Brad Tier-1 watchdog ran clean.** `com.elevated.pc-watchdog` (LaunchAgent, StartInterval 60s) polled all weekend: `fail_count=0`, `reboot_count=0`, zero firings, **no false reboots**. Only log entries were Friday's manual test (self-reset at 2/5). The Tier-2 false-reboot failure mode did NOT recur on Tier-1.
- **Tier-2 rebuilt + PUBLISHED** on omarchy n8n (workflow `sq6c3CWdw5AihV4me8PDB`, "PC Health Monitor v3 (Tier-2 gated)") — finishing the 3-tier design.
- **Elevated Twingate connectors restored as an HA pair** — recreated the deleted WSL connector + added a new Brad connector, both in the `Elevated` remote network (`jaded423`).

### Tier-2 (omarchy n8n)
- Published via the **n8n public REST API** (minted an API key), NOT direct DB edits — that's the fix for the snapshot trap that double-rebooted the PC (n8n runs the `activeVersionId` version snapshot, not `workflow_entity.nodes`). API path sets `activeVersionId` correctly.
- Graph: `Schedule(5m) → executeCommand probe PC 100.105.93.121:22 + Brad 100.82.50.89:22 over tailnet → Code "Decide" (gated) → Switch → {IFTTT plug-cycle | ntfy alert}`. Container confirmed able to reach both tailnet IPs on :22.
- Gate: fires ONLY when **PC AND Brad both down ≥6 cycles (~30 min)**; Brad up ⇒ Decide returns 0 items ⇒ silent (won't fight Tier-1). Verified live: PC up → no-op, no downstream nodes ran.
- Rewired the two notify nodes from IFTTT → **ntfy** (private topic — see local TODO / n8n workflow for the value). IFTTT power-key validated live (non-destructive probe). n8n API key stored `omarchy:~/.n8n_api_key` (0600).

### Twingate connectors (Elevated network `jaded423`)
- **`twingate-wsl`** — recreated on WSL (native Docker 29.1.3), replaced the dead `twingate-daffodil-puma` (its admin-side connector had been deleted → invalid token). Deployed via `--env-file` (inline `--env` + long token strings fail to parse over `ssh wsl`).
- **`twingate-brad-mac`** — new connector on Brad. Brad had no brew/Docker/runtime, so installed a **fully-userspace colima (vz) + docker CLI** in `~/.local` (no sudo/brew/GUI; Apple Virtualization, no qemu). Container→`192.168.1.1` LAN reachability verified (connector can serve Elevated LAN resources). Both connectors reached `Online`.
- **Auto-update: Watchtower** (`nickfedor/watchtower`, daily 04:00 UTC) on each host, scoped to the connector + watchtower.
- Brad chosen over Pi1 for redundancy: Pi1's internet routes through `192.168.137.1` (the PC's ICS), so it dies exactly when the PC does. Brad is the only PC-independent always-on Elevated host. WSL's connector is on the PC, so it also dies with the PC — Brad is the real redundancy.

### Brad cold-reboot resilience (tested)
- **FileVault DISABLED on Brad** + **auto-login** = elevatedtrading (policy: FV only on Macs that leave the premises; Brad is stationary + controlled).
- **Cold reboot tested end-to-end:** reboot → auto-login → colima LaunchAgent → connector `Online` + Tier-1 watchdog polling, all unattended (~2 min).
- The reboot caught a latent bug the manual install hid: the `com.elevated.colima` LaunchAgent ran `zsh -lc "colima start"`, but `-lc` (login, non-interactive) does NOT source `~/.zshrc` where the PATH export lived → `limactl` not found → colima silently failed every boot. **Fixed:** plist now sets `PATH` (and `HOME`) via `EnvironmentVariables` instead of relying on shell rc.

### Why
- Tier-2 was the last unfinished piece of the 3-tier PC watchdog; the Elevated Twingate network had drifted to zero working connectors (WSL connector deleted in admin). Both are PC-availability infrastructure for the Elevated office.

### Gotchas banked
- `containrrr/watchtower` is abandoned — its client API 1.25 < Docker 29's min 1.40, crash-loops. Use the maintained `nickfedor/watchtower`.
- WSL `~/.docker/config.json` had `credsStore: desktop` → `docker --pull` invoked `docker-credential-desktop.exe` (not in WSL PATH) and failed. Removed the key.
- `docker run` over `ssh wsl` with long token `--env` values fails to parse — use `--env-file`.

### Files modified (on the boxes, not this repo)
- `omarchy:` n8n workflow `sq6c3CWdw5AihV4me8PDB` (republished via API); `~/.n8n_api_key` (new, 0600).
- `wsl:` `twingate-wsl` + `watchtower` containers; `~/.docker/config.json` (credsStore removed).
- `brad:` `~/.local/{bin,share,state}` (colima/lima/docker userspace install); `twingate-brad-mac` + `watchtower` containers; `~/Library/LaunchAgents/com.elevated.colima.plist` (PATH fix); FileVault off + auto-login.

### This repo
- `TODO.md` — marked PC-watchdog + Twingate-connectors items done; DHCP-reservations demoted to low-prio/blocked.

---

## 2026-06-05 - Containerized Steam (steam-headless) on VM 101 — second game-stream rig

### Outcome
- **Deployed `josh5/steam-headless` on VM 101 (ubuntu, tower)** as a second Moonlight/Sunshine game-streaming rig, complementing omarchy. Full XFCE desktop + Steam + Sunshine in one container, GPU = the passed-through **Quadro M4000 (8GB dedicated VRAM)**. Verified end-to-end: Steam login → Proton → **Torchlight II** runs, streamed to Mac via Moonlight, Steam Big Picture fullscreen works.
- **Why a second rig:** M4000's 8GB *dedicated* VRAM beats omarchy's shared-RAM Lunar Lake iGPU for VRAM-bound older AAA; 35GB RAM, 28 vCPU, 109GB free for games. Trade-off below.

### Deploy details (`/home/jaded/docker/steam-headless/`)
- `docker-compose.yml` + `.env` adapted from the project's NVIDIA template: nvidia runtime, `network_mode: host`, `/dev/uinput` + `/dev/fuse`, `FORCE_X11_DUMMY_CONFIG=true` (headless dummy display), `ENABLE_SUNSHINE=true`, web desktop on `:8083`, Sunshine on `:47990`. Games → `/mnt/games` (lands at `/mnt/games/GameLibrary`, on the 109GB `/`). Footprint ~8.6GB (image 3.8 + Steam home 4.2 + layer 0.6).
- **Flatpak-installer hang fix:** first boot wedged — `start-desktop.sh` runs `install_firefox.sh`/`install_protonup.sh` (both `flatpak --user`, which deadlocks headless) in a blocking xterm *before* `startxfce4`, so XFCE never starts → Sunshine's "wait for desktop" times out → crash loop. **Fix:** no-op override scripts bind-mounted over both (`overrides/install_*.sh:/usr/bin/install_*.sh:ro`). Durable across recreate. Firefox/ProtonUp non-essential for gaming.
- **CSRF pairing fix:** added `csrf_allowed_origins = https://192.168.68.101:47990` + `origin_web_ui_allowed = wan` to `sunshine.conf` (PIN POST was CSRF-blocked from the non-localhost origin).

### The encoder wall: NVENC blocked by Maxwell EOL
- Current Sunshine (`v2026.516`) needs **nvenc API 13 / driver ≥570**; the M4000 is Maxwell, **permanently capped at the 535 legacy branch** (570+ dropped Maxwell). So **hardware NVENC is impossible with current Sunshine.** VAAPI also fails (no Intel/AMD iGPU on tower). Fell back to **software x264.**
- **x264 verdict (sampled live during Torchlight II):** Sunshine encode ~**1.7 cores**, system 62% busy / 38% idle, M4000 16% util / 624MB, **Frigate cameras unaffected (coexist fine).** Software encode is genuinely viable for older/emulator titles. Set `sw_preset = ultrafast` (bitrate untouched) to cut per-frame CPU spikes.
- **NVENC path (deferred, optional):** to get hardware encode, swap in **Sunshine v2025.122** (Jan 2025, last pre-driver-570 build; ships an AppImage that sidesteps Debian-13 deps). Fragile — breaks on image updates, may force re-pair. Only do it if the audio pulse is confirmed encode-jitter (testing pending).

### Mullvad: single-hop SE → multihop SE-entry / DAL-exit
- VM 101 egresses through Mullvad (Lockdown Mode, was Stockholm exit). Steam flagged the Swedish IP as a suspicious login. **Reconfigured to multihop: entry Stockholm (`se sto`), exit Dallas (`us dal`)** via `mullvad relay set location us dal` + `set entry location se sto` + `set multihop on`. Now `us-dal-wg-* via se-sto-wg-*` — Steam sees a US/Dallas IP (matches account, fast local downloads) while the entry hop stays foreign-jurisdiction. **Affects all VM101 Mullvad-routed apps** (qBit etc. now exit Dallas; still private). Note: the Sweden *entry* hop caps throughput (~264 Mbps vs ~700-900 single-hop vs ~1.9 Gbps bare) — offer-standing to move entry to Canada for speed if wanted.

### Open / pending (user testing tonight)
- **Audio pulsing** (same symptom as omarchy RDR): suspected software-x264 per-frame CPU-spike jitter on the shared Sunshine audio path (VM101 is only ~38% loaded, so not raw load). `sw_preset=ultrafast` applied; if pulse persists it's likely network (omarchy's final verdict was network-jitter), in which case NVENC wouldn't help either.
- **TL2 quirks:** native 2012 Linux build is broken (`ld.so`/LD_PRELOAD) — **force Proton 9.0** (Experimental crashed on Play, 9.0 works). In-game Options menu crashes (Proton quirk, parked). General rule banked: old DX9 → Proton 9.0; new → Experimental/GE; ancient native Linux → force Proton.
- **Big Picture clean-close:** steam-headless's `apps.json` already includes the `steam://close/bigpicture` undo + `xfce4-close-all-windows` + `pkill sunshine` teardown (more thorough than omarchy's) — but only fires when launched via the **"Steam Big Picture" Moonlight app**, not "Desktop."
- Creds are weak LAN defaults (`steam-tower-2026`) — change after testing. Remote access (Twingate/TS) not set up yet.

### Files (on VM 101, not this repo)
- `/home/jaded/docker/steam-headless/{docker-compose.yml,.env,overrides/}` — new.
- `~/.config/sunshine/{sunshine.conf,apps.json}` inside the container (persistent home volume).
- Mullvad daemon settings (multihop) — VM 101 host.

---

## 2026-06-04 - RDR (2024) playable on omarchy via Moonlight/Sunshine (Proton fix chain)

### Outcome
- **Red Dead Redemption (2024 port, Steam appid `2668510`) now runs** on VM 100 (omarchy) streamed to the Mac via Sunshine→Moonlight (Steam Big Picture). Renders the full intro/cutscenes, no crash, no black screen. Audio pulsing fixed by enabling FSR (was iGPU+encoder load contention). Remaining nit: very slight audio crackle on some remote paths only — network jitter on the audio stream, not the box (LAN/good links are clean). Client-side Moonlight audio-buffer bump if ever needed.

### The three real problems (and what actually fixed each)
1. **Crash `ACCESS_VIOLATION (0xC0000005)`** at world-load. Crash dump: fault in `libvkd3d-shader` / `D3D12PixelShader`, `rip 0x600000000005` (garbage jump) — a vkd3d-proton shader-translation bug in **stock Proton Experimental**. *Not* VRAM (lowering render res 2880→1280 didn't move the crash point). **Fix: installed GE-Proton10-34** (`~/.steam/root/compatibilitytools.d/`) and forced it for RDR via `CompatToolMapping` in `config.vdf`.
2. **Black 3D scene** (UI + audio fine). Cause: a leftover launch option **`PROTON_USE_WINED3D=1`** forcing the OpenGL-based wined3d path on a D3D12 game → broken/black render. **Fix: cleared RDR's `LaunchOptions`** in `localconfig.vdf`.
3. **Black/tiny window on Xwayland.** RDR "fullscreen" at a non-desktop res becomes a small black window on the 2880×1800 virtual display (Xwayland can't modeset it). **Fix: set game resolution = desktop (2880×1800)** so fullscreen fills with no mode-switch. Also set `bFocusPaused=false`.

### Hardware reality
- omarchy GPU = **Intel Arc 130V/140V (Lunar Lake iGPU)**, shared system RAM; VM 100 has **~11GB** of book5's **15GB** host (no room to grow — book5 is the OOM-prone laptop). Sunshine's encoder hits the *same* iGPU as the game. RDR 2024 is marginal here; expect to lean on FSR upscaling for playable fps + to keep the audio stream from underrunning.
- Mesa/vulkan-intel `26.0.6`, Proton Experimental `11.0-20260529` — both fresh, so this was a genuine vkd3d↔RDR incompat, not stale drivers. `gamescope 3.16.23` installed as a fallback render-surface lever (not currently in use; the wined3d-flag removal made it unnecessary).

### Files modified (on omarchy / VM 100, not this repo)
- `~/.steam/steam/config/config.vdf` — added `CompatToolMapping` 2668510→GE-Proton10-34. Backup `config.vdf.bak-pre-ge`.
- `~/.steam/steam/userdata/79228882/config/localconfig.vdf` — cleared RDR `LaunchOptions`. Backup `localconfig.vdf.bak-gamescope`.
- `.../Rockstar Games/Red Dead Redemption/graphicsOptions.xml` — res 2880×1800, FSR off (disabled to isolate the black screen), `bFocusPaused=false`. Backups `.bak-pre-vramfix`, `.bak-blackscreen`.

### Known-good rollback config (this entry)
- GE-Proton10-34, empty LaunchOptions, Fullscreen=true, 2880×1800, **FSR3UpscalingQuality=0**, bFocusPaused=false. Crash-free + renders. (Next step: re-enable FSR Performance for fps + to fix the audio pulse — load-induced, iGPU+encoder contention.)
- NOTE: `docs/gaming-vm-plan.md` is **stale** — it describes an abandoned Windows-VM-on-tower-with-M4000-passthrough plan. The actual rig is omarchy Steam/Proton + Sunshine.

---

## 2026-06-03 - HA porch-cam fix, HA 2026.5.4, Frigate self-healing (autoheal + notifier)

### What changed
- **Fixed porch cam watchdog automation.** Repair error `Porch cam offline → power cycle plug ... has an unknown action: tts.google_translate_say`. That TTS service was removed in HA 2026.x. Replaced with modern `tts.speak` (target `tts.google_translate_en_com`, `media_player_entity_id: media_player.family_room_speaker`) — announcement preserved. Cameras were never down; only the automation failed validation.
- **HA core updated 2026.5.3 → 2026.5.4.** Pre-update backup slug `58ba1362` on HA.
- **Frigate self-healing deployed on VM101.** Frigate had wedged: nginx (5000) served the page shell but the backend app (5001) hung — every `/auth`+`/api/*` call 504'd, health check went red (`Up 7 days (unhealthy)`), UI blank. Logs also showed a stuck 60s `clip.mp4` export from `plate_recognizer` (python-requests) piling on `/api/events`. Restarted container to clear the wedge (back to healthy, API 0.17.1), then added `willfarrell/autoheal` to the frigate compose stack + labeled frigate `autoheal=true`. Autoheal polls Docker health every 15s and restarts any unhealthy container, 120s start-period grace to avoid restart loops.
- **Wired autoheal → HA notification.** autoheal `WEBHOOK_URL` → HA webhook `autoheal_frigate_restart` (local_only) → new automation `autoheal_frigate_notify` → `persistent_notification.create`. A Frigate auto-restart now surfaces in the HA bell. Tested end-to-end (webhook 200, automation triggered).

### Why
- Self-healing requested after the manual restart. Autoheal acts on Frigate's existing healthcheck locally on VM101 (no HA dependency — HA itself was the fragile piece earlier this session). Notifier gives visibility into *how often* it fires, so a recurring wedge (suspect: the plate_recognizer events-export loop) surfaces instead of silently looping.

### Files modified (on the boxes, not this repo)
- `ha:/config/automations.yaml` — porch action fix + new `autoheal_frigate_notify` automation. Backup `automations.yaml.bak-2026-06-03`.
- `ubuntu(VM101):/home/jaded/docker/frigate/docker-compose.yml` — added `autoheal` service, `autoheal=true` label on frigate, `WEBHOOK_URL` env. Backup `docker-compose.yml.bak-2026-06-03`.

### Going forward
- If autoheal starts firing often, root-cause the `plate_recognizer` → `/api/events/.../clip.mp4` export stall rather than relying on restarts.

---

## 2026-05-27 - Tailscale-vs-Twingate consolidation: TS now primary, Twingate scoped to media

### Outcome
- **Tailscale is now the primary access layer** for all admin/SSH + homelab web UIs + RustDesk. **Twingate kept only** for what TS structurally can't reach: VM101/Mullvad-locked apps, Home Assistant web UI, AMT break-glass, and the remote (mom's) site.
- Twingate resources pruned **27 → 12**. SSH alias convention **inverted** (bare = Tailscale). Web UIs reachable by **MagicDNS name** (no aliases needed).

### Root cause that kicked this off: TG/TS CGNAT collision
- RustDesk direct-IP to PC failed while `tailscale ping` worked. Cause: Twingate installs a `100.96.0.0/12` route to its tunnel; Tailscale uses `100.64.0.0/10`. The `/12` is more specific → longest-prefix match steals any Tailscale peer numbered `100.96–100.111.x` (PC `100.99`, pi1 `100.98`) into Twingate's tunnel → TCP filtered. `tailscale ping` works because it uses userspace WireGuard, bypassing the OS routing table.
- **Fix deployed:** root LaunchDaemon `com.jaded.ts-pin-routes` + `/usr/local/sbin/ts-pin-routes.sh` on the Mac. Pins PC + pi1 with `/32` host routes via Tailscale's interface (a `/32` beats TG's `/12`). Re-asserts on `RunAtLoad` + network-change events. Verified: TG on → 100.96/12 back on utun5, but PC/pi1 stay on utun4, `nc 100.99.217.17 22` OPEN.

### Twingate resource cleanup (admin GraphQL API)
- Generated an API token (Settings → API, "Claude", Read/Write/Provision), stored in the Mac Keychain (`security find-generic-password -a twingate -s twingate-api -w`). No MCP — curl against `jaded423.twingate.com/api/graphql/`.
- **Deleted 15 redundant resources** (TS covers them, or junk): proxmox-web, Cockpit Book5, Cockpit Tower, prox-tower ssh, zMagic, Omarchy, n8n, mac-ssh, zWindows-SSH, RustDesk, zWindows (127.0.0.1), go-linux (172.17.0.1), homeLab Shared, Homelabel, Go-Elevated.
- **Kept 12:** VM101 apps (Plex, qBit, Frigate, Odoo, Portainer, Open Webui, Jit, Minecraft — Mullvad lockdown blocks direct tailnet), homeassistant (.111 web UI), AMT (.249 out-of-band break-glass — works when tower OS is down, so TS-via-tower can't replace it), mom-lan + Mom-pi (remote site).

### home-assistant VMID 112 → 111
- Renamed back to VM 111 now that the old book5 VM 111 is gone (VMID matches its IP `.111` per original plan). ZFS path: stopped VM, `zfs rename` the 3 zvols (`media-pool/vm-disks/vm-112-disk-{0,1,2}` → `vm-111-*`), `sed` the disk refs + `mv` the config, started as 111. Pre-rename safety backup at `local:/var/lib/vz/dump/vzdump-qemu-112-2026_05_27-11_37_00.vma.zst` (3.3G, delete once stable). IP stays `.111`, HA healthy (`:8123` up, agent OK).

### homeLab Shared retired
- The old Samba share on book5 was stale (no clients; omarchy's client mount was already commented; only a hand-added `[root]` share exposing `/root` rw remained — security smell). Removed the `[root]` share, **disabled + stopped `smbd`/`nmbd`** on book5 (backup `smb.conf.bak-2026-05-27`), deleted the TG resource, removed omarchy's dead CIFS fstab line.

### book5 Twingate connector recovered (recurring DNS bug)
- `prox-book5-systemd` showed DEAD in admin since 2026-05-23 while `systemctl` reported active. Cause: a TG client update reverted book5's `sdwan0` NM DNS back to the dead `100.95.0.x` resolvers (with `dns-priority=-1`, `dns-search=~.` = authoritative for all domains) → all book5 DNS failed → connector couldn't resolve the control plane. Re-applied the pihole override (`nmcli connection modify sdwan0 ipv4.dns 192.168.68.248 ipv4.ignore-auto-dns yes` + `device reapply`) + restarted connector → ALIVE in 10s. **2nd occurrence — every TG update may revert it** (auto-remediation TODO logged in `network-cleanup-todo.md`).

### Pixelbook Go onto Tailscale (CachyOS)
- Replaces the deleted `go-linux` TG resource. Tailscale installed via pacman, authed as `go` (`100.114.126.32`). Flagged a MagicDNS systemd-resolved/NM conflict on Go (cosmetic — IP alias works; TODO logged).

### SSH alias convention inverted (Mac `~/.ssh/config`)
- **bare alias = Tailscale** (primary, works anywhere on tailnet, via MagicDNS), `*-local` = home-LAN direct. Removed the Twingate SSH path entirely (TS reaches every homelab host). Backup `~/.ssh/config.bak-2026-05-27`.
- `omarchy` ProxyJump **dropped** (tested: direct TS works). `ubuntu` **keeps** ProxyJump tower (Mullvad blocks direct tailnet ingress — confirmed by test). pc/wsl/go reverse tunnels through book5 **dropped** (flaky + redundant). Added `pc-ts`/`wsl-ts`/`go-ts` (folded into bare). `trans`/`Homelabel` removed (CT `.61` scrubbed).

### Web UI access via MagicDNS (no aliases)
- MagicDNS works on the Mac (suffix `tail950cc2.ts.net`). Bookmarks: `https://prox-book5:8006` / `prox-tower:8006` (Proxmox), `:9090` (Cockpit), `http://pihole/admin/`, `http://omarchy:5678` (n8n), `https://omarchy:47990` (Sunshine, user `jaded423`).
- **n8n secure-cookie fix:** `http://omarchy:5678` was rejected by n8n's default `N8N_SECURE_COOKIE=true`. Added `N8N_SECURE_COOKIE=false` to `~/docker/tower-guardian/docker-compose.yml` on omarchy + recreated (safe — access is over encrypted TS/LAN). Backup `docker-compose.yml.bak-2026-05-27`.

### Files / artifacts
- `docs/network-cleanup-todo.md` - new follow-up list (book5 DNS auto-reapply, Go MagicDNS, delete HA backup, n8n URL polish, Tailscale Serve option)
- Mac: `~/.ssh/config` (inverted), `/usr/local/sbin/ts-pin-routes.sh` + `/Library/LaunchDaemons/com.jaded.ts-pin-routes.plist` (new)
- book5: `smbd` disabled, `sdwan0` DNS → pihole; omarchy: n8n env + fstab; tower: VM 111 rename + backup

### Addendum (same day): mom-pi onto Tailscale
- mom-pi (Pi 400 @ mom's, Debian 13 aarch64) joined tailnet `100.89.98.66`; `pi-mom` alias now = Tailscale. Disabled the failing `ssh-tunnel.service` (book5 reverse tunnel) — it was always redundant since mom-pi runs its own Twingate connector. Brought up `--accept-dns=false`, Tailscale SSH disabled (key-based like the fleet).

---

## 2026-05-20 → 2026-05-21 - Home Assistant deployed on tower (VM 112) with porch cam watchdog

### Outcome
- HA OS 17.3 running on tower as **VM 112** at **192.168.68.111** (DHCP reservation for MAC `bc:24:11:94:b8:9a`)
- Replaces the IFTTT-based porch cam watchdog (Hubspace plug control was the gap — IFTTT has no Hubspace service, only Tapo)
- Tower watchdog migration is deferred (HA on tower can't watch tower; see Follow-up)

### Why on tower instead of book5
- First attempt was on book5 as VM 111. Book5 hung mid-deploy from userspace OOM (VM 100 omarchy still at 10GB, HAOS first-boot I/O storm pushed it over). ICMP answered, sshd/pveproxy wedged, required physical power-cycle (no remote access).
- Moved to tower. Used VMID 112 because the partial book5 VM 111 record is cluster-wide locked until book5 is recovered and `qm destroy 111` runs.
- Saved memories: `book5-oom-during-vm-deploy.md`, `tower-hang-kernel-pin-not-root-cause.md`, `ha-book5-watchdog-plan.md`.

### Infrastructure changes on tower
- New ZFS dataset `media-pool/vm-disks` → registered as Proxmox storage `media-pool-vm` (zfspool, images+rootdir). Chose this over `local-zfs-tower` (82% full → would push to 91% with HA disk). media-pool already has precedent for non-media datasets (`media-pool/ollama`).
- VM 101 ubuntu-server **trimmed from 64GB → 36GB RAM** via virtio_balloon. Module wasn't loaded in the guest (Proxmox set ballooning target but guest ignored it); loaded with `modprobe virtio_balloon` + persisted via `/etc/modules-load.d/virtio_balloon.conf`. Actual working set in VM 101 was ~7.6GB so 36GB is still 4x headroom.
- VM 112 spec: 4GB RAM, 32GB disk on `media-pool-vm`, q35 machine type, OVMF UEFI **without** pre-enrolled MS keys (`pre-enrolled-keys=0`). Tried SeaBIOS first to skip OVMF debugging — HAOS image is UEFI-only, doesn't boot under SeaBIOS. SB-disabled OVMF works.

### Integrations deployed inside HA
- **HACS** (community store) via SSH addon (Advanced SSH & Web Terminal). Addon required `username: root` because we enabled SFTP — that's a hard requirement of the addon, not a choice.
- **Hubspace** (`jdeath/Hubspace-Homeassistant`, in HACS default repos now). Discovered 6 devices including the dual-outlet outdoor plug HPPA52CWBA023 ("Lights" device, Outside area). Outlet 2 = porch camera = `switch.lights_outlet_2` (friendly name "Porch Camera"). Note: entity_id is generated from device+outlet number, not the friendly name — renaming via UI doesn't change the entity_id, integration regenerates it on reload.
- **Frigate** (blakeblackshear, in HACS default repos). Created 4 devices (Frigate server + 3 cams: Tapo Porch, Tapo 360 Living Room, Plate Zone) but ZERO entities until MQTT was wired up.
- **MQTT**. The non-obvious gotcha: Frigate's HA integration is a discovery/topic listener — without MQTT pointing at Frigate's broker (mosquitto on VM 101 at 192.168.68.101:1883, anonymous), the Frigate devices stay empty. First attempt accidentally picked the "Mosquitto Mqtt Broker app" option which would install HAOS's own bundled broker (separate from VM 101's, would not see Frigate's topics). Removed that, re-added MQTT with "Manually enter broker details" → 192.168.68.101:1883, blank user/pass. Entity count jumped from ~20 (Hubspace + a few HA core) to 118 within seconds.

### Porch cam watchdog automation
- ID `porch_cam_watchdog`, friendly name "Porch cam offline → power cycle plug"
- Trigger: `camera.tapo_porch` state = `unavailable` for 2 minutes
- Action: `switch.lights_outlet_2` off → 10s delay → on → TTS to `media_player.family_room_speaker` (Google Nest Mini, auto-discovered by Google Cast integration)
- Mode: single
- Created via REST API POST to `/api/config/automation/config/porch_cam_watchdog`, then `services/automation/reload`. Verified plug toggles cleanly (off→on tested live during creation — actually power-cycled the cam, came back in ~30s).

### Access plumbing
- Long-lived access token created in HA → stored at `tower:/root/ha-emergency-kit/ha-token-claude.txt` (perms 600)
- HA emergency-kit backup file (the encryption key for HA backups) copied to `tower:/root/ha-emergency-kit/` and `ubuntu:~/ha-emergency-kit/` (perms 600 each). Mac copy deleted by user. 1Password also has it.
- Mac SSH config: added `Host ha` block with `ProxyJump tower` (Twingate intercepts 192.168.68.0/22 from Mac, same workaround as `ssh ubuntu`). `ssh ha` → root@HAOS SSH addon container.
- Twingate resource `homeassistant` (alias `ha.lab`) created pointing at 192.168.68.65, needs updating to 192.168.68.111 (IP moved when we set the DHCP reservation).

### Issues hit and resolved
- **DNS dead on book5** at start of the deploy: `/etc/resolv.conf` listed only Twingate's 100.95.0.x resolvers, which were unresponsive. Fixed in a parallel session by repointing sdwan0's NM connection at pihole (see 2026-05-20 sister entry). `network-health-monitor.sh` patched to also probe DNS — previously logged "green" through the outage because it only checked ICMP+socket+systemctl.
- **VM 112 boot looked black-screen at first**. Screen dumps showed `\0`-only pixels which I mistook for OVMF hanging. Actually HAOS was booting normally; first-boot Supervisor container pulls take 5-15min and the screen sits on "Waiting for the Home Assistant CLI to be ready" for most of it. Got fooled twice (book5 + tower) before checking the screen content properly.
- **VM 112 IP drifted from .65 → .67 → .111** as we added DHCP reservation. HAOS internal "reboot" only restarts containers, not the OS — had to `qm shutdown 112 && qm start 112` to force a fresh DHCP lease grab.

### Follow-up
- **HA-book5 watchdog still pending.** Need a second small HA (2GB/32GB, Tapo integration only) on book5 to watch tower. Plan saved at `~/.claude/projects/-Users-j-projects-homeLab/memory/ha-book5-watchdog-plan.md`. Blocked on book5 being healthy (currently hung from this incident) + VM 100 trim to 6GB.
- **Retire IFTTT applets** (`tower_plug_off`, `pc_plug_off`, etc.) once HA-book5 is up — Tapo integration in HA replaces them all natively.
- **Pi1 off-site watcher** (~50 lines of Python) as belt-and-suspenders for "both home nodes down" scenarios. Defer until HA-book5 done.
- **MQTT auth.** Currently anonymous on mosquitto. Fine on LAN but worth locking down with a user/pass. Need to update Frigate + HA MQTT integration in sync.
- **Hubspace entity_id stability.** Renames via UI don't stick — integration regenerates on reload. If we depend on these in automations, document the entity_ids that exist post-regeneration rather than relying on friendly-name-derived ids.

## 2026-05-20 - book5 DNS broken / sdwan0 swapped to pihole

### Incident
- `ping github.com` on book5 failed with "Temporary failure in name resolution"
- Direct queries to public resolvers (8.8.8.8) worked; only the configured resolvers failed
- `/etc/resolv.conf` listed `100.95.0.251-254` — Twingate's internal DNS, supplied via NM connection `sdwan0` (ipv4.method=manual, ipv4.dns-search=`~.` so it's catch-all)
- `twingate status` reported "online" and `/run/twingate/auth.sock` existed, but `dig @100.95.0.251 github.com` timed out — tunnel up, resolvers themselves not answering

### Investigation
- Confirmed 100.95.0.x are Twingate-owned (route via `sdwan0`, not Tailscale — Tailscale's `dns status` just reads `/etc/resolv.conf` and reports the same IPs as "system DNS")
- `systemctl restart twingate.service` did NOT bring the resolvers back; CLI `twingate stop && twingate start` blocked on an interactive "another VPN active" prompt (Tailscale also up — both use CGNAT, hence the false detection)
- Watchdog `network-health-monitor.sh` had logged every 10-minute check as fully healthy throughout the outage — it never probes DNS resolution, only ICMP to public IPs + systemctl + socket existence

### Fix
1. Started TW client back up via systemctl (left in `online` state)
2. Moved sdwan0 DNS off Twingate's broken resolvers and onto pihole:
   ```
   nmcli connection modify sdwan0 ipv4.dns 192.168.68.248
   nmcli connection modify sdwan0 ipv4.ignore-auto-dns yes
   nmcli device reapply sdwan0
   ```
   Persisted to `/etc/NetworkManager/system-connections/sdwan0.nmconnection`. resolv.conf now has only `nameserver 192.168.68.248`. pihole resolves both LAN and public — book5 does not need Twingate-internal name resolution.
3. DNS verified: `getent hosts github.com` → 140.82.114.4, `ping github.com` succeeds. Twingate still `online`, connector untouched.

### Watchdog Patch
- `/usr/local/bin/network-health-monitor.sh` patched (backup at `network-health-monitor.sh.bak-2026-05-20`)
- Added `check_dns()` — probes `getent ahostsv4` against cloudflare/google/github with 4s timeout
- Added new state branch "Case 4.5: DNS broken but everything else OK" — logs `action=dns_broken` and a hint to check resolv.conf/pihole/sdwan0. **Does not auto-remediate** — the 2026-05-20 incident showed TW client restart didn't fix it, and blind restart loops are worse than a clear log line
- "Case 5: Everything OK" now also requires `dns_ok=OK` so the watchdog doesn't report green during a future DNS outage
- log_check format unchanged (callers compatible); DNS state shows up via a separate `INFO dns_broken: ...` line

### Risk / Follow-up
- If Twingate client install/update overwrites the NM connection, sdwan0 DNS will revert to 100.95.0.x. Backup of original kept; re-apply nmcli commands if observed
- Root cause of TW resolver outage not determined (likely Twingate backend / sdwan0 tunnel state) — if it recurs, capture `twingate logs` + `ip -s link show sdwan0` before re-applying the workaround

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
## 2025-11-12 - Remote Desktop Access (wayvnc) Setup

### Overview
Successfully configured remote desktop access to the CachyOS server using wayvnc, enabling full GUI access via VNC over SSH tunnel. This allows viewing and controlling the Hyprland desktop environment from anywhere with SSH access.

### What Was Implemented

#### 1. wayvnc VNC Server Installation
- **Package:** wayvnc (Wayland-native VNC server)
- **Configuration:** Listens on `127.0.0.1:5900` (localhost only for security)
- **GPU Acceleration:** Enabled with `--gpu` flag for better performance
- **Auto-start:** Added to Hyprland config (`~/.config/hypr/hyprland.conf`)
- **Command:** `wayvnc 127.0.0.1 5900 --max-fps=30 --gpu`

#### 2. SSH Tunnel Configuration
- **Security Model:** VNC not exposed to network, only accessible via SSH tunnel
- **No firewall changes needed:** Port 5900 remains blocked externally
- **Connection method:** SSH port forwarding (`-L 5900:localhost:5900`)

**From Mac:**
```bash
# Create SSH tunnel (keep running)
ssh -L 5900:localhost:5900 jaded@192.168.1.228

# Connect VNC to localhost
open vnc://localhost:5900
# OR
open -a "VNC Viewer" localhost:5900
```

#### 3. VNC-Friendly Keybindings
Added Ctrl-based keybindings that work through VNC (SUPER key doesn't pass through VNC clients):

**Launching Applications:**
- `Ctrl + Enter` → Open terminal (kitty)
- `Ctrl + Space` → Open application launcher (wofi)

**Workspace Navigation:**
- `Ctrl + 1-9` → Switch to workspace 1-9
- `Ctrl + Shift + 1-9` → Move current window to workspace 1-9

**Legacy Bindings (still work):**
- `Ctrl + Alt + T` → Open terminal
- `Ctrl + Alt + Space` → Open app menu
- `Ctrl + Alt + W` → Close active window

**Original SUPER keybindings still work locally** (on physical machine):
- `SUPER + Return` → Terminal
- `SUPER + Space` → App launcher
- `SUPER + 1-9` → Switch workspaces
- `SUPER + Shift + 1-9` → Move window to workspace

#### 4. Waybar Status Bar Configuration
- **Issue:** Waybar couldn't detect Hyprland when started from SSH
- **Solution:** Start Waybar with `HYPRLAND_INSTANCE_SIGNATURE` environment variable
- **Location:** `~/.config/waybar/config`
- **Modules:** Power menu, workspaces, window title, clock, system stats, battery

**Removed:** Temporary [T] and [A] text shortcuts (replaced by keyboard shortcuts)

#### 5. Auto-login Configuration
- **Display Manager:** SDDM
- **Configuration:** `/etc/sddm.conf`
- **User:** jaded
- **Session:** Hyprland
- **Behavior:** Automatically logs in on boot, starts Hyprland and all services

### Files Modified

**Server Configuration Files:**
1. `~/.config/hypr/hyprland.conf`
   - Added wayvnc auto-start command
   - Added VNC-friendly keybindings (Ctrl + Enter, Ctrl + Space, etc.)
   - Added workspace switching and window movement keybindings

2. `~/.config/waybar/config`
   - Restored original configuration (power menu + workspaces)
   - Removed temporary text shortcuts

3. `/etc/sddm.conf`
   - Configured auto-login for user jaded
   - Set session to Hyprland

4. `~/.config/wayvnc/config.bak`
   - Backed up problematic config file (not used, command-line args used instead)

### Usage Instructions

#### Connecting to Desktop Remotely

**Step 1: Create SSH Tunnel**
```bash
# On Mac - open terminal and run:
ssh -L 5900:localhost:5900 jaded@192.168.1.228
# Keep this terminal open
```

**Step 2: Connect VNC Client**
```bash
# In another terminal or Finder (Cmd+K):
open vnc://localhost:5900

# OR use VNC Viewer app:
open -a "VNC Viewer" localhost:5900
```

**Step 3: Use the Desktop**
- Click to interact with windows and menus
- Use VNC-friendly keybindings (Ctrl+Enter, Ctrl+Space, etc.)
- No password required (secured by SSH tunnel)

#### Managing wayvnc Service

**Check if running:**
```bash
pgrep -a wayvnc
```

**View logs:**
```bash
tail -f /tmp/wayvnc.log
```

**Manually start (if needed):**
```bash
WAYLAND_DISPLAY=wayland-1 wayvnc 127.0.0.1 5900 --max-fps=30 --gpu &
```

**Restart Waybar (if workspace numbers missing):**
```bash
killall waybar
HYPRLAND_INSTANCE_SIGNATURE=$(ls -1 /run/user/1000/hypr/ | head -1) \
WAYLAND_DISPLAY=wayland-1 waybar &
```

### Technical Details

**Why SSH Tunnel?**
- **Security:** VNC traffic encrypted via SSH, no plaintext over network
- **No firewall changes:** Port 5900 never exposed to network
- **No VNC password needed:** SSH authentication provides security
- **Works remotely:** Same method works from anywhere (home or via Twingate)

**Why Ctrl Keybindings?**
- **VNC limitation:** SUPER (Windows/Command) key intercepted by VNC clients and host OS
- **Workaround:** Use Ctrl-based shortcuts that pass through VNC protocol
- **Dual support:** Both SUPER and Ctrl bindings coexist (SUPER for local, Ctrl for VNC)

**Performance Settings:**
- **FPS limit:** 30 FPS (good balance of responsiveness and bandwidth)
- **GPU acceleration:** Enabled for smoother rendering
- **Resolution:** Native 2880x1800 (Samsung eDP-1 display)

### Verification

**Connection verified working:**
- ✅ SSH tunnel establishes successfully
- ✅ VNC Viewer connects to localhost:5900
- ✅ Hyprland desktop visible and responsive
- ✅ Mouse input works
- ✅ Keyboard input works
- ✅ Ctrl+Enter opens terminal
- ✅ Ctrl+Space opens app launcher
- ✅ Workspace switching with Ctrl+1-9
- ✅ Window movement with Ctrl+Shift+1-9
- ✅ Waybar displays correctly with workspace numbers
- ✅ Auto-start works after reboot

### Troubleshooting Reference

**Issue: VNC connection refused**
```bash
# Check wayvnc is running
pgrep wayvnc

# Start if needed
WAYLAND_DISPLAY=wayland-1 wayvnc 127.0.0.1 5900 --max-fps=30 --gpu &
```

**Issue: Workspace numbers not showing in Waybar**
```bash
# Restart Waybar with Hyprland signature
killall waybar
HYPRLAND_INSTANCE_SIGNATURE=$(ls -1 /run/user/1000/hypr/ | head -1) \
WAYLAND_DISPLAY=wayland-1 waybar &
```

**Issue: Keybindings not working**
```bash
# Reload Hyprland config (from VNC or SSH)
hyprctl reload

# Or verify keybindings in config
grep -E "bind.*CTRL" ~/.config/hypr/hyprland.conf
```

**Issue: SSH tunnel drops**
```bash
# Keep SSH tunnel persistent with autossh
brew install autossh  # On Mac
autossh -M 0 -L 5900:localhost:5900 jaded@192.168.1.228
```

### Benefits

**Remote Access:**
- Full GUI access to server from anywhere
- No need to be physically at the machine
- Works over Twingate for remote access
- Can manage desktop applications remotely

**Development Workflow:**
- Can use graphical applications remotely
- Test GUI applications without being at server
- Access file managers, browsers, IDEs visually
- Debug desktop environment issues remotely

**Convenience:**
- VNC-friendly keyboard shortcuts for common tasks
- Auto-login on boot (no manual intervention needed)
- Persistent setup survives reboots
- Low bandwidth usage (30 FPS limit)

### Security Considerations

**Good Security Practices:**
- ✅ VNC only on localhost (not exposed to network)
- ✅ SSH tunnel provides encryption
- ✅ No VNC password needed (SSH auth is stronger)
- ✅ Firewall unchanged (port 5900 still blocked)
- ✅ Works with existing SSH key authentication

**Potential Concerns:**
- Auto-login means physical access = full access
  - Acceptable for home lab environment
  - Server is in secure location (home)
- VNC has no additional authentication
  - Mitigated by SSH tunnel requirement
  - Cannot connect without SSH access first

### Future Enhancements

**Possible Improvements:**
- Set up autossh for persistent SSH tunnel on Mac
- Configure VNC Viewer with saved connection
- Add additional Ctrl keybindings for more functions
- Optimize FPS based on network conditions
- Consider X11 forwarding for individual apps as alternative

### Documentation Updates

**Server Documentation (`~/README.md`):**
- Added wayvnc remote desktop access section
- Documented connection procedure
- Added keybinding reference
- Included troubleshooting steps

**Work Mac (`~/.claude/docs/homelab.md`):**
- Remote desktop access section added
- SSH tunnel configuration documented
- VNC client setup instructions
- Security model explanation

---

**Status:** ✅ Fully operational and tested
**Auto-start:** ✅ Configured (survives reboots)
**Security:** ✅ SSH tunnel only (no network exposure)
**Performance:** ✅ Smooth at 30 FPS with GPU acceleration
**Last Tested:** 2025-11-12

## 2026-05-06 - Added Homelable Visualizer LXC (CT 103) on book5

**What changed:**
- Created LXC 103 `homelable` on prox-book5 via community-scripts ProxmoxVE installer
  - Debian 13 unprivileged, 2 vCPU / 2 GB RAM / 8 GB disk on `local-zfs-book5`
  - Bridge `vmbr1`, IP `192.168.68.61` (DHCP)
  - Native install (Python 3.13 + uv venv + Node 20 + Caddy frontend), no Docker
- Configured `SCANNER_RANGES=["192.168.68.0/22"]` in `/opt/homelable/backend/.env`
- Added `homelable-mcp.service` (uvicorn on 0.0.0.0:8001) for AI integration
  - Generated `MCP_API_KEY` and `MCP_SERVICE_KEY`, stored in `/opt/homelable/mcp/.env` and backend `.env`
  - Wired into `~/.claude.json` as MCP server `homelable` (transport: `http`)
- User added Twingate resource for 192.168.68.61 (all ports) so it's reachable from Mac via tunnel

**Why:**
- Wanted a visual topology + live status overview of the homelab
- MCP integration lets Claude Code read topology, trigger scans, add/edit nodes during sessions

**Files modified:**
- `/etc/pve/lxc/103.conf` (book5) — new container
- `/etc/systemd/system/homelable.service` (CT 103) — backend systemd unit (created by installer)
- `/etc/systemd/system/homelable-mcp.service` (CT 103) — MCP server systemd unit (created manually)
- `/opt/homelable/backend/.env` (CT 103) — `SCANNER_RANGES` and `MCP_SERVICE_KEY`
- `/opt/homelable/mcp/.env` (CT 103) — MCP keys + `BACKEND_URL=http://localhost:8000`
- `~/.claude.json` (Mac) — added `homelable` MCP server entry
- `~/projects/homeLab/CLAUDE.md` — added CT 103 to current state
- `~/.claude/CLAUDE.md` — added CT 103 to Home Lab Quick Reference
- `~/.claude/docs/projects.md` — bumped Home Lab Last Updated, added Homelable to services

**Technical notes:**
- **Bridge gotcha:** community-scripts default is `vmbr0`. On book5 vmbr0 is inactive (post Feb-2026 router migration; vmbr1 is the 2.5GbE primary, already documented in global CLAUDE.md). First install attempt failed with "No IP assigned to CT 103 after 60 attempts". Fix: destroy + re-run with `var_brg=vmbr1` env var. Also pin CT ID with `var_ctid=103` (default would have picked 101 since 100/102 are used).
- **MCP transport:** Homelable's README says `--transport sse`, but the server uses `StreamableHTTPSessionManager`. Claude Code needs `type: "http"` (streamable-http), not `type: "sse"`. README is stale — verified via `claude mcp list` showing "Failed to connect" with `sse` and "Connected" with `http`.
- **Skipped host apt upgrade:** installer prompts to run `apt upgrade` on the Proxmox host — declined ([2] Ignore). Out of scope for one LXC install.
- **MCP server is native (not Docker):** community-scripts installer skips MCP entirely. Set up a venv at `/opt/homelable/mcp/.venv` and a separate systemd unit, mirroring the existing `homelable.service` pattern.

---

## 2026-05-06 - Populated Homelable Canvas via MCP

**What changed:**
- Seeded the Homelable canvas with 17 nodes / 13 edges / 4 parent links via MCP from a fresh Claude Code session
- Triggered first nmap scan (192.168.68.0/22) — discovered 26 devices
  - 10 hidden as duplicates of nodes already created
  - 4 approved with confident labels: TP-Link AP (192.168.71.250), PlayStation (.51), Nintendo Switch (.68), Google device (.56)
  - 2 hidden as randomized/transient MACs (visiting phones)
  - 10 left pending for user triage (mostly Espressif ESP32 + TP-Link smart-home gear)
- Created topology: gateway (192.168.68.1) at root → both Proxmox hosts, Pi-hole, Mac, IoT, mobile devices
- Set parent_id on VM/LXC nodes so they nest visually under their Proxmox host

**Why:**
- User wanted to see Homelable in action with their actual network — a fresh install ships with a demo canvas (Freebox Ultra / OpnSense / NAS-01 / etc.) which had been cleared
- Combined manual node creation from documented infrastructure with nmap-driven discovery for unknown devices

**Files modified:**
- (None on Mac — all changes via MCP to `/opt/homelable/data/homelab.db` on CT 103)

**Technical notes:**
- **Gateway and second AP same OUI:** gateway MAC `XX:XX:XX:XX:XX:XX` (.68.1) and `XX:XX:XX:XX:XX:XX` (.71.250) — adjacent MACs, both with the same TP-Link OUI prefix → almost certainly a mesh setup, primary router + AP/satellite. The .71.250 lives in the same /22 broadcast domain.
- **CT 102 trans IP:** 192.168.68.65 (was previously undocumented in network sheets).
- **OUI patterns on the network:** 6× Espressif (ESP32-based custom IoT — Tasmota/ESPHome/Shelly territory), 4× TP-Link (Tapo/Kasa devices), 1× Earda (smart switch/dimmer brand), plus consoles + Chromecast/Nest.
- **Approval payload format:** `approve_device` only takes `id`, `label`, `type`. To set `hostname`/`ip`/`status` afterward, use `update_node`. (We didn't need to since the discovered IP is auto-applied by approve.)
- **Edge defaults:** modeled wifi devices as connecting directly to the gateway (logical topology), not through the AP — Homelable canvas is meant to be a logical map, not a physical L2 trace.

---
