#!/usr/bin/env bash
# Live CPU and memory of this computer's CybroidOS build (tools/setup-builder.sh):
# the runner service and the build's containers, from the kernel's cgroup
# figures (no sudo or Docker access needed). Ctrl-C to stop.
#
#   tools/builder-top.sh [seconds between updates]   (default 2)
set -u
every="${1:-2}"
cores="$(nproc)"
cg=/sys/fs/cgroup/system.slice
declare -A last

usage() { awk '/^usage_usec/{print $2}' "$1/cpu.stat" 2>/dev/null || echo 0; }
mib() { awk '{printf "%.0f", $1/1048576}' "$1/memory.current" 2>/dev/null || echo 0; }
bar() { local n=$(( $1 * 30 / 100 )); ((n > 30)) && n=30; printf '%*s' "$n" '' | tr ' ' '#'; printf '%*s' $((30 - n)) ''; }

while :; do
	out=""; tcpu=0; tmem=0
	for d in "$cg/cybroid-builder.service" "$cg"/docker-*.scope; do
		[ -d "$d" ] || continue
		u=$(usage "$d"); p=${last[$d]:-$u}; last[$d]=$u
		pct=$(( (u - p) / (every * 10000) ))          # % of one core
		all=$(( pct / cores ))                         # % of the machine
		m=$(mib "$d")
		case "$d" in *builder*) name="runner";; *) id=${d##*/docker-}; name="build ${id:0:12}";; esac
		out+=$(printf '%-20s %3d%% [%s] %6d MiB' "$name" "$all" "$(bar "$all")" "$m")$'\n'
		tcpu=$((tcpu + all)); tmem=$((tmem + m))
	done
	read -r _ total _ avail _ < <(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{print "x",t,"x",a,"x"}' /proc/meminfo)
	clear
	printf 'CybroidOS build on %s · %s · %d cores\n\n' "$(hostname -s)" "$(date +%T)" "$cores"
	printf '%s' "${out:-No build running.$'\n'}"
	printf '\n%-20s %3d%% [%s] %6d MiB\n' "build total" "$tcpu" "$(bar "$tcpu")" "$tmem"
	printf 'Computer: load %s · %d MiB free of %d MiB\n' "$(cut -d' ' -f1-3 /proc/loadavg)" $((avail / 1024)) $((total / 1024))
	sleep "$every"
done
