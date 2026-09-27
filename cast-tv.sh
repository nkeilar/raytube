#!/bin/bash
# Cast to the Office TV (AirPlay): Intel Quick Sync encode, under the thermal
# guard. CANVAS is the size sent; raytube-cast sets it per TV (default 1080p).
# Larger than the TV handles (e.g. 2560x1440 or 3200x1800) makes the Apple TV
# hold the picture ~0.9 s behind the sound.
cd "$(dirname "$(readlink -f "$0")")"
. lib/raytube-env.sh   # GPU settings and the patched binaries
: "${TARGET:?set TARGET to the Apple TV IP address (raytube-cast does this)}"
export DOUBLETAKE_CANVAS=${CANVAS:-1920x1080}
export DOUBLETAKE_VAAPI_DEVICE=${DOUBLETAKE_VAAPI_DEVICE:-$RAYTUBE_RENDER_NODE}
# Zero-copy capture: Hyprland screencopy into an Intel-owned DMA-BUF, VA-API
# convert/pad/encode on Intel. Bypasses portal + PipeWire.
# Set WF_RECORDER= (empty) to fall back to the portal/GStreamer path below.
export DOUBLETAKE_WF_RECORDER=${WF_RECORDER-$WF_RECORDER_BIN}
# -D: send every compositor frame (capped at -fps), not damage-only. The Apple
# TV shows a frame only once a newer one arrives; with damage-only frames a
# static moment held the last change on screen for seconds (1.6 s -> 0.67 s).
export DOUBLETAKE_WF_ARGS=${WF_ARGS--D}
export DOUBLETAKE_PW_PROPS=${PW_PROPS-min-buffers=8}   # needed: without it xdph 1.4.1 wedges at once
export DOUBLETAKE_NO_COMPOSITOR=${NO_COMPOSITOR-1}    # forced-live compositor repeats stale frames
export DOUBLETAKE_PULSE_PROPS=${PULSE_PROPS-buffer-time=60000 latency-time=20000}  # 20 ms chunks: fresh audio without forcing a 5 ms PipeWire quantum (xrun crackle)
# Play audio later to match video stamped after capture+encode (tune with av-sync-test.html).
export DOUBLETAKE_AUDIO_DELAY_MS=${AUDIO_DELAY_MS-0}
export DOUBLETAKE_AUDIO_DELAY_FILE=${AUDIO_DELAY_FILE-}  # re-read live, so the delay can be tuned while casting
# Tolerate short screencopy refusals (window/fullscreen transitions); a real
# display change (resolution/scale) still fails, and the loop below restarts.
export WF_MAX_FAILURES=${WF_MAX_FAILURES:-60}

# Restart after a capture/stream error (exit 1), e.g. when the display mode or
# scale changes. A thermal abort, Ctrl+C, or clean exit ends the loop.
trap 'exit 130' INT TERM
while :; do
	./cast-guard.sh "$DOUBLETAKE_BIN" \
		-target "$TARGET" -hwaccel intel -fps ${FPS:-30} -bitrate ${BITRATE:-20000} -target-latency-ms ${LATENCY_MS:-110} "$@"
	rc=$?
	[ $rc -eq 1 ] || exit $rc
	grep -q "ABORT" <(tail -3 "${CAST_GUARD_LOG:-$HOME/.local/state/raytube/thermal.log}") && exit $rc
	echo "cast-tv: stream error, restarting in 3 s (Ctrl+C to stop)" >&2
	sleep 3
done
