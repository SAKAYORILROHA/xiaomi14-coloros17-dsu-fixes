#!/system/bin/sh
# late_start service: restore SDK, apply AOD/charging/fingerprint fixes, keep HAL alive.

LOG=/data/local/tmp/dsufix.log
log() { echo "$(date '+%m-%d %H:%M:%S') $*" >> "$LOG"; }

sleep 20
# vendor HALs are up by now; put the real SDK value back
resetprop ro.build.version.sdk 37
log "restored sdk=$(getprop ro.build.version.sdk)"

# ---- AOD: full screen + always on ----
settings put secure doze_always_on 1
settings put secure full_screen_aod 1
settings put secure panoramic_aod_enable 1
settings put secure oplus_keyguard_panoramic_aod_support 1
settings put secure Setting_AodState 2
settings put secure Setting_AodEnable 1
settings put secure Setting_AodSwitchEnable 1
# stop dock/sleep screensaver from waking the screen during AOD
settings put secure screensaver_enabled 0
settings put secure screensaver_activate_on_dock 0
settings put secure screensaver_activate_on_sleep 0
log "aod settings applied"

# ---- fingerprint icon position (verified on 1200x2670 panel) ----
setprop persist.vendor.fingerprint.optical.iconlocation 280
setprop persist.vendor.fingerprint.optical.sensorlocation 600::2391
settings put secure fingerprint_icon_margin_bottom 170
# ColorOS gates the on-screen fingerprint icon (and its press animation) behind this switch.
# Without it haveFp() is false -> no keyguard icon / no ripple animation / no enroll progress.
settings put secure oplus_customize_fingerprint_unlock_switch 1
settings put secure oplus_customize_fingerprint_unlock_enter_desktop 1
settings put secure fingerprint_enabled 1
log "fingerprint icon switch applied"

# ---- FOD bridge ----
# The fodbridge module has its own service.sh; only start it manually if that module is gone.
if [ ! -f /data/adb/modules/fodbridge/service.sh ]; then
  [ -x /data/local/tmp/fodbridge-start.sh ] && sh /data/local/tmp/fodbridge-start.sh
  log "fodbridge module missing, fallback start attempted"
else
  log "fodbridge module present (self-starting)"
fi

# ---- watchdog: keep the OPlus charger HAL alive without a global SDK lie ----
while true; do
  st=$(getprop init.svc.oplus_charger_hal_service)
  if [ "$st" != "running" ]; then
    log "charger hal state=$st, restarting"
    resetprop ro.build.version.sdk 36
    setprop ctl.stop oplus_charger_hal_service
    sleep 1
    setprop ctl.start oplus_charger_hal_service
    n=0
    while [ $n -lt 40 ]; do
      [ "$(getprop init.svc.oplus_charger_hal_service)" = "running" ] && break
      sleep 0.5
      n=$((n+1))
    done
    resetprop ro.build.version.sdk 37
    log "charger hal restarted, state=$(getprop init.svc.oplus_charger_hal_service)"
  fi
  sleep 15
done
