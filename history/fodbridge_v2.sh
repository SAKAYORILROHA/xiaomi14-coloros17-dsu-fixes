#!/system/bin/sh
# FOD bridge for ColorOS-on-Xiaomi: translate FOD-area touches to Xiaomi HAL extCmd(4)
# v2: also keep the Xiaomi touch HAL in "FOD support" mode so the touch driver writes
#     /sys/class/touch/touch_dev/fod_press_status on real presses (that node is what
#     triggers mfp-daemon's SYS_NODE_EVENT_FINGER_DOWN -> fod capture start).
S=vendor.xiaomi.hardware.fingerprintextension.IXiaomiFingerprint/default
T=vendor.xiaomi.hw.touchfeature.ITouchFeature/default
LOG=/data/local/tmp/fodbridge.log
log() { echo "$(date +%H:%M:%S.%N) $*" >> "$LOG"; }

n=0
while [ $n -lt 180 ]; do
  if /system/bin/service call $S 1 i32 0 i32 0 >/dev/null 2>&1; then break; fi
  sleep 1; n=$((n+1))
done
log "hal ready after ${n}s"

# baseline display state the old working setup had: colorfade=0, powermode=0
/system/bin/service call $S 1 i32 2 i32 0 >/dev/null 2>&1
/system/bin/service call $S 1 i32 3 i32 0 >/dev/null 2>&1
log "colorfade=0 powermode=0 sent"

# keep touch control + FOD support alive
( while true; do
    /system/bin/service call $S 1 i32 1 i32 1 >/dev/null 2>&1
    /system/bin/service call $T 9 i32 0 i32 10 i32 1 >/dev/null 2>&1
    sleep 2
  done ) &
log "touch ctl + fod-support keepalive started"

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
            pressed=0
            log "release"
          fi
        else
          if [ $pressed -eq 0 ] && [ $x -ge $X1 ] && [ $x -le $X2 ] && [ $y -ge $Y1 ] && [ $y -le $Y2 ]; then
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
