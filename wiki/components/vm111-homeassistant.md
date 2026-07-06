---
type: component
title: VM 111 — Home Assistant
host: ha
ip: 192.168.68.111
tags: [home-assistant, hubspace, frigate, mqtt, tower, vm111, automation]
related: [tower, vm101-ubuntu, watchdogs, access-model]
---

Home Assistant OS running as **VM 111 on [[tower]]** (192.168.68.111). Hub for Hubspace
smart devices, a Frigate integration, MQTT, and the porch-cam watchdog-notify automation.

> NOTE: Renamed from **VM 112 → 111 on 2026-05-27**; IP unchanged (192.168.68.111).

## At a glance

| | |
|---|---|
| VM ID | 111 (on tower) |
| OS | Home Assistant OS |
| IP | 192.168.68.111 |
| SSH | `ssh ha` — ProxyJump [[tower]] (jump rides Tailscale; tower bare alias = TS) |
| Web UI | Twingate only (Mullvad/LAN-only) — see [[access-model]] |
| Bridge | 2.5G `vmbr1` on tower (see below) |

## What it runs

- **Hubspace** — cloud integration for Hubspace smart devices.
- **Frigate integration** — HA talks to Frigate, whose NVR + cameras live on [[vm101-ubuntu]]
  (PetCam `192.168.68.75`, Porch `192.168.68.76`; Frigate/MQTT broker on `192.168.68.101:1883`).
- **MQTT** — event/message bus feeding the Frigate integration + automations.
- **Porch-cam watchdog automation** — see the autoheal notify chain below.

**Token + emergency kit** (HA long-lived token + the HA onboarding emergency kit / recovery
credentials) are stored on **tower + [[vm101-ubuntu]]**.

## autoheal → HA webhook notify chain

VM101's `willfarrell/autoheal` container restarts an unhealthy Frigate, then POSTs its
`WEBHOOK_URL` → HA webhook **`autoheal_frigate_restart`** → automation
**`autoheal_frigate_notify`** → HA persistent notification (so you see *when* it fired).
Full watchdog detail lives in [[watchdogs]]; Frigate itself is on [[vm101-ubuntu]].

## Networking

- VM 111 sits on tower's **2.5G `vmbr1`** (`enp2s0`, r8169), merged there with VM101 during the
  2026-06-19 post-outage cable reroute.
- **GOTCHA**: the runtime fix (`ip link set tapNi0 master vmbr1`) is runtime-only. VM net0
  configs already point at `vmbr1`, but the taps stranded once — **verify tap masters after
  any tower reboot / power event**: `bridge link show | grep tap`.

## Access

- `ssh ha` → ProxyJump [[tower]] (Mullvad lockdown on VM101 is unrelated; `ha` jumps via tower over Tailscale).
- HA **web UI stays on Twingate** (not exposed via Tailscale MagicDNS). Full model → [[access-model]].

## Sources

- `~/projects/homeLab/CLAUDE.md` — Operational Current State (VM 111 summary line; ProxyJump note;
  Web UI note; autoheal→HA notify chain; VM101+VM111 vmbr1 merge)
- `~/.claude/docs/homelab/services.md` — Frigate NVR / MQTT (cameras + broker on VM101)
