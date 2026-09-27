#!/bin/bash
# fetch-upstreams.sh -- clone doubletake, wf-recorder and omacast into
# build/src/ at the exact commits in patches/BASES.txt and apply raytube's
# patches. Safe to re-run: an existing checkout is reset to the pinned commit
# and patched again.
set -euo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
SRC="$ROOT/build/src"
declare -A URL=(
	[doubletake]=https://github.com/omarroth/doubletake.git
	[wf-recorder]=https://github.com/ammen99/wf-recorder.git
	[omacast]=https://github.com/Aphrodine-wq/omacast.git
)
mkdir -p "$SRC"
for name in doubletake wf-recorder omacast; do
	base=$(awk -v n="$name" '$1 == n && $2 == "base:" {print $3}' "$ROOT/patches/BASES.txt")
	[ -n "$base" ] || { echo "no pinned commit for $name in patches/BASES.txt" >&2; exit 1; }
	dir="$SRC/$name"
	if [ ! -d "$dir/.git" ]; then
		git clone --quiet "${URL[$name]}" "$dir"
	fi
	git -C "$dir" fetch --quiet origin
	git -C "$dir" checkout --quiet --force --detach "$base"
	git -C "$dir" clean --quiet -fdx
	git -C "$dir" apply --whitespace=nowarn "$ROOT/patches/$name.patch"
	echo "$name: $base + patches/$name.patch"
done
