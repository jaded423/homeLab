---
type: component
title: phone
tags: [phone, s25, samsung, termux, proot, mdns, reverse-tunnel, roaming, ssh-tunnels]
related: [access-model, mac, go, pc, s9-tablet, s10, dns-adblocking, book5, vm100-omarchy, vm101-ubuntu]
host: s25
ip: n/a
---

# phone (Samsung S25 Ultra / Termux)

Samsung Galaxy S25 Ultra running **Termux (proot)** as a homelab node: an SSH server,
a persistent reverse tunnel back to [[book5]], and a set of SSH tunnels that expose homelab
web services on `localhost`. A **roaming device** — reachable from any network via its
reverse tunnel + mDNS. Roaming sibling of [[mac]] [[go]] [[pc]] [[s9-tablet]] [[s10]].

- **Access (from Mac / anywhere):** `ssh s25` — canonical, **mDNS** (works on any LAN sharing the broadcast domain). Full model → [[access-model]].
- **Termux user:** `u0_a499` · **SSH server port:** `8022` · **Shell:** zsh + oh-my-zsh + powerlevel10k.

## SSH — the four aliases

`ssh s25` is the canonical entry (mDNS, resolves wherever the phone shares the broadcast
domain). Three explicit-method aliases pin a specific path:

| Alias | Path / target | When |
|-------|---------------|------|
| `ssh s25` | mDNS (advertised by proot mDNS advertiser) | canonical — any shared-broadcast LAN |
| `ssh s25-home` | `192.168.68.200` (home LAN, `.200` DHCP-reserved) | on home WiFi |
| `ssh s25-work` | `192.168.1.37` (work LAN, stable but not reserved) | at work |
| `ssh s25-tunnel` | ProxyJump [[book5]] → `localhost:2247` | from anywhere (reverse tunnel) |

> NOTE: frontmatter `ip: n/a` because the phone has no single stable IP — it roams. `.200`
> (home) and `.1.37` (work) are the per-LAN addresses behind the `-home`/`-work` aliases.

Local Termux SSH server listens on `:8022`; from a same-LAN host without the alias:
`ssh -p 8022 192.168.68.200`. SSH keys on the phone: `~/.ssh/id_ed25519` (primary,
`termux@s25ultra`) + `~/.ssh/id_rsa` (RSA fallback); authorized on tower, book5, omarchy,
ubuntu, S9 FE, S10+.

### proot `.ssh` path quirk
The phone runs Termux under **proot**. proot reads its SSH config from **`/home/jaded/.ssh/config`**
(the passwd-file home) **NOT** `$HOME/.ssh/config`. When pushing SSH config to the phone,
target that absolute path and use `scp -O` (legacy protocol).

## Reverse tunnel

Persistent SSH reverse tunnel to [[book5]] gives remote access from any network (this is
what `s25-tunnel` and the roaming reach ride on):

- **Port:** `2247` on book5 → phone's `:8022`.
- Access path → [[access-model]]. Roaming reverse-tunnel pattern is shared with [[mac]] [[go]] [[pc]] [[s9-tablet]] [[s10]].

## Termux:Boot autostart (+ reboot gotcha)

Boot scripts under `~/.termux/boot/` are run by the Termux:Boot app at device boot:

| Script | Starts |
|--------|--------|
| `~/.termux/boot/start-services` | wake-lock + `sshd` + tunnel-watchdog |
| `~/.termux/boot/start-mdns-advertise` | mDNS advertiser (inside proot) — powers `ssh s25` |

Older single-purpose form still documented: `~/.termux/boot/start-sshd.sh` →
```bash
#!/data/data/com.termux/files/usr/bin/bash
sshd
```

**Boot sequence:** phone boots → Android launches Termux:Boot → runs the boot scripts →
`sshd` up on `:8022` + reverse tunnel + mDNS advertised → first interactive shell login
triggers `start_tunnels` via `.zshrc`.

> **GOTCHA (reboot required):** Termux:Boot autostarts sshd/tunnel/mDNS **only at a real
> phone reboot**. Editing a boot script does **not** take effect until the phone is actually
> rebooted — there is no re-run-on-save. After changing anything in `~/.termux/boot/`, reboot
> the phone to apply.

## SSH tunnels (homelab services on localhost)

On interactive shell launch, `.zshrc` calls `start_tunnels`, opening two tmux-held SSH tunnel
sessions so phone-browser `localhost:PORT` reaches homelab services (avoids the n8n
secure-cookie issue; only tunneled ports route through the homelab, all other traffic stays on
WiFi/LTE).

**Omarchy tunnels** (tmux session `tunnels`) → [[vm100-omarchy]]:

| localhost | Remote | Service |
|-----------|--------|---------|
| :5678 | omarchy:5678 | n8n |
| :11434 | omarchy:11434 | Ollama |
| :8000 | omarchy:8000 | tapo-rest |

