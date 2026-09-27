#!/bin/bash
# install.sh -- set raytube up for the current user on Omarchy (Hyprland, Lua config).
#
#   ./install.sh [--dry-run] [--write-hypr] [--no-build]
#
#   --dry-run     show every action, change nothing
#   --write-hypr  add require("hypr.raytube") to ~/.config/hypr/hyprland.lua
#                 (backed up first); otherwise the line is printed for you to add
#   --no-build    skip fetching and building the patched senders
#
# Needs no root. Steps that do (fan/turbo permission, firewall) are printed at
# the end. Every change is recorded in ~/.local/state/raytube/install.log so
# ./uninstall.sh can undo it.
set -euo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
DRY=0 WRITE_HYPR=0 BUILD=1
for a in "$@"; do
	case "$a" in
		--dry-run) DRY=1 ;; --write-hypr) WRITE_HYPR=1 ;; --no-build) BUILD=0 ;;
		*) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
	esac
done
STATE="$HOME/.local/state/raytube"; LOG="$STATE/install.log"
say() { printf '\033[1m%s\033[0m\n' "$*"; }
do_() { # do_ <description> <command...>: run, or just show in --dry-run
	local what=$1; shift
	if (( DRY )); then echo "  would: $what"; else echo "  $what"; "$@"; echo "$what" >> "$LOG"; fi
}
(( DRY )) || mkdir -p "$STATE"

say "1. Checking what's installed"
missing=()
need() { command -v "$1" >/dev/null || missing+=("$1 ($2)"); }
need hyprctl hyprland; need git git; need python3 python; need uv uv
need pactl libpulse; need pw-metadata pipewire; need avahi-browse avahi
need gst-launch-1.0 "gstreamer gst-plugins-good gst-plugins-bad"; need ffmpeg ffmpeg
need notify-send libnotify; need vainfo libva-utils
if (( BUILD )); then need go go; need meson meson; need ninja ninja; need cargo rust; fi
command -v chromium >/dev/null || echo "  (optional) chromium: needed for the family board"
if (( ${#missing[@]} )); then
	echo "  missing: ${missing[*]}"
	echo "  install with: omarchy pkg add <package>   (package names in brackets)"
	exit 1
fi
echo "  all required tools found"

say "2. Finding the GPUs"
if (( DRY )); then echo "  would: run scripts/detect-gpu.sh"; else "$ROOT/scripts/detect-gpu.sh"; fi

if (( BUILD )); then
	say "3. Fetching and building the patched senders (a few minutes, low priority)"
	do_ "fetch upstreams at pinned commits and apply patches" "$ROOT/scripts/fetch-upstreams.sh"
	do_ "build doubletake, wf-recorder, omacast into build/bin" "$ROOT/scripts/build-upstreams.sh"
else
	say "3. Skipping the build (--no-build)"
fi

say "4. Linking the tools and config"
mkdir -p "$HOME/.local/bin" "$HOME/.config/hypr" 2>/dev/null || true
for t in raytube-cast raytube-tv; do
	do_ "link ~/.local/bin/$t" ln -sfn "$ROOT/$t" "$HOME/.local/bin/$t"
done
do_ "link ~/.config/hypr/raytube.lua" ln -sfn "$ROOT/config/hypr/raytube.lua" "$HOME/.config/hypr/raytube.lua"
HYPR="$HOME/.config/hypr/hyprland.lua"
if grep -q 'require("hypr.raytube")' "$HYPR" 2>/dev/null; then
	echo "  hyprland.lua already loads raytube"
elif (( WRITE_HYPR )); then
	do_ "back up hyprland.lua to hyprland.lua.bak.raytube" cp "$HYPR" "$HYPR.bak.raytube"
	do_ "add require(\"hypr.raytube\") to hyprland.lua" sh -c "printf '\n-- raytube: TV desktop keys and monitor rule\nrequire(\"hypr.raytube\")\n' >> '$HYPR'"
else
	echo "  add this line at the end of ~/.config/hypr/hyprland.lua (or rerun with --write-hypr):"
	echo '      require("hypr.raytube")'
fi
OMACAST="$HOME/.config/omacast/config.toml"
if [ -f "$OMACAST" ]; then
	echo "  keeping your ~/.config/omacast/config.toml; make sure video_command points at $ROOT/wf-capture.sh"
else
	do_ "write ~/.config/omacast/config.toml" sh -c "mkdir -p '$HOME/.config/omacast' && sed 's|@RAYTUBE_DIR@|$ROOT|' '$ROOT/config/omacast/config.toml.in' > '$OMACAST'"
fi
if [ ! -f "$ROOT/board/data.js" ]; then
	do_ "copy board/data.example.js to board/data.js (edit it for your family)" cp "$ROOT/board/data.example.js" "$ROOT/board/data.js"
fi

say "5. The Cast menu (Omarchy plugin)"
echo "  omarchy plugin add https://github.com/<owner>/omarchy-raytube --enable"
[ -d "$ROOT/../omarchy-raytube/.git" ] && echo "  (local checkout: omarchy plugin add file://$(cd "$ROOT/../omarchy-raytube" && pwd) --enable)"

say "6. Steps that need root (run them yourself)"
cat <<STEPS
  Fans and turbo control while casting (MacBooks / Intel CPUs; optional):
      sudo groupadd -f raytube && sudo usermod -aG raytube "\$USER"
      sudo install -m644 $ROOT/config/tmpfiles/raytube-hw.conf /etc/tmpfiles.d/
      sudo systemd-tmpfiles --create /etc/tmpfiles.d/raytube-hw.conf
      (then log out and in once)
  AirPlay clock sync (Apple TV) if you use ufw:
      sudo ufw allow from <apple-tv-ip> to any port 319,320 proto udp
  Firefox hardware decoding on the Intel GPU (optional):
      see config/firefox/user.js.example and 60-firefox-intel-decode.conf.example
STEPS
say "Done. Open the Cast menu in the top bar, or run: raytube-cast list"
