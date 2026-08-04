---
type: component
title: S9 FE Tablet (Termux node)
tags: [s9, tablet, termux, android, roaming, on-demand-tunnel, ssh]
related: [access-model, book5, phone, mac, go, pc, s10]
host: s9
ip: 192.168.68.50
---

Samsung Galaxy Tab S9 FE running Termux as a full homelab dev node — Claude Code, neovim, tmux, sesh, and SSH into the whole homelab. Roaming sibling of [[mac]] [[go]] [[pc]] [[phone]] [[s10]]. Reverse tunnel to [[book5]] is **on-demand** (`s9up`/`s9down`) to save battery, not persistent.

## At a glance

| | |
|---|---|
| IP | 192.168.68.50 (DHCP reserved) |
| SSH port | 8022 (Termux limitation, not 22) |
| User | `u0_a348` |
| Reverse tunnel | book5:2249 (on-demand) |
| Shell | zsh + Oh My Zsh + Powerlevel10k |
| tmux prefix | **Ctrl+A** (Android eats Ctrl+Space) |

## Access

```bash
ssh s9            # Via tunnel: ProxyJump book5 → localhost:2249 (needs tunnel up)
ssh s9-local      # Direct: 192.168.68.50:8022 (same network only)
```

Full access-model / roaming-tunnel pattern → [[access-model]].

## On-demand reverse tunnel

Not persistent — brought up only when needed, to save tablet battery. Run from [[book5]] (or phone with the same aliases):

```bash
s9up      # Bring tunnel up (SSHs to device, starts wake-lock + tunnel)
s9down    # Kill tunnel, release wake-lock

# Underlying scripts on book5:
/root/bin/tunnel-up.sh s9
/root/bin/tunnel-down.sh s9
```

Once `s9up` has run, `ssh s9` works from anywhere; otherwise use `ssh s9-local` on the LAN.

## Boot auto-start (Termux:Boot)

`~/.termux/boot/start-services` starts **sshd only** (with watchdog) on device boot — the tunnel is deliberately NOT auto-started (battery).

- sshd via `~/bin/keep-sshd.sh` watchdog — checks every 30s, restarts sshd if Samsung OOM-kills it
- Logs to `~/boot.log`

## SSH keys / config

- `~/.ssh/id_ed25519` — primary key; pubkey distributed to book5, Mac, Phone (`authorized_keys`)
- `~/.ssh/config` mirrors homelab topology (hosts added Mar 2026: pc, wsl, pi1; the `dax` host was removed in the 2026-07-06 teardown)

## Dev workflow stack

| Tool | Purpose | Notes |
|------|---------|-------|
| Claude Code | AI assistant | v2.1.71 via npm (nodejs-lts) |
| neovim | Editor | Config: jaded423/nvimConfig from GitHub |
| tmux | Multiplexer | TPM + catppuccin, **prefix Ctrl+A** |
| sesh | Session manager | Go install, Ctrl+A then Shift+S |
| fzf | Fuzzy finder | Ctrl+T/R/F |
| zoxide | Smart cd | `z` |
| bat / eza / fd / ripgrep | Better cat/ls/find/grep | `lss`, `lsa`, `rg` |
| lazygit | Git TUI | |
| golang / python / clang | Languages / build | golang required for sesh |

### tmux prefix convention

Each machine uses a unique prefix so nested SSH sessions don't collide:

| Device | Prefix | Rationale |
|--------|--------|-----------|
| Mac | Ctrl+Space | Primary workstation |
| Tablet (S9 FE) | **Ctrl+A** | Android eats Ctrl+Space for input method |
| book5 | Ctrl+B | Allows nesting from Mac/tablet |

Nesting example: Mac (Ctrl+Space) → SSH book5 (Ctrl+B) → no conflict.

## Claude Code on Termux (required fix)

Environment variables in `~/.zshrc` — without these Claude Code fails on Termux:

```bash
# Claude Code — redirect sandbox to Termux-writable tmp
export TMPDIR=$PREFIX/tmp
export CLAUDE_CODE_TMPDIR=$PREFIX/tmp
export CLAUDE_TMPDIR=$PREFIX/tmp/claude

# Disable native install migration (native binary incompatible with Android/Termux)
export DISABLE_AUTO_MIGRATE_TO_NATIVE=1
```

**Why:** Claude Code's sandbox hardcodes `/tmp/claude-{uid}`, but Android's `/tmp` is owned by `shell:shell` (mode 0771), not writable by the Termux user. The native-binary migration also fails — ELF binaries are incompatible with Android's linker.

`~/.claude/CLAUDE.md` is configured for the session-notes workflow (points to GitHub raw docs: `https://raw.githubusercontent.com/jaded423/scripts/master/.claude/docs/`).

## Termux / Android quirks

- **Ctrl+Space** intercepted by Android for input-method switching — hence Ctrl+A tmux prefix
- **gitstatusd** (p10k's git daemon) incompatible with Termux/bionic libc — disabled via `POWERLEVEL9K_DISABLE_GITSTATUS=true` in `~/.p10k.zsh` (falls back to `git status`, slightly slower)
- **sshd** on port 8022, not 22 (standard Termux limitation)
- **zsh** must be installed separately: `pkg install zsh`
- **sesh** is v1 dev build (not v2) — some v2 flags unavailable (no `--hide-duplicates`, no `sesh preview`)

## Key config files

| File | Purpose |
|------|---------|
| `~/.zshrc` | Adapted from Mac template (no platform-specific bits) |
| `~/.zsh/functions/*.zsh` | fzf config, SSH functions |
| `~/.config/tmux/tmux.conf` | catppuccin, sesh binding, vim-tmux-navigator |
| `~/.config/tmux/sesh.sh` | fzf session picker |
| `~/.config/sesh/sesh.toml` | sesh config |
| `~/.config/sesh/scripts/default.sh` | Default session layout (Main/Claude/Neo) |
| `~/bin/start-tunnel.sh` | Reverse tunnel to book5 |
| `~/bin/keep-sshd.sh` | sshd watchdog (restarts if OOM-killed) |
| `~/.termux/boot/start-services` | Boot auto-start (sshd + watchdog only) |
| `~/.claude/CLAUDE.md` | Claude Code session-notes config |

## Sources

- `~/.claude/docs/homelab/tablet.md`
- `~/projects/homeLab/CLAUDE.md` — Operational Current State (S9 FE row, Roaming Devices)
