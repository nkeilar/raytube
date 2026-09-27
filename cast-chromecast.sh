#!/bin/bash
# cast-chromecast.sh <device name> -- mirror this laptop to a Chromecast via
# omacast (Cast Streaming) until stopped (Ctrl+C / SIGTERM), under the thermal
# guard. Video comes from the patched wf-recorder set as video_command in
# ~/.config/omacast/config.toml; omacast adds Opus audio.
set -u
DIR="$(dirname "$(readlink -f "$0")")"
. "$DIR/lib/raytube-env.sh"   # OMACAST_BIN, OMACASTD_BIN
NAME=${1:?usage: $0 <device name>}

if [ -z "${CAST_GUARDED:-}" ]; then
	export CAST_GUARDED=1
	exec "$DIR/cast-guard.sh" "$0" "$@"
fi

stop() { "$OMACAST_BIN" stop >/dev/null 2>&1; exit 0; }
trap stop INT TERM

# Start a fresh daemon so this session's environment (capture output, audio
# source) applies; a daemon left from an earlier session would keep its own.
"$OMACAST_BIN" stop >/dev/null 2>&1
pkill -x omacastd 2>/dev/null && sleep 0.5
(setsid "$OMACASTD_BIN" >/dev/null 2>&1 &)
sleep 1
"$OMACAST_BIN" start --to "$NAME" || exit 1

# Stay alive while the session runs; exit 1 if it ends on its own so a
# supervisor can tell it apart from a requested stop.
while "$OMACAST_BIN" status 2>/dev/null | grep -q '^casting'; do
	sleep 3 & wait $!
done
exit 1
