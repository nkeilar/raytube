#!/bin/bash
# uninstall.sh -- undo install.sh for the current user.
#
#   ./uninstall.sh [--dry-run] [--purge]
#
#   --purge   also delete raytube's settings and state (~/.config/raytube,
#             ~/.local/state/raytube) and the build/ folder. AirPlay pairings
#             (~/.config/doubletake) and ~/.config/omacast are never touched.
#
# Root-owned steps you ran yourself (tmpfiles rule, group, firewall rule) are
# listed at the end for you to undo.
set -uo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
DRY=0 PURGE=0
for a in "$@"; do
	case "$a" in --dry-run) DRY=1 ;; --purge) PURGE=1 ;; *) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;; esac
done
do_() { local what=$1; shift; if (( DRY )); then echo "  would: $what"; else echo "  $what"; "$@"; fi; }

do_ "stop any cast" "$ROOT/raytube-cast" stop
for u in raytube-watch raytube-syncwatch raytube-rotation; do
	systemctl --user is-active --quiet "$u" && do_ "stop $u" systemctl --user stop "$u"
done
for t in raytube-cast raytube-tv; do
	[ "$(readlink "$HOME/.local/bin/$t")" = "$ROOT/$t" ] && do_ "remove ~/.local/bin/$t" rm "$HOME/.local/bin/$t"
done
[ "$(readlink "$HOME/.config/hypr/raytube.lua")" = "$ROOT/config/hypr/raytube.lua" ] &&
	do_ "remove ~/.config/hypr/raytube.lua" rm "$HOME/.config/hypr/raytube.lua"
HYPR="$HOME/.config/hypr/hyprland.lua"
if grep -q 'require("hypr.raytube")' "$HYPR" 2>/dev/null; then
	do_ "remove the raytube lines from hyprland.lua (backup: hyprland.lua.bak.uninstall)" \
		sh -c "cp '$HYPR' '$HYPR.bak.uninstall' && sed -i '/-- raytube: TV desktop keys and monitor rule/d; /require(\"hypr.raytube\")/d' '$HYPR'"
fi
omarchy plugin list 2>/dev/null | grep -q '^nathank.raytube ' && do_ "remove the Cast menu plugin" omarchy plugin remove nathank.raytube --yes
if (( PURGE )); then
	do_ "delete ~/.config/raytube and ~/.local/state/raytube" rm -rf "$HOME/.config/raytube" "$HOME/.local/state/raytube"
	do_ "delete build/" rm -rf "$ROOT/build"
fi
cat <<STEPS
If you ran the root steps from install.sh, undo them with:
    sudo rm /etc/tmpfiles.d/raytube-hw.conf && sudo gpasswd -d "\$USER" raytube
    sudo ufw delete allow from <apple-tv-ip> to any port 319,320 proto udp
Then reload Hyprland (hyprctl reload).
STEPS
