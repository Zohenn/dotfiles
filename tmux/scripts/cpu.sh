#!/bin/sh
# CPU usage since the previous call (delta of /proc/stat), no sleeping.
state="${XDG_RUNTIME_DIR:-/tmp}/tmux-cpu-$(id -u)"
read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
idle_all=$((idle + iowait))
total=$((user + nice + system + idle_all + irq + softirq + steal))
prev_total=0 prev_idle=0
[ -r "$state" ] && read -r prev_total prev_idle < "$state"
echo "$total $idle_all" > "$state"
dt=$((total - prev_total)); di=$((idle_all - prev_idle))
if [ "$prev_total" -eq 0 ] || [ "$dt" -le 0 ]; then
  sleep 0.5
  read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
  idle_all2=$((idle + iowait))
  total2=$((user + nice + system + idle_all2 + irq + softirq + steal))
  echo "$total2 $idle_all2" > "$state"
  dt=$((total2 - total)); di=$((idle_all2 - idle_all))
fi
[ "$dt" -gt 0 ] && awk -v dt="$dt" -v di="$di" 'BEGIN { printf "%.1f%%\n", 100 * (dt - di) / dt }' || echo "0.0%"
