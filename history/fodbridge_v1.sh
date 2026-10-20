#!/system/bin/sh
# FOD bridge for ColorOS-on-Xiaomi: translate FOD-area touches to Xiaomi HAL extCmd(4)
S=vendor.xiaomi.hardware.fingerprintextension.IXiaomiFingerprint/default
LOG=/data/local/tmp/fodbridge.log
log() { echo "$(date +%H:%M:%S.%N) $*" >> "$LOG"; }
n=0
while [ $n -lt 180 ]; do
  if /system/bin/service call $S 1 i32 0 i32 0 >/dev/null 2>&1; then break; fi
  sleep 1; n=$((n+1))
done
log "hal ready after ${n}s"
( while true; do /system/bin/service call $S 1 i32 1 i32 1 >/dev/null 2>&1; sleep 30; done ) &
log "touch ctl keepalive started"
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
