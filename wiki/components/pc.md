---
type: component
title: pc
tags: [windows, wsl, production, coa, run_full_sync, cron, rustdesk, ics, google-drive, reverse-tunnel]
related: [access-model, mac, go, phone, s9-tablet, s10, pi1]
host: pc
ip: n/a
---

# pc (Windows PC + WSL — Elevated PRODUCTION)

Custom desktop, **hostname `etintake`**, Windows 11 + WSL2 Ubuntu. Physically at the
Elevated office (roams on `192.168.1.x` work Wi-Fi). This box is the **production
runner** for the photos→web automation: the WSL side runs `run_full_sync.sh` every
15 min (crawler → COA extraction → inventory sync). Roaming sibling of [[mac]] [[go]]
[[phone]] [[s9-tablet]] [[s10]]; hosts [[pi1]]'s internet via Ethernet ICS.

- **SSH:** `ssh pc` / `ssh pc-local` (PowerShell, port 22); `ssh wsl` / `ssh wsl-local` (WSL Ubuntu, port 2222). Bare alias = Tailscale, `-local` = LAN. Full model → [[access-model]].
- **Role:** Mac = staging, **WSL = production**. Never deploy code to WSL until the user explicitly says so.

## Roles: Windows vs WSL

| Layer | What runs there |
|-------|-----------------|
| **WSL2 Ubuntu** | **Production cron** (`run_full_sync.sh` 15-min), COA extraction, inventory sync, Twingate connector (Docker), SSH server (port 2222) |
| **Windows** | Google Drive File Stream (H:/I:), RustDesk service, reverse-tunnel + heartbeat Scheduled Tasks, ICS gateway for [[pi1]], `netsh portproxy` forwards |

## Network

| Interface | IP | Purpose |
|-----------|-----|---------|
| Wi-Fi | `192.168.1.193` (DHCP, work location) | Main network, Twingate client |
| Ethernet | `192.168.137.1` | ICS gateway for [[pi1]] |

```
Mac → Tailscale/Twingate → PC:22 (PowerShell)
Mac → PC:2222 → netsh portproxy → WSL:22
Pi1 → PC:192.168.137.1 (ICS NAT) → Wi-Fi → Internet
```

