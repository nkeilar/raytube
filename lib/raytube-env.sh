# raytube-env.sh -- sourced by the launchers. Sets RAYTUBE_DIR, loads the GPU
# settings from scripts/detect-gpu.sh, and finds the patched programs:
# override variable, then the installed build (build/bin), then the
# development clones (project-references/).
RAYTUBE_DIR=${RAYTUBE_DIR:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)}
_gpu_env=${RAYTUBE_GPU_ENV:-$HOME/.config/raytube/gpu.env}
[ -f "$_gpu_env" ] || "$RAYTUBE_DIR/scripts/detect-gpu.sh" >/dev/null 2>&1
# shellcheck disable=SC1090
[ -f "$_gpu_env" ] && . "$_gpu_env"
RAYTUBE_RENDER_NODE=${RAYTUBE_RENDER_NODE:-/dev/dri/renderD128}
export WF_FORCE_DMABUF WF_IMPLICIT_MODIFIER

raytube_find() { # raytube_find <name> <dev-path-under-project-references>
	local f
	for f in "$RAYTUBE_DIR/build/bin/$1" "$RAYTUBE_DIR/project-references/$2"; do
		[ -x "$f" ] && { echo "$f"; return; }
	done
	command -v "$1"
}
WF_RECORDER_BIN=${WF_RECORDER_BIN:-$(raytube_find wf-recorder wf-recorder/build/wf-recorder)}
DOUBLETAKE_BIN=${DOUBLETAKE_BIN:-$(raytube_find doubletake doubletake/bin/doubletake)}
OMACAST_BIN=${OMACAST_BIN:-$(raytube_find omacast omacast/target/release/omacast)}
OMACASTD_BIN=${OMACASTD_BIN:-$(raytube_find omacastd omacast/target/release/omacastd)}
