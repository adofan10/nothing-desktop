#!/bin/sh
# One-shot system snapshot for the Nothing dynamic island.
# Emits a single line of key=value pairs separated by \x1f.
ST=/tmp/.nothing-island-cpu.$(id -u)

# --- CPU (delta against previous run) ---
set -- $(awk '/^cpu /{print $2+$3+$4+$6+$7+$8, $2+$3+$4+$5+$6+$7+$8}' /proc/stat)
busy=$1; total=$2
cpu=0
if [ -r "$ST" ]; then
  read pb pt < "$ST"
  db=$((busy-pb)); dt=$((total-pt))
  [ "$dt" -gt 0 ] && cpu=$((100*db/dt))
fi
printf '%s %s\n' "$busy" "$total" > "$ST"
[ "$cpu" -lt 0 ] && cpu=0; [ "$cpu" -gt 100 ] && cpu=100

# --- Memory ---
mem=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{if(t>0) printf "%d", (t-a)*100/t; else print 0}' /proc/meminfo)

# --- Temperature (prefer x86_pkg_temp, else first zone) ---
temp=0
for z in /sys/class/thermal/thermal_zone*; do
  [ -r "$z/type" ] || continue
  case "$(cat "$z/type")" in
    x86_pkg_temp|acpitz) temp=$(( $(cat "$z/temp" 2>/dev/null || echo 0) / 1000 )); break ;;
  esac
done
[ "$temp" = 0 ] && temp=$(awk '{printf "%d", $1/1000}' /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0)

# --- Volume (PipeWire) ---
vol=0; mute=0
v=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null) || v=""
if [ -n "$v" ]; then
  vol=$(echo "$v" | awk '{printf "%d", $2*100}')
  echo "$v" | grep -q MUTED && mute=1
fi

# --- Brightness ---
bright=0
for b in /sys/class/backlight/*; do
  [ -r "$b/brightness" ] || continue
  cur=$(cat "$b/brightness"); mx=$(cat "$b/max_brightness")
  [ "$mx" -gt 0 ] && bright=$((cur*100/mx))
  break
done

# --- Network ---
net=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | head -1)
nname=$(echo "$net" | cut -d: -f1)
ntype=$(echo "$net" | cut -d: -f2)
[ -z "$nname" ] && { nname="Offline"; ntype="none"; }

# --- Bluetooth ---
bt=$(bluetoothctl devices Connected 2>/dev/null | head -1 | cut -d' ' -f3-)
[ -z "$bt" ] && bt="Not connected"

printf 'cpu=%s\037mem=%s\037temp=%s\037vol=%s\037mute=%s\037bright=%s\037net=%s\037ntype=%s\037bt=%s\n' \
  "$cpu" "$mem" "$temp" "$vol" "$mute" "$bright" "$nname" "$ntype" "$bt"
