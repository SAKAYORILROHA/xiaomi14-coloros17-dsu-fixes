#!/system/bin/sh
echo "=== before ==="
settings get global fingerprint_icon_info
settings get secure oplus_customize_fingerprint_unlock_switch
settings put secure oplus_customize_fingerprint_unlock_switch 1
settings put secure oplus_customize_fingerprint_unlock_enter_desktop 1
sleep 3
echo "=== after ==="
settings get secure oplus_customize_fingerprint_unlock_switch
settings get global fingerprint_icon_info
echo "=== sysui logs ==="
logcat -d -b all -v threadtime 2>/dev/null | grep -i -E 'FingerSwitchHelper|haveFp|initFpInfo|fpIconShouldShow' | tail -10
