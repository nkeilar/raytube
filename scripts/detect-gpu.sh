#!/bin/bash
# detect-gpu.sh -- find the GPUs raytube needs and write ~/.config/raytube/gpu.env.
#
#   RAYTUBE_RENDER_NODE   the Intel (i915/xe) render node used to encode H.264
#   WF_FORCE_DMABUF       1 when the encode GPU is not the one that draws the screen
#                         (zero-copy capture across GPUs)
#   WF_IMPLICIT_MODIFIER  1 when the screen is drawn by an AMD GCN 1.0 (Southern
#                         Islands) GPU, which only lists implicit modifiers; an
#                         explicit LINEAR buffer gave black frames there
#
# Run by install.sh; re-run after changing GPUs. Prints the result.
set -u
OUT=${RAYTUBE_GPU_ENV:-$HOME/.config/raytube/gpu.env}

driver() { basename "$(readlink -f "$1/device/driver" 2>/dev/null)" 2>/dev/null; }

render=""
for r in /sys/class/drm/renderD*; do
	case "$(driver "$r")" in i915|xe) render=/dev/dri/$(basename "$r"); break ;; esac
done
[ -n "$render" ] || { echo "detect-gpu: no Intel render node found; raytube needs Intel VA-API H.264 encode" >&2; exit 1; }

# The display GPU: the card with a connected built-in panel, else any connected output.
display=""
for c in /sys/class/drm/card[0-9]*-eDP-* /sys/class/drm/card[0-9]*-*; do
	[ "$(cat "$c/status" 2>/dev/null)" = connected ] || continue
	display=${c%%-*}; break
done
display_driver=$(driver "$display")
render_card=$(basename "$(readlink -f /sys/class/drm/$(basename "$render")/device)")
display_dev=$(basename "$(readlink -f "$display/device" 2>/dev/null)")

force_dmabuf=0
[ -n "$display_dev" ] && [ "$display_dev" != "$render_card" ] && force_dmabuf=1

implicit=0
if [ "$display_driver" = amdgpu ] || [ "$display_driver" = radeon ]; then
	id=$(( $(cat "$display/device/device") ))
	# Southern Islands: Oland 0x6600-0x663f, Hainan 0x6660-0x666f, Tahiti
	# 0x6780-0x679f, Pitcairn / Cape Verde 0x6800-0x683f.
	if (( (id >= 0x6600 && id <= 0x663f) || (id >= 0x6660 && id <= 0x666f) ||
	      (id >= 0x6780 && id <= 0x679f) || (id >= 0x6800 && id <= 0x683f) )); then
		implicit=1
	fi
fi

mkdir -p "$(dirname "$OUT")"
cat > "$OUT" <<ENV
# Written by raytube scripts/detect-gpu.sh on $(date +%F)
RAYTUBE_RENDER_NODE=$render
WF_FORCE_DMABUF=$force_dmabuf
WF_IMPLICIT_MODIFIER=$implicit
ENV
echo "encode: $render ($(driver /sys/class/drm/$(basename "$render"))) · display: $(basename "$display") ($display_driver) · cross-GPU: $force_dmabuf · implicit modifier: $implicit"
