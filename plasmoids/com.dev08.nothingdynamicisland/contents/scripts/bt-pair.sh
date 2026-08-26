#!/bin/sh
# Pair / forget a Bluetooth device for the Nothing dynamic island.
#
# BluezQt's QML wrapper exposes connectToDevice()/disconnectFromDevice() but not
# Device::pair(), so pairing has to go to BlueZ directly. Calling org.bluez's own
# method (rather than driving `bluetoothctl`, which registers a *competing* agent)
# leaves bluedevil's session agent in charge, so PIN/confirm dialogs still appear.
#
#   bt-pair.sh pair   /org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF
#   bt-pair.sh forget /org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF
set -eu

action=${1:-}
ubi=${2:-}

case "$ubi" in
  /org/bluez/hci*/dev_*) ;;   # only ever act on a real device path
  *) echo "bt-pair.sh: refusing bad device path: $ubi" >&2; exit 2 ;;
esac

adapter=$(dirname "$ubi")

case "$action" in
  pair)
    busctl --system call org.bluez "$ubi" org.bluez.Device1 Pair >/dev/null
    # Trusting is what makes the device reconnect on its own afterwards.
    busctl --system set-property org.bluez "$ubi" org.bluez.Device1 Trusted b true >/dev/null
    busctl --system call org.bluez "$ubi" org.bluez.Device1 Connect >/dev/null
    ;;
  forget)
    busctl --system call org.bluez "$adapter" org.bluez.Adapter1 RemoveDevice o "$ubi" >/dev/null
    ;;
  *)
    echo "bt-pair.sh: unknown action: $action" >&2; exit 2 ;;
esac
