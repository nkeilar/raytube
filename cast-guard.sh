#!/bin/bash
# cast-guard.sh -- run a casting command under thermal protection.
#
#   cast-guard.sh doubletake -target <apple-tv-ip> -hwaccel intel ...
#
# While the command runs:
#   * FAN_MODE=auto: fan minimums are raised to maximum only while
#     CPU/GPU >= FAN_BOOST_C, and released after FAN_HOLD_S at <= FAN_CALM_C.
#     FAN_MODE=max raises them for the whole run. SMC stays in control either
#     way, so the fans fall back to automatic if this script dies.
#   * FAN_MODE=quiet (default): our own fan curve under manual control, because
#     the Mac's SMC runs these fans flat out from about 67C. QUIET_RPM up to
#     QUIET_FROM_C, rising linearly to full speed at QUIET_MAX_C; at or above
#     QUIET_MAX_C the SMC takes over again (and the auto boost above applies).
#     The curve resumes after FAN_HOLD_S at <= QUIET_RESUME_C. Manual control is
#     released on every exit this script can catch.
#   * CPU package or AMD GPU >= THROTTLE_C for 3 samples: cap CPU at THROTTLE_PCT
#     via intel_pstate; lifted again once both are <= RECOVER_C
#   * any sample >= ABORT_C: stop the command
# On exit, fan minimums and the CPU cap are restored.
set -u

THROTTLE_C=${THROTTLE_C:-85}
RECOVER_C=${RECOVER_C:-78}
ABORT_C=${ABORT_C:-92}
THROTTLE_PCT=${THROTTLE_PCT:-60}
INTERVAL=${INTERVAL:-2}
HOLD_S=${HOLD_S:-30}   # minimum time the CPU cap stays on once applied
FAN_MODE=${FAN_MODE:-quiet}
QUIET_RPM=${QUIET_RPM:-3500}
QUIET_FROM_C=${QUIET_FROM_C:-70}
QUIET_MAX_C=${QUIET_MAX_C:-82}
QUIET_RESUME_C=${QUIET_RESUME_C:-76}
FAN_BOOST_C=${FAN_BOOST_C:-80}
FAN_CALM_C=${FAN_CALM_C:-70}
FAN_HOLD_S=${FAN_HOLD_S:-60}
LOG=${CAST_GUARD_LOG:-$HOME/.local/state/raytube/thermal.log}

# Hardware controls are optional: each one missing on this machine is skipped
# (fans: MacBook applesmc; CPU cap and turbo: intel_pstate). The abort only
# needs a CPU temperature.
SMC=$(ls -d /sys/devices/platform/applesmc.* 2>/dev/null | head -1)
HAVE_FANS=0; [ -n "$SMC" ] && [ -e "$SMC/fan1_min" ] && HAVE_FANS=1
PERF=/sys/devices/system/cpu/intel_pstate/max_perf_pct
# Turbo off while casting (TURBO=1 keeps it): the cast needs ~5% of a core, and
# turbo bursts from other apps spiked the CPU to 88-94C and the fans to max.
TURBO_FILE=/sys/devices/system/cpu/intel_pstate/no_turbo
TURBO=${TURBO:-0}
HAVE_PSTATE=0; [ -e "$PERF" ] && HAVE_PSTATE=1
hwmon() { local n; n=$(grep -lE "^($1)\$" /sys/class/hwmon/hwmon*/name 2>/dev/null | head -1); [ -n "$n" ] && echo "$(dirname "$n")/temp1_input"; }
CPU_T=$(hwmon 'coretemp|k10temp|zenpower')
[ -n "$CPU_T" ] || CPU_T=/sys/class/thermal/thermal_zone0/temp
GPU_T=$(hwmon 'amdgpu|radeon|nouveau')

