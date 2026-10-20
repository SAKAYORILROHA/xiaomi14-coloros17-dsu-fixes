#!/system/bin/sh
P=$(pidof com.android.systemui)
echo "old=$P"
kill -9 "$P" 2>/dev/null
sleep 6
echo "new=$(pidof com.android.systemui)"
