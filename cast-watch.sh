#!/bin/bash
# cast-watch.sh -- watch the cast for trouble and fix what it can.
#  * Logs every cast error / audio stall from the journal with what the machine
#    was doing at that moment.
#  * Every 5 s reads PipeWire's xrun counter for the cast's audio capture
#    (gst-launch pulsesrc). More than 2 new glitches in 30 s: raise the audio
#    cycle 1024 -> 2048 samples and notify.
#  * After a glitch burst or an audio-only capture restart, the Apple TV stays
#    out of sync (it never catches up by itself), so once things have been calm
#    for 10 s, re-sync (restart the cast session) - at most every 5 minutes.
# Output: ~/.local/state/raytube/cast-watch.log
LOG=${CAST_WATCH_LOG:-$HOME/.local/state/raytube/cast-watch.log}
context() {
	local h a b
	h=$(pgrep -x Hyprland)
	a=$(awk '{print $14+$15}' /proc/$h/stat 2>/dev/null); sleep 1; b=$(awk '{print $14+$15}' /proc/$h/stat 2>/dev/null)
	printf 'cpu=%s hyprland=%s%% load=%s top=%s sink=%s' \
		"$(sensors 2>/dev/null | awk '/Package id 0/ {print $4; exit}')" "$((b - a))" \
		"$(cut -d' ' -f1 /proc/loadavg)" \
		"$(ps -eo pcpu,comm --sort=-pcpu | sed -n '2,4p' | awk '{printf "%s:%s%% ", $2, $1}')" \
		"$(pactl get-default-sink 2>/dev/null)"
}
echo "$(date +%T) watch started" >> "$LOG"

journalctl --user -f -n0 -o short-iso -u raytube-cast -u raytube-rotation 2>/dev/null |
	grep --line-buffered -iE "error|stuck|restart|fatal|abort|throttle|stopp|exit|panic|failed" |
	while read -r line; do
		echo "$(date +%T) ${line#* } | $(context)" >> "$LOG"
	done &

# Audio glitch watch: xrun counter (ERR column) of the cast's capture stream.
capture_errors() {
	timeout 3 pw-top -b -n 2 2>/dev/null | awk '/gst-launch/ {e=$9} END {print e+0}'
}
last=$(capture_errors); window=()
resync_pending=0; calm=0; last_resync=0; checked=$(date +%s)
while sleep 5; do
	systemctl --user is-active --quiet raytube-cast || { last=0; window=(); continue; }
	now=$(capture_errors)
	(( now < last )) && last=0   # capture restarted: counter reset
	new=$(( now - last )); last=$now
	window=("${window[@]: -5}" "$new")   # last 30 s
	total=0; for n in "${window[@]}"; do total=$(( total + n )); done
	if (( new > 0 )); then echo "$(date +%T) audio glitch x$new (30 s: $total) | $(context)" >> "$LOG"; fi
	# A stuck-audio restart inside doubletake also leaves the TV out of sync.
	if journalctl --user -u raytube-cast --since "@$checked" --no-pager -o cat 2>/dev/null | grep -q "restarting audio capture only"; then
		resync_pending=1
	fi
	checked=$(date +%s)
	(( total > 2 )) && resync_pending=1
	if (( new > 0 )); then calm=0; else calm=$(( calm + 5 )); fi
	if (( resync_pending && calm >= 10 && $(date +%s) - last_resync >= 300 )); then
		echo "$(date +%T) re-syncing the TV after audio trouble" >> "$LOG"
		"$(dirname "$(readlink -f "$0")")/raytube-cast" resync >> "$LOG" 2>&1
		last_resync=$(date +%s); resync_pending=0; window=(); last=0
		sleep 15
		continue
	fi
	q=$(pw-metadata -n settings 0 clock.force-quantum 2>/dev/null | grep -oE "value:'[0-9]+'" | grep -oE "[0-9]+")
	if (( total > 2 )) && [ "${q:-0}" -lt 2048 ]; then
		pw-metadata -n settings 0 clock.force-quantum 2048 >/dev/null
		echo "$(date +%T) audio glitching ($total in 30 s): audio cycle raised to 2048 samples" >> "$LOG"
		notify-send -t 4000 "Casting" "Sound was glitching; switched to a safer audio buffer."
		window=()
	fi
done
