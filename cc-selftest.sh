#!/bin/bash
# cc-selftest.sh [seconds] -- cast to the Chromecast with the current
# ~/.config/omacast/config.toml, then judge the result from the receiver's own
# RTCP feedback: frames decoded / rendered per second, render delay, NACKs,
# keyframe requests, and sender-side shedding. No one needs to watch the TV.
set -u
SECS=${1:-30}
DIR="$(dirname "$(readlink -f "$0")")"
. "$DIR/lib/raytube-env.sh"   # OMACAST_BIN, OMACASTD_BIN
LOG="$HOME/.local/state/omacast/omacastd.log"

"$OMACAST_BIN" stop >/dev/null 2>&1
pkill -x omacastd 2>/dev/null; sleep 1
: > "$LOG"
(RUST_LOG=info,omacast_core::cast::sender=debug OMACAST_RTCP_EVENT_LOG=${EVENT_LOG:-0} setsid "$OMACASTD_BIN" >/dev/null 2>&1 &)
sleep 1

echo "== casting for ${SECS}s"
timeout 25 "$OMACAST_BIN" start --to "${DEVICE:?set DEVICE to the Chromecast name}" 2>&1 | tail -1
sleep "$SECS"
"$OMACAST_BIN" status 2>&1 | head -2
"$OMACAST_BIN" stop 2>&1 | tail -1
sleep 2

clean=$(sed 's/\x1b\[[0-9;]*m//g' "$LOG")
echo "== receiver feedback (5 s windows)"
grep -oE "receiver( audio)?: .*" <<<"$clean" | sed "s/^/  /"
echo "== sender"
echo "  frames shed (window full / awaiting key): $(grep -cE 'shedding' <<<"$clean")"
grep -E "ERROR|WARN" <<<"$clean" | sed 's/^[^ ]* */  /' | cut -c1-160 | sort | uniq -c | head -8

# Verdict. This Chromecast firmware rejects OFFERs that request the receiver
# event log (decoded/rendered events), so judge from what it does report:
# checkpoints = frames received complete; keyframe requests = decoder trouble.
w=$(grep -oE "receiver: .*" <<<"$clean" | tail -2 | head -1)
cp=$(grep -oE "checkpoints [0-9]+" <<<"$w" | grep -oE "[0-9]+"); kr=$(grep -oE "keyframe requests [0-9]+" <<<"$w" | grep -oE "[0-9]+")
nk=$(grep -oE "nacks [0-9]+" <<<"$w" | grep -oE "[0-9]+")
fps=$(( ${cp:-0} / 5 ))
if [ "${fps}" -ge 20 ] && [ "${kr:-1}" -eq 0 ]; then v=PASS; else v=FAIL; fi
echo "== verdict: $v -- ~${fps} fps received complete, ${kr:-?} keyframe requests, ${nk:-?} nacks per 5 s"
