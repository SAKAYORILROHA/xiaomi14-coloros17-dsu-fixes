#!/system/bin/sh
# 一次性应用本轮所有修复（幂等，可在任意时刻重复执行）
# 用法：su -c 'sh /data/local/tmp/dsufix_apply.sh'

echo "[1/6] AOD 全屏 + 全天候"
settings put secure doze_always_on 1
settings put secure full_screen_aod 1
settings put secure panoramic_aod_enable 1
settings put secure oplus_keyguard_panoramic_aod_support 1
settings put secure Setting_AodState 2
settings put secure Setting_AodEnable 1
settings put secure Setting_AodSwitchEnable 1

echo "[2/6] 关闭 dock/sleep 屏保（防止 AOD 期间屏幕自己乱亮）"
settings put secure screensaver_enabled 0
settings put secure screensaver_activate_on_dock 0
settings put secure screensaver_activate_on_sleep 0

echo "[3/6] 指纹图标对齐 + 打开 ColorOS 锁屏指纹图标开关"
setprop persist.vendor.fingerprint.optical.iconlocation 280
setprop persist.vendor.fingerprint.optical.sensorlocation 600::2391
settings put secure fingerprint_icon_margin_bottom 170
settings put secure oplus_customize_fingerprint_unlock_switch 1
settings put secure oplus_customize_fingerprint_unlock_enter_desktop 1
settings put secure fingerprint_enabled 1

echo "[4/6] 修复 oplus charger HAL 的 SDK 37 崩溃"
resetprop ro.build.version.sdk 36
setprop ctl.stop oplus_charger_hal_service
sleep 1
setprop ctl.start oplus_charger_hal_service

echo "[5/6] 启动指纹桥接"
[ -x /data/adb/modules/fodbridge/service.sh ] && sh /data/adb/modules/fodbridge/service.sh

echo "[6/6] 状态"
getprop ro.build.version.sdk
getprop init.svc.oplus_charger_hal_service
dumpsys battery | head -9
dumpsys power | grep -E 'mAlwaysOnEnabled='
