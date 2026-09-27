# raytube

Cast your Omarchy (Arch + Hyprland) desktop to an Apple TV or a Chromecast with very little CPU:
the screen is captured and encoded on the GPU, and a thermal guard keeps laptops cool and quiet.
Built and tested on a 2015 MacBook Pro (Intel Iris Pro + AMD R9 M370X).

| Receiver | Protocol | Sender |
|---|---|---|
| Apple TV (tested: Apple TV 4K, tvOS 26) | AirPlay 2 screen mirroring | patched [doubletake](https://github.com/omarroth/doubletake) |
| Chromecast (tested: Chromecast with Google TV HD) | Cast Streaming | patched [omacast](https://github.com/Aphrodine-wq/omacast) |

Two things can be cast:

- **Screen**: the laptop screen, mirrored.
- **TV desktop**: a hidden second monitor (centred above the laptop) that only the TV sees. Send
  windows to it, flip between scenes (Main, Family board, Watch), arrange them full / split /
  picture-in-picture, or let it rotate. Its sound goes only to the TV.

## Install

Requirements: Omarchy 4 (Hyprland with the Lua config), an **Intel GPU** for H.264 encoding
(VA-API), and PipeWire. AMD- or NVIDIA-only machines are not supported yet.

```bash
git clone https://github.com/<owner>/raytube && cd raytube
./install.sh --dry-run        # see what it will do
./install.sh --write-hypr     # build the patched senders, link the tools, load the keys
omarchy plugin add https://github.com/<owner>/omarchy-raytube --enable   # the Cast menu
```

`install.sh` never needs root; it prints the optional root steps (fan and turbo control for the
thermal guard, the AirPlay firewall rule). `./uninstall.sh` undoes it.

## Using it

Everything is in the **Display** menu in the top bar (the cast icon shows while casting):

- **CAST**: Screen | TV desktop, then click a TV to start or stop.
- While casting to the Apple TV: **Sound sync − / +**, picture size **720p | 1080p | 1440p**
  (1080p default; 1440p makes the TV run the picture behind the sound), and **Re-sync TV**.
- **TV DESKTOP**: layouts, rotation, Board / Browser / YouTube ⇄ TV app, and the scene list.

Keys (Command is the key next to the space bar):

| Keys | What happens |
|---|---|
| Command + Ctrl + ↑ | send the window you're looking at to the TV |
| Command + Ctrl + ↓ | bring it back |
| Command + Shift + T | **TV mode**: a cheat sheet appears, then one letter |

TV mode letters: **S** send, **B** back, **N/P** next/previous scene, **L** next layout, **M**
swap main window, **F** video full screen, **R** rotation, **Y** YouTube in the TV's own app,
**O** casting on/off, **A** re-sync sound and picture, **Esc** leave.

From a terminal: `raytube-cast` (list, start, stop, mode, size, av-delay, resync) and
`raytube-tv` (up, down, send, back, scene, layout, board, browser, native, pull). Both print
their commands when run without arguments or read the header of the script.

## What keeps it cheap and quiet

- Zero-copy capture: Hyprland renders on the AMD GPU straight into a buffer that the Intel GPU
  encodes (H.264, VA-API). The AMD encoder crashed the display once; it is never used.
- The Apple TV is sent the size it can keep in sync (1080p); the cast costs ~5% of one core.
- `cast-guard.sh` wraps every cast: a quiet fan curve (~3500 rpm), turbo off while casting, CPU
  cap at 85°C, stop at 92°C.
- `cast-watch.sh` watches for audio glitches, raises the audio buffer, and re-syncs the TV when
  it falls behind (the Apple TV never catches up by itself).

## Where things are

| Path | What |
|---|---|
| `raytube-cast`, `raytube-tv`, `raytube-media.py` | the tools (front door, TV desktop, TV browser / Chromecast apps) |
| `cast-tv.sh`, `cast-chromecast.sh`, `wf-capture.sh` | launchers for each TV and the shared capture |
| `cast-guard.sh`, `cast-watch.sh`, `sync-watch.sh` | heat guard, trouble watcher, timing recorder |
| `config/` | Hyprland keys and TV rule, omacast config, fan/turbo permission rule, examples |
| `install.sh`, `uninstall.sh`, `scripts/` | setup, GPU detection, fetching and building the patched senders |
| `board/` | the family board (three.js, calendar, sample data in `data.js`) |
| `av-sync-test.html`, `latency-test.html`, `cc-selftest.sh` | sync, latency and Chromecast self-tests |
| `patches/` | our changes to doubletake, wf-recorder and omacast (fetched and built by `scripts/`) |
| `WISHLIST.md` | ideas parked for later |

## Documentation

In [`docs/`](docs/):

- [System/project_architecture.md](docs/architecture.md): components, config and state
- [System/cast-pipeline.md](docs/cast-pipeline.md): capture, encode, AirPlay and Cast, sync, audio
- [System/tv-desktop.md](docs/tv-desktop.md): the TV desktop, scenes, keys, Display menu
- [System/hardware-and-platform.md](docs/hardware-and-platform.md): GPUs, thermals, fans, suspend
- [System/configuration-reference.md](docs/configuration-reference.md): every setting and state file
- [SOP/casting-operations.md](docs/operating-and-debugging.md): everyday use, sync and glitch checks, tests
- [SOP/rebuilding-patched-deps.md](docs/rebuilding-patched-senders.md): rebuilding the patched programs

## Licence

MIT (see [LICENSE](LICENSE)). The doubletake patch is LGPL-3.0-or-later like doubletake itself;
see [NOTICE](NOTICE) for all third-party code.
