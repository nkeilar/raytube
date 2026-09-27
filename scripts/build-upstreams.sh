#!/bin/bash
# build-upstreams.sh -- build the patched programs fetched by fetch-upstreams.sh
# and put them in build/bin/, where the raytube launchers look first.
# Builds run at low priority on two cores so a laptop doesn't overheat.
# Needs: go, meson, ninja, cargo (Arch: go meson ninja rust, plus the
# wf-recorder deps: ffmpeg wayland wayland-protocols libpulse mesa).
set -euo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
SRC="$ROOT/build/src" BIN="$ROOT/build/bin"
mkdir -p "$BIN"
low() { nice -n 19 "$@"; }

( cd "$SRC/doubletake"
  GOMAXPROCS=2 low go build -p 2 -o "$BIN/doubletake" ./cmd/doubletake
  GOMAXPROCS=2 low go build -p 2 -o "$BIN/doubletake-test-receiver" ./cmd/doubletake-test-receiver )
echo "built doubletake"

( cd "$SRC/wf-recorder"
  [ -d build ] || low meson setup build --buildtype=release >/dev/null
  low ninja -j2 -C build >/dev/null
  install -m755 build/wf-recorder "$BIN/wf-recorder" )
echo "built wf-recorder"

( cd "$SRC/omacast"
  low cargo build --release --locked -j 2 --quiet
  install -m755 target/release/omacast target/release/omacastd "$BIN/" )
echo "built omacast"
ls -1 "$BIN"
