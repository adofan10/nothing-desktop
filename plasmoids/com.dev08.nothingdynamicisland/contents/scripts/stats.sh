#!/bin/sh
# System snapshot for the Nothing dynamic island.
# Emits one line of key=value pairs separated by \x1f.
#
# Two modes, because the compact pill and the expanded panel need very different
# amounts of work and the pill is on screen ~always:
#
#   lite  (default)  volume + brightness only -- everything the pill draws.
#                    One fork (wpctl) plus two sysfs reads, ~20 ms.
#   full             adds CPU, memory, temperature, network, Bluetooth and the
#                    Wi-Fi radio state for the expanded panel. ~97 ms, because
#                    nmcli (22 ms), wpctl (15 ms) and bluetoothctl (10 ms) each
#                    cost a process.
#
# At 2 s intervals the full snapshot is ~5% of a core, forever, which is far too
# much to pay for a panel nobody has open. The applet asks for `full` only while
# its popup is up.
mode=${1:-lite}

# --- Volume (PipeWire) ---
vol=0; mute=0
v=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null) || v=""
if [ -n "$v" ]; then
  vol=$(echo "$v" | awk '{printf "%d", $2*100}')
  echo "$v" | grep -q MUTED && mute=1
fi

# --- Brightness (sysfs, no fork) ---
bright=0
for b in /sys/class/backlight/*; do
  [ -r "$b/brightness" ] || continue
  cur=$(cat "$b/brightness"); mx=$(cat "$b/max_brightness")
  [ "$mx" -gt 0 ] && bright=$((cur*100/mx))
  break
done

if [ "$mode" != "full" ]; then
  printf 'vol=%s\037mute=%s\037bright=%s\n' "$vol" "$mute" "$bright"
  exit 0
fi

# ------------------------------------------------------------------ full only
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

# --- Network ---
net=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | head -1)
nname=$(echo "$net" | cut -d: -f1)
ntype=$(echo "$net" | cut -d: -f2)
[ -z "$nname" ] && { nname="Offline"; ntype="none"; }

# --- Wi-Fi radio (numeric D-Bus property; `nmcli radio wifi` is localised) ---
wifi=1
w=$(busctl --system get-property org.freedesktop.NetworkManager \
      /org/freedesktop/NetworkManager org.freedesktop.NetworkManager \
      WirelessEnabled 2>/dev/null)
case "$w" in *false*) wifi=0 ;; esac

# --- Bluetooth ---
bt=$(bluetoothctl devices Connected 2>/dev/null | head -1 | cut -d' ' -f3-)
[ -z "$bt" ] && bt="Not connected"

printf 'cpu=%s\037mem=%s\037temp=%s\037vol=%s\037mute=%s\037bright=%s\037net=%s\037ntype=%s\037bt=%s\037wifi=%s\n' \
  "$cpu" "$mem" "$temp" "$vol" "$mute" "$bright" "$nname" "$ntype" "$bt" "$wifi"
