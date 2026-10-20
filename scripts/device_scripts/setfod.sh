#!/system/bin/sh
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
