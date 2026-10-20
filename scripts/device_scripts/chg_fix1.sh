#!/system/bin/sh
LOG=/data/local/tmp/chg_fix.log
echo "== before ==" > $LOG
echo "sdk=$(getprop ro.build.version.sdk)" >> $LOG
echo "svc=$(getprop init.svc.oplus_charger_hal_service)" >> $LOG
# 1) temporarily pretend SDK 36 so the rust binder HAL passes its version gate
resetprop ro.build.version.sdk 36
echo "sdk_after=$(getprop ro.build.version.sdk)" >> $LOG
# 2) restart the crashing HAL service
setprop ctl.stop oplus_charger_hal_service
sleep 1
setprop ctl.start oplus_charger_hal_service
sleep 3
echo "svc_after=$(getprop init.svc.oplus_charger_hal_service)" >> $LOG
ps -A -o PID,ARGS | grep 'charger-V6' >> $LOG 2>/dev/null
sleep 2
echo "--- recent logcat ---" >> $LOG
logcat -d -b all -v threadtime 2>/dev/null | grep -i -E 'ICharger|charger.*registered|Unsupported Android SDK|oplus_charger' | tail -15 >> $LOG
cat $LOG
