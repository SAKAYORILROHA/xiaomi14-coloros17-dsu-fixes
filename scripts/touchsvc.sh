#!/system/bin/sh
echo "=== touchfeature procs ==="
ps -A -o PID,PPID,ETIME,ARGS | grep -i -E 'touchfeature|touch-V2|xiaomi_touch'
echo "=== services ==="
service list | grep -i touch
echo "=== init svc props ==="
getprop | grep -i -E 'init.svc.*touch'
