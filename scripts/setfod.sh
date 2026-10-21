#!/system/bin/sh
# 实验脚本：会把触摸 HAL 置为 support fod=1（FOD 模式），可能导致"只能点击、不能滑动"。
# 仅用于排查，用完务必还原：
#   service call vendor.xiaomi.hw.touchfeature.ITouchFeature/default 9 i32 0 i32 10 i32 0
#   setprop ctl.restart touchfeature-service
S=vendor.xiaomi.hw.touchfeature.ITouchFeature/default
echo "--- call code 1 (setModeValue 0,10,1) ---"
service call "$S" 1 i32 0 i32 10 i32 1 2>&1 | head -2
sleep 0.5
echo "--- thp log ---"
logcat -d -b all -v threadtime 2>/dev/null | grep -i 'THP-DAE' | tail -4
sleep 3
echo "--- after 3s ---"
logcat -d -b all -v threadtime 2>/dev/null | grep -i 'THP-DAE' | tail -3
echo "--- fod node ---"
cat /sys/class/touch/touch_dev/fod_press_status
