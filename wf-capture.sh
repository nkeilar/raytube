#!/bin/bash
# wf-capture.sh <width> <height> <fps> <kbps> -- H.264 Annex-B on stdout from
# the patched wf-recorder (zero-copy screencopy, Intel VA-API encode). Used as
# omacast's video_command. RAYTUBE_OUTPUT names the monitor to capture (e.g.
# the virtual TV desktop); unset captures the laptop screen.
set -u
W=$1 H=$2 FPS=$3 KBPS=$4
DIR="$(dirname "$(readlink -f "$0")")"
. "$DIR/lib/raytube-env.sh"   # GPU settings, WF_RECORDER_BIN
OUTPUT_ARGS=()
[ -n "${RAYTUBE_OUTPUT:-}" ] && OUTPUT_ARGS=(-o "$RAYTUBE_OUTPUT")
# Fit and pad on the GPU (pad in RGB, then NV12, or the bars come out green).
# The TV desktop is created at exactly the cast size, so there both passes are
# full-frame copies that do nothing: convert only.
FILTER="scale_vaapi=w=$W:h=$H:force_original_aspect_ratio=decrease:force_divisible_by=2,pad_vaapi=w=$W:h=$H:x=-1:y=-1:color=black,scale_vaapi=format=nv12"
if [ -n "${RAYTUBE_OUTPUT:-}" ] && [ "$(cat "$HOME/.local/state/raytube/tv-size" 2>/dev/null)" = "${W}x${H}" ]; then
	FILTER="scale_vaapi=format=nv12"
fi

export WF_MAX_FAILURES=60
exec "$WF_RECORDER_BIN" "${OUTPUT_ARGS[@]}" \
	-c h264_vaapi -d "$RAYTUBE_RENDER_NODE" \
	-F "$FILTER" \
	-B "$FPS" -D \
	-p rc_mode=VBR -p b="${KBPS}k" -p maxrate="${KBPS}k" -p g=15 -p bf=0 \
	-p aud=1 -p async_depth=1 \
	-m h264 -f pipe:1
