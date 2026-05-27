# Network Cleanup — Follow-up TODO

Open items from the 2026-05-27 Tailscale-vs-Twingate consolidation session. None are blocking; the core split is done (Tailscale = admin/SSH + web UIs + RustDesk; Twingate = VM101/Mullvad apps + HA + remote-site).

## 1. Auto-reapply book5 DNS override (recurring)
**Problem:** Twingate client updates revert book5's `sdwan0` NM DNS back to the dead `100.95.0.x` resolvers → all book5 DNS breaks → `prox-book5-systemd` connector can't heartbeat (shows DEAD in TG admin while `systemctl` says active). Happened 2026-05-20 and again 2026-05-23. Manual re-fix each time.

**Fix to build:** upgrade `/usr/local/bin/network-health-monitor.sh` `check_dns()` from log-only to auto-remediate. When it detects `100.95.0.x` in `/etc/resolv.conf` AND DNS resolution failing, run:
```
nmcli connection modify sdwan0 ipv4.dns 192.168.68.248 ipv4.ignore-auto-dns yes
nmcli device reapply sdwan0
systemctl restart twingate-connector
```
Backup current watchdog first. See memory `project_book5_dns_sdwan0_override`.

## 2. Fix MagicDNS on Pixelbook Go (CachyOS)
**Problem:** Go's Tailscale flagged a MagicDNS / systemd-resolved↔NetworkManager conflict at install. Doesn't affect reaching Go (IP-based `go-ts` alias works from Mac), only Go resolving *other* tailnet names by hostname.

**Fix:** on Go, resolve the resolved/NM conflict so `100.100.100.100` is authoritative for `*.tail950cc2.ts.net` (typically `systemctl enable --now systemd-resolved` + point `/etc/resolv.conf` → stub, or `tailscale set --accept-dns=true` with resolved active). Then `ssh book5` / browsing by name works *from* Go.

## 3. Delete HA pre-rename backup (once stable)
After home-assistant (VM 111, renamed from 112 on 2026-05-27) is confirmed stable for a day or two, delete the safety backup on tower:
```
ssh tower 'rm /var/lib/vz/dump/vzdump-qemu-112-2026_05_27-11_37_00.vma.zst*'
```

## 4. (minor) n8n editor base URL
n8n on omarchy still has `N8N_EDITOR_BASE_URL=http://localhost:5678` and `WEBHOOK_URL=http://192.168.68.100:5678/` in `~/docker/tower-guardian/docker-compose.yml`. Works, but for clean links over Tailscale consider `http://omarchy:5678`. Only change WEBHOOK_URL if no external services depend on the `.100` webhook URL. (Secure-cookie issue already fixed via `N8N_SECURE_COOKIE=false` on 2026-05-27.)

## Optional alternative: Tailscale Serve for HTTPS
Instead of `N8N_SECURE_COOKIE=false`, could front n8n (and other web UIs) with `tailscale serve` for a real HTTPS cert (`https://omarchy.tail950cc2.ts.net`) — satisfies secure cookie properly and drops the cert warnings on Proxmox/Cockpit. More setup; revisit if the http access ever feels wrong.
