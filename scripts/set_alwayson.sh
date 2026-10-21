#!/system/bin/sh
echo "== before =="
for k in doze_always_on full_screen_aod panoramic_aod_enable Setting_AodState Setting_AodEnable Setting_AodSwitchEnable oplus_keyguard_panoramic_aod_support Setting_Aod_ShowWallpaper; do
  printf '%s=' "$k"; settings get secure "$k"
done
settings put secure doze_always_on 1
echo "== after doze_always_on =="
settings get secure doze_always_on
dumpsys power | grep -E 'mAlwaysOnEnabled=|mWakefulness='
