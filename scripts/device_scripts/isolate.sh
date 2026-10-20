#!/system/bin/sh
echo "=== stop bridge ==="
for p in /proc/[0-9]*/cmdline; do
  c=$(tr '\0' ' ' < "$p" 2>/dev/null)
  case "$c" in
    *fodbridge.sh*) pid=${p#/proc/}; pid=${pid%/cmdline}; kill -9 "$pid" 2>/dev/null ;;
  esac
done
sleep 1
echo "=== force support fod off ==="
service call vendor.xiaomi.hw.touchfeature.ITouchFeature/default 9 i32 0 i32 10 i32 0 >/dev/null 2>&1
echo "=== also clear HAL finger state ==="
service call vendor.xiaomi.hardware.fingerprintextension.IXiaomiFingerprint/default 1 i32 4 i32 0 >/dev/null 2>&1
sleep 1
echo "=== restart touch HAL ==="
setprop ctl.restart touchfeature-service
sleep 4
getprop init.svc.touchfeature-service
echo "=== state ==="
logcat -c 2>/dev/null
sleep 3
logcat -d -b all -v threadtime 2>/dev/null | grep 'THP-DAE' | tail -5
n=0
for p in /proc/[0-9]*/cmdline; do c=$(tr '\0' ' ' < "$p" 2>/dev/null); case "$c" in *fodbridge.sh*) n=$((n+1));; esac; done
echo "bridge_procs=$n"
