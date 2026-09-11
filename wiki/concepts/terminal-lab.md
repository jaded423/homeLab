---
type: concept
title: Terminal lab — TERM, terminfo, ncurses and escape sequences (career practice)
tags: [terminal, terminfo, ncurses, tput, escape-sequences, ghostty, tmux, console, bash, lab, study]
related: [network-lab, s10]
---

# Terminal lab — the layer between a program and the pixels

**Why (2026-09-11):** on pi-gw1, `clear` from a Ghostty session failed with `'xterm-ghostty': unknown terminal type`.
Chasing it exposed a whole layer Joshua had half-seen in Dave Eddy's YSAP bash course (raw escape sequences drawing
TUIs) but never had a map of. This page is the map plus a set of exercises in the [[network-lab]] shape:
**setup → measure → break → observe → restore → lesson.** Nothing here can hurt anything but the one terminal
window you run it in, so every exercise is tier 0: do it on the Pi, the Mac, or a VM, any time.

## The stack in one paragraph

A **terminal emulator** (Ghostty, Alacritty, the Pi's HDMI console, tmux from the inside) turns bytes into pixels
and keys into bytes. Some byte strings are **escape sequences** — `ESC [ 5 ; 10 H` means "cursor to row 5 col 10",
`ESC [ 3 2 m` means "green" — and every emulator speaks a slightly different dialect. **terminfo** is the database
on the *remote* host, one entry per terminal type, that says which bytes mean what for the terminal named in
`$TERM`; `tic` compiles an entry, `infocmp` decompiles one, `tput` asks it a question from the shell. **ncurses** is
the library full-screen programs (vim, htop, less, lazygit) use instead of hand-writing bytes: they say "bold text
at row 3" and ncurses consults terminfo for the current `$TERM`. So: *program → ncurses → terminfo (keyed by TERM)
→ bytes over ssh → emulator → pixels.* Raw sequences skip the middle and bet the terminal is xterm-like (it almost
always is); terminfo pays a dependency (the host must have the entry) to fail loudly instead of quietly when it
isn't. That trade is the whole lesson.

## Instruments

- `echo $TERM` · `infocmp -x` (the entry, decompiled) · `tput <cap> [args]` (ask for one capability; exit code ≠ 0
  = the terminal can't) · `tput colors` / `tput lines` / `tput cols`.
- `cat -v` then press keys (input direction: what bytes your arrows/F-keys send) · `stty -a` (line discipline).
- `reset` and `stty sane` — the two ways out of a terminal a program left broken.
- `script -q /dev/null` fakes a tty for a pipeline; `[ -t 1 ]` tests "is stdout a terminal".
- Man pages, in reading order: `man 5 terminfo` (the format + every capability name) → `man 1 tput` → `man 1 tic` /
  `man 1 infocmp` → `man 4 console_codes` (the Linux console's dialect, ≈ xterm's) → `man 3 ncurses`.
  Off-box: xterm's *ctlseqs* document is the canonical dialect reference.

## Exercises

| # | Exercise | Break it | Expect / learn |
|---|---|---|---|
| 1 | **What TERM buys you.** `echo $TERM`; `infocmp -x \| head -40`; `tput colors`. Run `htop`. | `TERM=vt100 htop`, then `TERM=dumb htop`, then `TERM=nonsense clear`. | Colors and box-drawing degrade in steps; `dumb` refuses full-screen; a bogus name fails outright. The *program* didn't change — its dictionary did. |
| 2 | **Reproduce the pi-gw1 fault.** On a host without the entry (pi-gw2's first flash, before the card carries it): ssh in from Ghostty, run `clear`. | — it is already broken. | `unknown terminal type`. Fix A (host): `infocmp -x xterm-ghostty \| ssh host 'tic -x -'` (lands in `~/.terminfo`; add `-o /usr/share/terminfo` with sudo for everyone). Fix B (client): `SetEnv TERM=xterm-256color` in `~/.ssh/config` — lie about who you are, lose Ghostty-specific caps. The card bakes fix A (`fleet/gateway/xterm-ghostty.terminfo`); Joshua's SOP is "Ghostty on every accessing machine, so one extra type is all a card must know". |
| 3 | **Raw vs polite.** Draw the same thing twice: `echo -e "\e[5;10Hhello"` and `tput cup 4 9; echo hello`. | Run both under `TERM=dumb`. | Raw still emits the bytes (an xterm shows it; a log file shows `^[[5;10H`); `tput` prints nothing and exits 1, so a script can branch. Raw = self-contained but assumes; terminfo = adapts but needs the database. |
| 4 | **Colors, three tiers.** `for i in $(seq 0 255); do tput setaf $i; printf '%3d ' $i; done; tput sgr0`. Then `printf '\e[38;2;255;100;0mtruecolor\e[0m\n'`; `echo $COLORTERM`. | `TERM=xterm` (8/16 colors) and rerun. | 16 → 256 → 24-bit are different capabilities; `COLORTERM=truecolor` is the emulator's side-channel promise, not in terminfo at all. Explains "my theme looks wrong over ssh". |
| 5 | **Keys are sequences too.** `cat -v`, then press ←, Home, F5, Ctrl-arrows; `showkey -a` on the Pi console. | Compare under `TERM=vt100` inside `cat -v` (nothing changes) vs inside `vim` (bindings break). | Input bytes are fixed by the *emulator*; what a program *expects* comes from terminfo (`kcub1`, `khome`, `kf5`). Wrong TERM ⇒ vim/tmux "ignore" keys. |
| 6 | **A multiplexer in the middle.** Inside `tmux`: `echo $TERM` (`tmux-256color`/`screen-256color`). | Start tmux with an outer `TERM=xterm` (no 256 colors), or inner `TERM=xterm-ghostty`. | tmux is its own emulator: the outer TERM is for tmux's output, the inner TERM is for programs talking to tmux. Two dictionaries, two failure modes (colors lost outward, italics/keys lost inward). |
| 7 | **Size is negotiated.** `stty size`; `tput lines`; resize the window; `htop` follows. | On a serial console (Pi UART, or `screen /dev/tty.usb…`) size is unknown ⇒ `stty rows 24 cols 80` by hand; run `resize` where available. | Window size travels as `SIGWINCH` + `TIOCGWINSZ`, not as bytes in the stream — so over a wire that carries only bytes, nobody tells the far side. |
| 8 | **The console is an emulator too.** Pi on HDMI: `echo $TERM` → `linux`; `man 4 console_codes`; `setterm --blank 0`; `setterm -cursor off`. | `printf '\e[?25l'` (hide cursor), then `reset`. | Same escape language, kernel-side implementation. This is the layer pi1's 3.5" TFT lives in (`setterm` silencing fbcon before drawing pixels — see the pi1 memory notes). |
| 9 | **A tiny TUI, YSAP-style.** `tput smcup; tput civis; trap 'tput cnorm; tput rmcup' EXIT`; draw a box with `cup`; read keys with `read -rsn1`. | `kill -9` it from another window. | Alt-screen never restored, cursor gone: the terminal is "broken" ⇒ `reset` / `stty sane`. Why every TUI installs an EXIT trap, and why `reset` exists. |
| 10 | **A pipe is not a terminal.** `ls --color=auto` vs `ls --color=auto \| cat`; `[ -t 1 ] && echo tty \|\| echo pipe`. | `script -q -c 'ls --color=auto' /dev/null \| cat`. | Well-behaved programs check `isatty` and drop sequences when piped; `script` fakes a tty and the sequences come back — the reason CI logs fill with `^[[0m`. |

## Sources

- `man 5 terminfo`, `man 1 tput`, `man 1 tic`, `man 1 infocmp`, `man 4 console_codes`, `man 3 ncurses` (all on the Pi).
- xterm control sequences ("ctlseqs") — the dialect nearly everything imitates.
- Dave Eddy, *You Suck at Programming* — the bash course whose TUI segments use the raw-sequence side of this.
- Origin fault + fix: piGate `TODO.md` card-QoL item and `fleet/gateway/xterm-ghostty.terminfo` (2026-09-11).
