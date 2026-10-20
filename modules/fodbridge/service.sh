#!/system/bin/sh
# Only run on the ported ColorOS (DSU) system, never on the stock MIUI/HyperOS.
if [ -z "$(getprop ro.build.version.oplusrom)" ]; then
  echo "$(date) fodbridge: not ColorOS, skip" >> /data/local/tmp/fodbridge.log
  exit 0
fi
D=/data/adb/modules/fodbridge
[ -f "$D/fodbridge.sh" ] || D=${0%/*}
setprop persist.vendor.fingerprint.optical.iconlocation 280
setprop persist.vendor.fingerprint.optical.sensorlocation 600::2391
( sh "$D/fodbridge.sh" >/dev/null 2>&1 ) &
