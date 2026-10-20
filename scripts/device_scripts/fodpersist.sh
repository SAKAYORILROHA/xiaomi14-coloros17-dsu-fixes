#!/system/bin/sh
S=vendor.xiaomi.hw.touchfeature.ITouchFeature/default
logcat -c 2>/dev/null
echo "--- set support fod=1 (code 9) ---"
service call "$S" 9 i32 0 i32 10 i32 1 >/dev/null 2>&1
sleep 0.5
logcat -d -b all -v threadtime 2>/dev/null | grep 'THP-DAE' | tail -3
echo "--- wait 5s, see if it resets ---"
logcat -c 2>/dev/null
sleep 5
logcat -d -b all -v threadtime 2>/dev/null | grep 'THP-DAE' | tail -3
echo "(empty above means no reset)"
echo "--- fod node now ---"
cat /sys/class/touch/touch_dev/fod_press_status
