#!/bin/bash
# sync-watch.sh -- once a minute, record doubletake's video timing (needs the cast
# running with -debug) so a slow A/V drift can be matched to its cause.
# Output: ~/.local/state/raytube/sync-watch.log
LOG=${SYNC_WATCH_LOG:-$HOME/.local/state/raytube/sync-watch.log}
echo "$(date +%T) sync watch started" >> "$LOG"
while sleep 60; do
	journalctl --user -u raytube-cast --since "-60 sec" --no-pager -o cat 2>/dev/null |
		awk -v t="$(date +%T)" -v sink="$(pactl get-default-sink 2>/dev/null)" '
			/video progress/ {
				n++; f=$0; sub(/.*sent frame /, "", f); sub(/ .*/, "", f); if (!first) first=f; last=f
				a=$0; sub(/.*source age=/, "", a); sub(/ms.*/, "", a); a+=0; sa+=a; if (a>amax) amax=a
				s=$0; sub(/.*slack=/, "", s); sub(/ms.*/, "", s); s+=0; ss+=s; if (!n1++ || s<smin) smin=s
			}
			/stale|stuck|underflow/ { bad++ }
			END {
				if (!n) { printf "%s no video lines (cast off or not -debug)\n", t; exit }
				printf "%s fps=%.1f source_age avg=%.0f max=%.0f ms  slack avg=%.0f min=%.0f ms  audio_problems=%d sink=%s\n",
					t, (last-first)/60, sa/n, amax, ss/n, smin, bad, sink
			}' >> "$LOG"
done
