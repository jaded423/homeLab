# Go (Pixelbook Go) — TODO

Device-specific tasks for the Pixelbook Go ("atlas") running CachyOS rolling (`7.1.2-cachyos`, LTS `6.18.x-cachyos-lts` fallback). Hardware: Intel Wireless-AC 9560 wifi, AVS audio (MAX98373 amp + DA7219 codec), intel_backlight. SSH: `ssh go` (Tailscale) / `ssh go-local`.

## Open

- [ ] **Built-in speakers silent — AVS topology missing (LOW, not blocking).** `snd_soc_avs 0000:00:1f.3: request topology "intel/avs/hda-8086280b-tplg.bin" failed: -2` (file not found). **Confirmed 2026-06-29: BT audio works fine; only internal speakers dead.** atlas moved to Intel `snd_soc_avs` driver; needs the AVS topology firmware blob, or force legacy `snd_hda_intel`. Fix path: install topology files (`sof-firmware`/`alsa-ucm-conf` + AVS tplg) or blacklist avs → snd_hda_intel fallback. **Not a deal-breaker for rolling — BT headphones cover it.** Chase only if internal speakers wanted.
- [ ] **Orphan packages (LOW/tidy).** `ffmpeg4.4`, `lib32-libcap`, `libliftoff`. Optional cleanup: `sudo pacman -Rns $(pacman -Qdtq)` — review list first.

## Watch / notes

- Rolling `7.1.2` wifi confirmed working (2026-06-29). Earlier "disconnected" was Twingate `sdwan0` DNS hijack + unconnected Elevated profile, fixed on LTS, carried to rolling (NM profiles in `/etc` = kernel-independent). NOT an iwlwifi regression.
- Twingate disabled on Go (was crash-looping `twingated` SIGSEGV, 6/28–6/29). Access via Tailscale + ssh/scp/rclone only. Don't re-enable unless media access needed.
- Diag baseline 2026-06-29: 0 failed units, no reboot pending, disk 14%, battery design-capacity 99.8%, no suspend/resume errors. Healthy otherwise.

## Done

- [x] **Bluetooth working (2026-06-29).** blueman-manager GUI; bone-conductor headphones + Kinesis Adv360 both connect. The `hci0` config-warning log line is cosmetic.