> NOTE: The deep doc frames direct SSH as "broken, use the book5 reverse tunnel." Per the authoritative CLAUDE.md (SSH inversion 2026-05-27), `ssh pc`/`ssh wsl` now reach the box **over Tailscale** (the book5 reverse tunnels for pc/wsl/go were dropped). The Windows reverse-tunnel Scheduled Task still exists as a fallback — see [Reverse Tunnel](#reverse-tunnel-fallback) — but Tailscale is the primary path.

## SSH Servers

**PowerShell (port 22)** — Win32-OpenSSH 9.8p2 (GitHub release), `C:\Program Files\OpenSSH`.
- In-box System32 OpenSSH (9.5) still exists but the service points to Program Files.
- Known issue: the 10.0 preview has an SCM timeout (error 1053) on this machine — service won't start. Revisit when a stable release ships.

**WSL Ubuntu (port 2222)** — SSH server inside WSL2, port-forwarded from Windows via `netsh portproxy` (2222 → WSL:22).

```
Mac → Windows:2222 → netsh portproxy → WSL:22 → SSH
```

### WSL SSH auto-start

WSL runs `/etc/wsl-ssh-startup.sh` on boot (via `/etc/wsl.conf`). It starts sshd and
re-points the Windows port-proxy at the current WSL IP (which changes on each WSL boot):

```bash
#!/bin/bash
mkdir -p /run/sshd
rm -f /run/nologin /etc/nologin
service ssh start

# Update Windows port forwarding to current WSL IP
WSL_IP=$(hostname -I | awk '{print $1}')
powershell.exe -Command "netsh interface portproxy delete v4tov4 listenport=2222 listenaddress=0.0.0.0" 2>/dev/null
powershell.exe -Command "netsh interface portproxy add v4tov4 listenport=2222 listenaddress=0.0.0.0 connectport=22 connectaddress=$WSL_IP"
```

Manual fix if SSH fails after reboot — `/usr/local/bin/fix-wsl-ssh` (run `sudo /usr/local/bin/fix-wsl-ssh`):

```bash
#!/bin/bash
sudo mkdir -p /run/sshd
sudo rm -f /run/nologin /etc/nologin
sudo service ssh restart

WSL_IP=$(hostname -I | awk '{print $1}')
powershell.exe -Command "netsh interface portproxy delete v4tov4 listenport=2222 listenaddress=0.0.0.0"
powershell.exe -Command "netsh interface portproxy add v4tov4 listenport=2222 listenaddress=0.0.0.0 connectport=22 connectaddress=$WSL_IP"
echo "WSL IP: $WSL_IP, port forwarding updated"
```

## Automated Full Sync (WSL — PRODUCTION)

The core reason this machine exists. Cron on WSL runs `~/projects/run_full_sync.sh`
every 15 min: **crawler** (forces Google Drive to download COA PDFs locally) →
**COA extraction** (PDF → Google Sheets) → **inventory sync** (Odoo → Sheets).
STEP 5 of this same script builds the `elevatedWeb` WP/WooCommerce pages (see that
project's docs).

```bash
# Manual run
~/projects/run_full_sync.sh

# Check schedule
crontab -l | grep run_full_sync
```

**Cron entry:**
```bash
# Every 15 minutes
14,29,44,59 * * * * /home/joshua/projects/run_full_sync.sh >> /home/joshua/projects/sync.log 2>&1
```

**Typical timing:** crawler ~15 s, COA extraction ~55 s, inventory ~10 s → **~1:20 total**.

### Sync-script behavior

1. **Check Google Drive** — `tasklist.exe` finds `GoogleDriveFS.exe`.
2. **Auto-start if needed** — triggers the `StartGoogleDrive` scheduled task, waits 30 s, retries up to 3×.
3. **Mount drives** — ensures `/mnt/h` (Elevated) and `/mnt/i` (Dax) are mounted.
4. **Auto-restart Google Drive** — if mounts fail and H: doesn't exist in Windows, kills + restarts Google Drive (fixes the "running but no drives" state after updates/sleep/wake).
5. **Run crawler** — reads first byte of each PDF to force cloud download.
6. **Extract COA** — runs `extract_coa_data.py` for Elevated.
7. **Inventory sync** — runs `inventory_sync.py`.

### GOTCHA: WSL interop in cron/SSH

Cron jobs and SSH sessions **do not** inherit `WSL_INTEROP`, required to call Windows
`.exe` from WSL. The script auto-detects the interop socket at startup:

```bash
# Added to top of run_full_sync.sh (after set -e)
if [ -z "$WSL_INTEROP" ]; then
    for socket in /run/WSL/*_interop; do
        if [ -S "$socket" ]; then
            export WSL_INTEROP="$socket"
            break
        fi
    done
fi
```

If Windows exe calls fail with "Invalid argument", re-register the interop binfmt entry
(needed after WSL restarts):
```bash
sudo sh -c 'echo :WSLInterop:M::MZ::/init:PF > /proc/sys/fs/binfmt_misc/register'
```
Any other WSL script calling `.exe` from cron/SSH needs the same interop-detection pattern.

### Google Drive auto-start (Scheduled Task)

GUI apps can't be launched from a non-interactive WSL/SSH session, so the sync script
triggers a Windows scheduled task that runs in the interactive session:

```powershell
schtasks /query /tn "StartGoogleDrive"        # view
schtasks /run /tn "StartGoogleDrive"           # from Windows
/mnt/c/Windows/System32/schtasks.exe /run /tn "StartGoogleDrive"   # from WSL
```
Task: **StartGoogleDrive**, on-demand only, runs `C:\scripts\start-gdrive.bat` →
`start "" "C:\Program Files\Google\Drive File Stream\launch.bat"`.

### View logs
```bash
tail -f ~/projects/sync.log
```

## COA Script Sync System (Mac ↔ WSL) — `local_config.py` pattern

The COA extraction scripts (`extract_coa_data.py`) run on both [[mac]] (staging) and
WSL (production) but need different Google Drive paths. Code is kept identical; the
machine-specific paths live in a **gitignored `local_config.py`** (never synced), with
a tracked `local_config.py.example` template. When code changes, **only
`extract_coa_data.py` is copied** — `local_config.py` stays put on each machine.

| File | Tracked? | Purpose |
|------|----------|---------|
| `extract_coa_data.py` | Yes | Main script (synced between machines) |
| `local_config.py` | **No** | Machine-specific paths (never synced) |
| `local_config.py.example` | Yes | Template for a new machine |

**Machine-specific paths — `coa/` (Elevated):**

| Variable | Mac | WSL |
|----------|-----|-----|
| `COA_BASE` | `/Users/j/Library/CloudStorage/GoogleDrive-joshua@elevatedtrading.com/Shared drives/Elevated Trading, LLC/COA's` | `/mnt/h/Shared drives/Elevated Trading, LLC/COA's` |
| `CREDENTIALS_PATH` | `~/projects/odooReports/AR_AP/credentials.json` | `~/projects/odooReports/AR_AP/credentials.json` |
| `TOKEN_PATH` | `~/projects/odooReports/inventory/sheets_token.json` | `~/projects/odooReports/inventory/sheets_token.json` |

**`coaDax/` (Dax Distro):**

| Variable | Mac | WSL |
|----------|-----|-----|
| `COA_FOLDER` | `/Users/j/joshua@daxdistro.com - Google Drive/My Drive/1 - THCa Flower COAs` | `/mnt/i/.shortcut-targets-by-id/1v9wlV4MbLRypk-PwGZNzI6KYrKN9qnpX/1 - THCa Flower COAs` |

**Sync scripts Mac → WSL** (only the code, never `local_config.py`):
```bash
# From Mac
scp ~/projects/coa/extract_coa_data.py wsl:~/projects/coa/
scp ~/projects/coaDax/extract_coa_data.py wsl:~/projects/coaDax/

# Both at once
scp ~/projects/coa/extract_coa_data.py wsl:~/projects/coa/ && \
scp ~/projects/coaDax/extract_coa_data.py wsl:~/projects/coaDax/
```

**First-time WSL setup:**
```bash
ssh wsl
cd ~/projects/coa    && cp local_config.py.example local_config.py && nano local_config.py
cd ~/projects/coaDax && cp local_config.py.example local_config.py && nano local_config.py
```

WSL `local_config.py` for `coa/`:
```python
from pathlib import Path

COA_BASE = Path("/mnt/h/Shared drives/Elevated Trading, LLC/COA's")
CREDENTIALS_PATH = Path.home() / "projects" / "odooReports" / "AR_AP" / "credentials.json"
TOKEN_PATH = Path.home() / "projects" / "odooReports" / "inventory" / "sheets_token.json"
```

WSL `local_config.py` for `coaDax/`:
```python
from pathlib import Path

COA_FOLDER = Path("/mnt/i/.shortcut-targets-by-id/1v9wlV4MbLRypk-PwGZNzI6KYrKN9qnpX/1 - THCa Flower COAs")
```

**Verify:**
```bash
cd ~/projects/coa    && python3 -c "from local_config import COA_BASE; print(COA_BASE); print(COA_BASE.exists())"
cd ~/projects/coaDax && python3 -c "from local_config import COA_FOLDER; print(COA_FOLDER); print(COA_FOLDER.exists())"
```

**Rules:** develop on Mac first → only sync `extract_coa_data.py` → check paths after sync →
keep `local_config.py.example` updated when adding config vars.

## WSL Google Drive Mounts

`/etc/fstab`:
```
H: /mnt/h drvfs defaults,nofail 0 0
I: /mnt/i drvfs defaults,nofail 0 0
```
`nofail` is **critical** — without it, WSL boot fails when Google Drive isn't ready,
leaving `/var/run/nologin` in place and blocking SSH logins.

> WSL can't use the Drive mounts for extraction (drvfs permission limits on Google
> Drive's virtual FS). Production COA extraction runs on **Windows Python** via the
> crawler-then-extract flow; the WSL mounts are for path checks only.

**Auto-mount cron** — `/usr/local/bin/ensure-mounts.sh`, `/etc/cron.d/ensure-mounts`
(every 5 min as root), logs `/var/log/ensure-mounts.log`:
```bash
mountpoint /mnt/h && mountpoint /mnt/i     # check
tail /var/log/ensure-mounts.log            # log
sudo /usr/local/bin/ensure-mounts.sh       # manual
```

**Mount-on-demand in scripts:**
```bash
mountpoint -q /mnt/h || sudo mount -t drvfs H: /mnt/h
mountpoint -q /mnt/i || sudo mount -t drvfs I: /mnt/i
```
```python
# Python: ensure_wsl_mounts() in inventory_sync.py
import subprocess
for drive, mp in [("H:", "/mnt/h"), ("I:", "/mnt/i")]:
    if subprocess.run(["mountpoint", "-q", mp], capture_output=True).returncode != 0:
        subprocess.run(["sudo", "mount", "-t", "drvfs", drive, mp])
```

**Drive accounts:** H: = `joshua@elevatedtrading.com`, I: = `joshua@daxdistro.com`.

## Windows Scheduled Tasks & Services

| Service / Task | Where | Purpose |
|----------------|-------|---------|
| Twingate Client | Windows | Outbound homelab access (jaded423 network) |
| Reverse SSH Tunnel | Scheduled Task (VBS hidden) | Fallback inbound via book5:2245 → see below |
| PC Heartbeat | Scheduled Task (VBS hidden, every 2 min) | Heartbeat ping to n8n via book5 |
| Start WSL Cron | Scheduled Task (VBS hidden) | Starts cron + keeps WSL alive |
| RustDesk | Windows Service | Remote desktop (direct mode needs the service running) |
| ICS | Ethernet adapter | Internet for [[pi1]] |
| StartGoogleDrive | Scheduled Task | On-demand — starts Google Drive (triggered by sync) |
| COA Sync (legacy) | Scheduled Task, daily 6 AM | Windows-native `C:\scripts\run_coa_sync.ps1` — legacy, superseded by the WSL 15-min cron |

**Twingate connector** (Docker inside WSL):
```bash
docker ps | grep twingate
docker restart twingate-connector
```

**Pi1 ICS + port forward** — Windows shares its Wi-Fi to [[pi1]] over Ethernet
(`192.168.137.1`) and forwards SSH:
```powershell
netsh interface portproxy show v4tov4    # view rules
netsh interface portproxy add v4tov4 listenport=2223 listenaddress=0.0.0.0 connectport=22 connectaddress=192.168.137.123
```
> Pi1 is also on Tailscale (`100.98.16.63`), so `ssh pi1` is reachable independent of
> which host's ICS it's using — but its *internet* still requires this PC (or Mac) on.

**Windows-native COA scripts** (`C:\scripts\`, legacy) — `gdrive_crawler.ps1`,
`run_coa_sync.ps1` (crawler → Elevated COA → Dax COA), with `coa\` and `coaDax\`
subdirs holding their own `extract_coa_data.py` + credentials. Superseded by the WSL
cron pipeline; kept as a fallback. Python 3.12 via winget at
`C:\Users\joshu\AppData\Local\Programs\Python\Python312`.

## RustDesk (remote desktop)

Full remote-access model → [[access-model]]. Direct-LAN mode needs the **RustDesk
service running** AND firewall TCP **53037** open; otherwise it falls back to the Azure
relay (grainy, ~+30 ms).

```powershell
Get-Service RustDesk
Start-Service RustDesk
Get-NetFirewallRule -DisplayName '*RustDesk*53037*'
# If missing:
New-NetFirewallRule -DisplayName 'RustDesk Direct TCP 53037' -Direction Inbound -Protocol TCP -LocalPort 53037 -Action Allow -Profile Any
```
Verify from Mac during a session: `netstat -an | grep 192.168.1.193` (direct) vs
`grep 21117` (relayed). Direct = Mac → PC:53037 TCP + UDP:21119.

### GOTCHA: RustDesk "Bad TOML data" / won't connect

Root cause: `RustDesk2.toml` option values written **without quotes** — TOML requires
string values quoted. CM log shows `ERROR Failed to load config 'RustDesk2.toml': Bad TOML data`.
Config: `C:\Users\joshu\AppData\Roaming\RustDesk\config\RustDesk2.toml`.

```powershell
# Check CM log
type C:\Users\joshu\AppData\Roaming\RustDesk\log\cm\RustDesk_rCURRENT.log

# Fix: quote all option values, e.g.:
# direct-server = 'Y'        (not: direct-server = Y)
# allow-always-relay = 'N'   (not: allow-always-relay = N)

# Restart after fixing
net stop RustDesk && net start RustDesk
```

## Reverse Tunnel (fallback)

Access model / tunnels → [[access-model]]. PC runs the Twingate **client** for outbound;
inbound historically used a reverse SSH tunnel through book5 (`Mac → book5 → localhost:2245 → PC:22`).
Since the 2026-05-27 SSH inversion, Tailscale is the primary inbound path and the pc/wsl
book5 tunnels were dropped — but the Windows Scheduled Task still exists as a fallback.

**Scheduled Task "SSH Tunnel to book5":**
- Trigger: system startup (30 s delay), single trigger; multi-instance IgnoreNew; restart-on-failure 999× / 1 min apart.
- Action: `wscript.exe //nologo C:\Users\joshu\bin\start-tunnel.vbs` (hidden) → launches `start-tunnel.ps1` (infinite reconnect loop, 10 s between attempts).
- SSH keepalive 60 s, drops after 3 failures. Key: `C:\Users\joshu\.ssh\id_ed25519`.
- Boot: ~70 s window while Twingate stabilizes; tunnel auto-reconnects. Task shows "Ready" (not "Running") because the VBS wrapper is fire-and-forget.

```powershell
wscript //nologo "C:\Users\joshu\bin\start-tunnel.vbs"   # manual start (hidden)
schtasks /run /tn "SSH Tunnel to book5"                   # via task scheduler
schtasks /end /tn "SSH Tunnel to book5"                   # stop
```

## Troubleshooting

**SSH fails after reboot** → `sudo /usr/local/bin/fix-wsl-ssh` (in WSL).

**"System is booting up" error** → fstab mount failures leave `/var/run/nologin`.
Permanent fix = `nofail` in fstab (above). Immediate: `sudo rm -f /run/nologin /etc/nologin`.

**WSL IP changed** → auto-start script handles it; manual:
```bash
hostname -I
powershell.exe -Command "netsh interface portproxy delete v4tov4 listenport=2222 listenaddress=0.0.0.0"
powershell.exe -Command "netsh interface portproxy add v4tov4 listenport=2222 listenaddress=0.0.0.0 connectport=22 connectaddress=$(hostname -I | awk '{print $1}')"
```

**Windows IP changed (DHCP)** → update the Twingate resource, or set a DHCP reservation on the router.

**Google Drive won't start:**
```bash
/mnt/c/Windows/System32/schtasks.exe /query /tn "StartGoogleDrive"
cat /mnt/c/scripts/start-gdrive.bat   # should: start "" "C:\Program Files\Google\Drive File Stream\launch.bat"
```

**Mounts failing / "running but no drives"** (H:/I: missing from Windows):
```bash
/mnt/c/Windows/System32/tasklist.exe | grep -i GoogleDriveFS
mountpoint /mnt/h && echo "H: mounted" || echo "H: not mounted"
/mnt/c/Windows/System32/cmd.exe /c "if exist H:\\ (echo H: exists) else (echo H: missing)"
# If missing, restart Google Drive:
/mnt/c/Windows/System32/taskkill.exe /f /im GoogleDriveFS.exe
/mnt/c/Windows/System32/schtasks.exe /run /tn "StartGoogleDrive"
# wait ~60s, then:
sudo mount -t drvfs H: /mnt/h
sudo mount -t drvfs I: /mnt/i
```
(The sync script now does this automatically.)

**Can't reach [[pi1]]** → 1) PC powered on, 2) ICS enabled on the Ethernet adapter,
3) port-forward rule exists (`netsh interface portproxy show v4tov4`).

## Sources

- `~/.claude/docs/homelab/pc.md` (deep doc)
- `~/projects/homeLab/CLAUDE.md` — Operational Current State (lines 45–119, SSH inversion + roaming devices)
