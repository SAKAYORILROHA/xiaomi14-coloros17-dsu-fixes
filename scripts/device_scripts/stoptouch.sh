#!/system/bin/sh
echo "=== stop bridge ==="
for p in /proc/[0-9]*/cmdline; do
  c=$(tr '\0' ' ' < "$p" 2>/dev/null)
  case "$c" in
    *fodbridge.sh*) pid=${p#/proc/}; pid=${pid%/cmdline}; kill -9 "$pid" 2>/dev/null ;;
  esac
done
sleep 1
n=0
for p in /proc/[0-9]*/cmdline; do
  c=$(tr '\0' ' ' < "$p" 2>/dev/null)
  case "$c" in *fodbridge.sh*) n=$((n+1));; esac
done
echo "bridge procs after kill=$n"
echo "=== restart touch HAL ==="
setprop ctl.restart touchfeature-service
sleep 4
getprop init.svc.touchfeature-service
echo "=== THP doze log after restart ==="
logcat -c 2>/dev/null
sleep 3
logcat -d -b all -v threadtime 2>/dev/null | grep 'THP-DAE' | tail -8
