#!/bin/zsh
# netwatch — one probe cycle: first hop (default gateway) + WAN (1.1.1.1).
# Fired every 30s by ~/Library/LaunchAgents/com.j.netwatch.plist.
#
# Why both hops: loss at the gateway AND the WAN = local (router/Wi-Fi link).
# Loss at the WAN only = upstream (ISP). That split is the whole point of the log.
#
# Gateway + interface are auto-detected each cycle, so a router swap (or a move
# from Wi-Fi to the dock's ethernet) is recorded rather than breaking the probe.
#
# Log: ~/.local/state/netwatch/netwatch.tsv  (NOT in this repo — it's public)
# Columns: iso8601  iface  gateway_ip  gw_rtt_ms  wan_rtt_ms   ("LOSS" / "-" on failure)

set -u

WAN_TARGET="1.1.1.1"
LOG_DIR="$HOME/.local/state/netwatch"
LOG="$LOG_DIR/netwatch.tsv"
MAX_BYTES=$((5 * 1024 * 1024))   # rotate at 5MB, keep 4 generations (~20MB ceiling)
KEEP=4

mkdir -p "$LOG_DIR"

# --- rotate before writing ---
if [[ -f "$LOG" ]]; then
  size=$(stat -f%z "$LOG" 2>/dev/null || echo 0)
  if (( size > MAX_BYTES )); then
    for ((i = KEEP - 1; i >= 1; i--)); do
      [[ -f "$LOG.$i" ]] && mv -f "$LOG.$i" "$LOG.$((i + 1))"
    done
    mv -f "$LOG" "$LOG.1"
  fi
fi

# --- probe ---
# avg RTT in ms, or LOSS. -W is per-packet wait (ms on macOS), -t is overall cap (s).
probe() {
  local target="$1"
  local out
  out=$(ping -c 1 -W 2000 -t 3 "$target" 2>/dev/null) || { print -- "LOSS"; return }
  print -- "${${out##*time=}%% ms*}"
}

ts=$(date +%Y-%m-%dT%H:%M:%S%z)

route_out=$(route -n get default 2>/dev/null)
gw=${${route_out##*gateway: }%%$'\n'*}
iface=${${route_out##*interface: }%%$'\n'*}

# No default route at all — asleep, or genuinely offline. Record it and stop.
if [[ -z "$gw" || "$gw" == "$route_out" ]]; then
  print -- "$ts\t-\t-\tNOROUTE\tNOROUTE" >> "$LOG"
  exit 0
fi

gw_rtt=$(probe "$gw")
wan_rtt=$(probe "$WAN_TARGET")

print -- "$ts\t$iface\t$gw\t$gw_rtt\t$wan_rtt" >> "$LOG"
