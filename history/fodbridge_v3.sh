#!/system/bin/sh
# FOD bridge for ColorOS-on-Xiaomi (v3)
# v2 added touch-HAL "support fod" so THP writes /sys/class/touch/touch_dev/fod_press_status.
# v3 keeps that flag ON right after every release (the HAL turns it off on extCmd(4,0)),
# so every subsequent touch still triggers SYS_NODE_EVENT_FINGER_DOWN -> fod capture start.
S=vendor.xiaomi.hardware.fingerprintextension.IXiaomiFingerprint/default
T=vendor.xiaomi.hw.touchfeature.ITouchFeature/default
LOG=/data/local/tmp/fodbridge.log
log() { echo "$(date +%H:%M:%S.%N) $*" >> "$LOG"; }
fodon() { /system/bin/service call $T 9 i32 0 i32 10 i32 1 >/dev/null 2>&1; }

n=0
while [ $n -lt 180 ]; do
  if /system/bin/service call $S 1 i32 0 i32 0 >/dev/null 2>&1; then break; fi
  sleep 1; n=$((n+1))
done
log "hal ready after ${n}s"

/system/bin/service call $S 1 i32 2 i32 0 >/dev/null 2>&1
/system/bin/service call $S 1 i32 3 i32 0 >/dev/null 2>&1
fodon
log "colorfade=0 powermode=0 + fod support on"

# keep touch control + fod support alive; 1s interval so the flag is never missing
( while true; do
    /system/bin/service call $S 1 i32 1 i32 1 >/dev/null 2>&1
    fodon
    sleep 1
  done ) &
log "keepalive started"

X1=38000; X2=86000; Y1=210000; Y2=262000
while true; do
  EV=$(grep -A6 "synaptics_tcm_touch" /proc/bus/input/devices 2>/dev/null | grep -o "event[0-9]*" | head -1)
  [ -n "$EV" ] || EV=event7
  EV=/dev/input/$EV
  log "using $EV"
  id=ffffffff; x=0; y=0; pressed=0
  /system/bin/getevent -lt "$EV" | while IFS= read -r line; do
    line=${line%"${line##*[! ]}"}
    case "$line" in
      *ABS_MT_TRACKING_ID*) id=${line##* } ;;
      *ABS_MT_POSITION_X*) v=${line##* }; [ -n "$v" ] && x=$((0x$v)) ;;
      *ABS_MT_POSITION_Y*) v=${line##* }; [ -n "$v" ] && y=$((0x$v)) ;;
      *SYN_REPORT*)
        if [ "$id" = "ffffffff" ]; then
          if [ $pressed -eq 1 ]; then
            /system/bin/service call $S 1 i32 4 i32 0 >/dev/null 2>&1
            fodon
            pressed=0
            log "release"
          fi
        else
          if [ $pressed -eq 0 ] && [ $x -ge $X1 ] && [ $x -le $X2 ] && [ $y -ge $Y1 ] && [ $y -le $Y2 ]; then
            fodon
            /system/bin/service call $S 1 i32 4 i32 1 >/dev/null 2>&1
            pressed=1
            log "press x=$x y=$y"
          fi
        fi ;;
    esac
  done
  log "getevent exited; restarting"
  sleep 1
done
