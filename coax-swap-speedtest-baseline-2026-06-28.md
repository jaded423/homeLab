# Coax Swap Speedtest — BEFORE (baseline)

**Date**: 2026-06-28 18:04–18:05 CDT
**Context**: Baseline before swapping modem coax to longer run. Modem = Spectrum EJ2251 (rented, locked stats page → no DOCSIS power/SNR, going blind via throughput).
**Method**: Run SEQUENTIAL (one host at a time). Parallel runs contend for the same ~1.4 Gbps WAN and split it — invalid. (First attempt was concurrent + discarded.)

## TOWER (direct, no Mullvad — full NIC) — TRUTH SIGNAL
- Server: x99.cloud - Dallas, TX (id 72163), ISP Spectrum
- Idle latency: **11.00 ms** (jitter 1.82, low 6.57, high 12.31)
- Download: **1571.63 Mbps** (loaded latency 67.65 ms)
- Upload: **328.54 Mbps** (loaded latency 6.57 ms)
- Packet loss: 0.0%
- URL: https://www.speedtest.net/result/c/2e345973-fff8-4067-9bd2-b09c95d72aa7

## BOOK5 (direct, no Mullvad — cross-check, 18:08 CDT)
- Server: AT&T - Dallas, TX (id 69099), ISP Spectrum
- Idle latency: **12.62 ms** (jitter 2.92, low 10.89, high 14.65)
- Download: **1637.22 Mbps** (loaded latency 56.45 ms)
- Upload: **358.62 Mbps** (loaded latency 6.72 ms)
- Packet loss: 0.0%
- URL: https://www.speedtest.net/result/c/04d448d6-1dc3-4b81-bbbc-1282e477ff44
- Note: matches tower (1572/329, 11ms) — confirms baseline. Sunday-evening congestion → ~1500-1650, below the 1800-1900 peak both hosts hit off-peak.

## UBUNTU (VM101, Mullvad single-hop Stockholm — mv-sto default)
- Mullvad: Connected, relay se-sto-wg (lockdown ON, multihop disabled, exit Sweden/Stockholm)
- Server: AltusHost B.V. - Stockholm (id 5235), ISP Datacamp
- Idle latency: **137.69 ms** (Mullvad SE path — expected high)
- Download: **914.19 Mbps** (loaded latency 225.59 ms)
- Upload: **182.72 Mbps** (loaded latency 220.10 ms)
- Packet loss: 0.0%
- URL: https://www.speedtest.net/result/c/68b7b092-a8de-47b3-9add-412eb909110b

## Compare AFTER swap (run sequential, same order)
TOWER cmd:  `ssh tower 'speedtest --accept-license --accept-gdpr'`
UBUNTU cmd: `ssh ubuntu 'speedtest --accept-license --accept-gdpr'`

Watch for:
- **TOWER idle latency** = cleanest line-quality signal (11ms now). Rise or any packet loss → cable/connector problem.
- TOWER download drop >~200 Mbps consistent across reruns → degradation. (Down varies ~150 Mbps run-to-run normally — rerun to confirm before alarm.)
- Upload more stable than download for spotting trend (328 Mbps now).
- Mullvad numbers (ubuntu) vary by relay load — don't over-read. TOWER is truth.

After modem power-cycle: verify Deco DHCP Primary DNS still 192.168.68.248 (pihole) — blanked during 2026-06-19 outage.