**Ubuntu tunnels** (tmux session `ubuntu-tunnels`) → [[vm101-ubuntu]]:

| localhost | Remote | Service |
|-----------|--------|---------|
| :32400 | ubuntu:32400 | Plex |
| :5000 | ubuntu:5000 | Frigate |
| :8080 | ubuntu:8080 | qBittorrent |
| :3000 | ubuntu:3000 | Open WebUI |

`.zshrc` autostart:
```bash
# Auto-start homelab tunnels on Termux launch
start_tunnels() {
  # Omarchy services (n8n, Ollama, tapo-rest)
  if ! tmux has-session -t tunnels 2>/dev/null; then
    tmux new-session -d -s tunnels 'ssh -N \
      -L 5678:localhost:5678 \
      -L 11434:localhost:11434 \
      -L 8000:localhost:8000 \
      -o ServerAliveInterval=60 -o ServerAliveCountMax=3 omarchy'
    echo "Omarchy tunnels started"
  fi

  # Ubuntu services (Plex, Frigate, qBittorrent, Open WebUI)
  if ! tmux has-session -t ubuntu-tunnels 2>/dev/null; then
    tmux new-session -d -s ubuntu-tunnels 'ssh -N \
      -L 32400:localhost:32400 \
      -L 5000:localhost:5000 \
      -L 8080:localhost:8080 \
      -L 3000:localhost:3000 \
      -o ServerAliveInterval=60 -o ServerAliveCountMax=3 ubuntu'
    echo "Ubuntu tunnels started"
  fi
}
start_tunnels
```

Accessing services in the phone browser: n8n `http://localhost:5678` · Plex
`http://localhost:32400/web` · Frigate `http://localhost:5000` · qBittorrent
`http://localhost:8080` · Open WebUI `http://localhost:3000` · Ollama API
`http://localhost:11434`.

### `mole` — tunnel health check / auto-repair
`mole` curls a canary port for each tunnel (n8n :5678 for omarchy, Frigate :5000 for ubuntu);
if dead it `pkill`s the zombie ssh, kills the tmux session, and recreates the tunnel:
```bash
mole    # check health and auto-repair dead tunnels
```

Manual management:
```bash
tmux list-sessions                    # what's running
tmux kill-session -t tunnels          # drop omarchy tunnels
tmux kill-session -t ubuntu-tunnels   # drop ubuntu tunnels
start_tunnels                         # bring them back
tmux attach -t tunnels                # watch output (detach: Ctrl+B, D)
```
Add a port on the same server: append `-L <local>:localhost:<remote>` to that session's `-L`
chain in `.zshrc`. Local ports must be unique across all tunnels; remote ports may repeat on
different servers.

## Private DNS (Pi-hole ad-blocking, away from home)

Off home WiFi, the phone routes DNS through Pi-hole for ad-blocking via Android **Private DNS
(DoT)** → the tunnel: full detail → [[dns-adblocking]].

- **Setup:** Settings → Network & Internet → Private DNS → `dns.jadedviber.com`.
- Uses DoT on **port 853** (does NOT conflict with the VPN slot); traffic flows phone →
  Android Private DNS → `dns.jadedviber.com:853` → tunnel → [[book5]] dnsproxy → Pi-hole
  (`192.168.68.248:53`).
- Do **NOT** enable a client "Secure DNS" / custom DoH — causes a circular dependency.

## Troubleshooting

```bash
tmux list-sessions        # tunnel sessions present?
ps aux | grep ssh         # ssh processes running?
start_tunnels             # recreate tunnels
ssh -v omarchy            # verbose SSH for a failing hop
ssh-keygen -R <ip>        # clear a changed host key, then reconnect
```
- **Connection refused on localhost:** tunnel died (`start_tunnels` / `mole`), or the remote
  service is down.
- **Omarchy tunnel is flakier than Ubuntu** — check `mole` output first when omarchy services
  are unreachable.
- **Powerlevel10k gitstatus:** the gitstatus binary doesn't run on Termux/Android — fixed by
  removing `vcs` from the `~/.p10k.zsh` left-prompt elements (2026-01-17).

> NOTE: the deep doc describes the phone's outbound SSH as routing **phone → Twingate → tower →
> destination** (pre-2026-05-27). The authoritative current state inverted the unified SSH
> pattern to **Tailscale** (`ssh device` = Tailscale, anywhere via MagicDNS); the phone's tunnel
> targets (`omarchy`/`ubuntu`) now ride that. Reach *to* the phone is via mDNS / the book5
> reverse tunnel as documented above. Cross-cutting detail → [[access-model]].

## Sources
- `~/.claude/docs/homelab/phone.md` (deep doc)
- `~/projects/homeLab/CLAUDE.md` "Operational Current State" (authoritative, S25 rows + SSH-inversion note)