mkdir -p "$(dirname "$LOG")"
log() { echo "$(date '+%F %T') $*" | tee -a "$LOG" >&2; }
# Write a sysfs control: directly when the raytube group may (config/tmpfiles),
# else skip (warned once per file). CAST_GUARD_SUDO=1 also tries passwordless
# sudo (opt-in, e.g. before logging in again after joining the raytube group).
declare -A warned=()
put() {
	[ -n "$1" ] && [ -e "$1" ] || return 0
	if [ -w "$1" ]; then echo "$2" > "$1" 2>/dev/null && return 0; fi
	[ "${CAST_GUARD_SUDO:-0}" = 1 ] && echo "$2" | sudo -n tee "$1" >/dev/null 2>&1 && return 0
	[ -n "${warned[$1]:-}" ] || { warned[$1]=1; log "WARN: no permission to write $1 (see config/tmpfiles/raytube-hw.conf)"; }
}

[ $# -gt 0 ] || { echo "usage: $0 <command> [args...]" >&2; exit 2; }

orig_fan1=""; orig_fan2=""; orig_perf=""; orig_no_turbo=""
if (( HAVE_FANS )); then orig_fan1=$(cat "$SMC/fan1_min"); orig_fan2=$(cat "$SMC/fan2_min"); fi
if (( HAVE_PSTATE )); then orig_perf=$(cat "$PERF"); orig_no_turbo=$(cat "$TURBO_FILE" 2>/dev/null); fi
(( HAVE_FANS )) || FAN_MODE=none
child=
restore() {
	trap - EXIT INT TERM
	[ -n "$child" ] && kill -INT "$child" 2>/dev/null && sleep 2 && kill -KILL "$child" 2>/dev/null
	if (( HAVE_FANS )); then
		fans_manual_off
		put "$SMC/fan1_min" "$orig_fan1"; put "$SMC/fan2_min" "$orig_fan2"
	fi
	if (( HAVE_PSTATE )); then put "$PERF" "$orig_perf"; put "$TURBO_FILE" "$orig_no_turbo"; fi
	log "restored:${orig_fan1:+ fans (min $orig_fan1/$orig_fan2 rpm)}${orig_perf:+ CPU cap ($orig_perf%) turbo}"
}
trap restore EXIT
trap 'exit 130' INT TERM

fans_up() { put $SMC/fan1_min "$(cat $SMC/fan1_max)"; put $SMC/fan2_min "$(cat $SMC/fan2_max)"; }
fans_auto() { put $SMC/fan1_min "$orig_fan1"; put $SMC/fan2_min "$orig_fan2"; }
# Quiet: fan1 follows the curve for temperature $1; fan2 runs at the same
# fraction of its own maximum. Writes only when the target moves by 100+ rpm.
quiet_rpm=0
fans_quiet() {
	local t=${1:-0} max1 rpm
	max1=$(cat $SMC/fan1_max)
	rpm=$QUIET_RPM
	(( t > QUIET_FROM_C )) && rpm=$(( QUIET_RPM + (t - QUIET_FROM_C) * (max1 - QUIET_RPM) / (QUIET_MAX_C - QUIET_FROM_C) ))
	(( rpm > max1 )) && rpm=$max1
	(( quiet_rpm && rpm - quiet_rpm < 100 && quiet_rpm - rpm < 100 )) && return
	put $SMC/fan1_manual 1; put $SMC/fan1_output "$rpm"
	put $SMC/fan2_manual 1; put $SMC/fan2_output "$(( rpm * $(cat $SMC/fan2_max) / max1 ))"
	quiet_rpm=$rpm
}
fans_manual_off() { put $SMC/fan1_manual 0; put $SMC/fan2_manual 0; quiet_rpm=0; }
boosted=0; boosted_at=0; quiet=0; calm_since=$SECONDS
(( TURBO || !HAVE_PSTATE )) || put "$TURBO_FILE" 1
# The fan curve follows the average of the last 5 samples (~10 s) so a turbo
# spike can't knock it off; throttle and abort still use every sample.
recent=()
if [ "$FAN_MODE" = max ]; then fans_up; boosted=1; fi
if [ "$FAN_MODE" = quiet ]; then fans_quiet; quiet=1; fi
log "fan mode $FAN_MODE (fans: $HAVE_FANS, intel_pstate: $HAVE_PSTATE); throttle at ${THROTTLE_C}C, abort at ${ABORT_C}C; running: $*"

"$@" 0<&0 &
child=$!

hot=0; crit=0; throttled=0; throttled_at=0; peak=0
while kill -0 "$child" 2>/dev/null; do
	c=$(( $(cat "$CPU_T" 2>/dev/null || echo 0) / 1000 ))
	g=0; [ -n "$GPU_T" ] && g=$(( $(cat "$GPU_T" 2>/dev/null || echo 0) / 1000 ))
	t=$(( c > g ? c : g )); (( t > peak )) && peak=$t
	recent=("${recent[@]: -4}" "$t"); tsum=0; for x in "${recent[@]}"; do tsum=$(( tsum + x )); done
	tavg=$(( tsum / ${#recent[@]} ))
	echo "$(date +%T) cpu=${c}C gpu=${g}C fans=$(cat "$SMC/fan1_input" 2>/dev/null || echo -)/$(cat "$SMC/fan2_input" 2>/dev/null || echo -) cap=$(cat "$PERF" 2>/dev/null || echo -)%" >>"$LOG"
	# Abort on sustained heat only: Haswell reports single-sample turbo spikes
	# to Tjmax, which the CPU handles itself; one spike throttles instead.
	if (( t >= ABORT_C )); then crit=$((crit + 1)); else crit=0; fi
	if (( crit >= 2 )); then
		log "ABORT: cpu=${c}C gpu=${g}C >= ${ABORT_C}C, stopping cast"
		kill -INT "$child"; sleep 2; kill -KILL "$child" 2>/dev/null
		break
	fi
	if [ "$FAN_MODE" = quiet ]; then
		if (( quiet && tavg >= QUIET_MAX_C )); then
			fans_manual_off; quiet=0; calm_since=$SECONDS; log "quiet fans off, automatic: avg ${tavg}C (cpu=${c}C gpu=${g}C)"
		elif (( quiet )); then
			fans_quiet "$tavg"
		elif (( tavg > QUIET_RESUME_C )); then
			calm_since=$SECONDS
		elif (( !boosted && SECONDS - calm_since >= FAN_HOLD_S )); then
			fans_quiet "$tavg"; quiet=1; log "quiet fan curve on (${quiet_rpm} rpm): avg ${tavg}C"
		fi
	fi
	if [ "$FAN_MODE" = auto ] || [ "$FAN_MODE" = quiet ]; then
		if (( !boosted && t >= FAN_BOOST_C )); then
			fans_up; boosted=1; boosted_at=$SECONDS; log "fans boosted: cpu=${c}C gpu=${g}C"
		elif (( boosted && t <= FAN_CALM_C && SECONDS - boosted_at >= FAN_HOLD_S )); then
			fans_auto; boosted=0; log "fans back to automatic: cpu=${c}C gpu=${g}C"
		elif (( boosted && t > FAN_CALM_C )); then
			boosted_at=$SECONDS
		fi
	fi
	if (( t >= THROTTLE_C )); then hot=$((hot + 1)); else hot=0; fi
	# Throttle after 3 hot samples, or at once on a spike near the abort point.
	if (( !throttled && (hot >= 3 || t >= ABORT_C - 4) )); then
		put $PERF "$THROTTLE_PCT"; throttled=1; throttled_at=$SECONDS; log "THROTTLE: cpu=${c}C gpu=${g}C, CPU capped at ${THROTTLE_PCT}%"
	elif (( throttled && t <= RECOVER_C && SECONDS - throttled_at >= HOLD_S )); then
		put $PERF "$orig_perf"; throttled=0; log "recovered: cpu=${c}C gpu=${g}C, CPU cap lifted"
	fi
	sleep "$INTERVAL"
done
wait "$child" 2>/dev/null; rc=$?
log "cast ended (exit $rc), peak ${peak}C"
exit $rc
