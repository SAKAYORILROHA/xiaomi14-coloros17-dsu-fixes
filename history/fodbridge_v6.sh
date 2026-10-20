#!/system/bin/sh
# FOD bridge for ColorOS-on-Xiaomi (v6)
# v6: support-fod is only enabled while the device is LOCKED (or screen off).
#     Keeping it always-on made the touch HAL treat every touch as an FOD press,
#     which broke scrolling ("only tap works, no swipe").
S=vendor.xiaomi.hardware.fingerprintextension.IXiaomiFingerprint/default
T=vendor.xiaomi.hw.touchfeature.ITouchFeature/default
LOG=/data/local/tmp/fodbridge.log
ST=/data/local/tmp/fod.locked
log() { echo "$(date +%H:%M:%S.%N) $*" >> "$LOG"; }
fodon() { /system/bin/service call $T 9 i32 0 i32 10 i32 "$1" >/dev/null 2>&1; }
extc() { /system/bin/service call $S 1 i32 "$1" i32 "$2" >/dev/null 2>&1; }
locked() {
  d=$(dumpsys trust 2>/dev/null | grep -o 'deviceLocked=[01]' | head -1)
  [ "$d" = "deviceLocked=1" ] && echo 1 || echo 0
}

n=0
while [ $n -lt 180 ]; do
  if /system/bin/service call $S 1 i32 0 i32 0 >/dev/null 2>&1; then break; fi
  sleep 1; n=$((n+1))
done
log "hal ready after ${n}s"

extc 2 0
extc 3 0
fodon 0
echo 0 > $ST
log "colorfade=0 powermode=0, fod support off until locked"

# state loop: keep /data/local/tmp/fod.locked in sync, toggle touch-HAL fod support
( while true; do
    L=$(locked)
    echo "$L" > $ST
    if [ "$L" = "1" ]; then
      fodon 1
      extc 1 1
    else
      fodon 0
    fi
    sleep 1
  done ) &
log "state loop started (fod support only while locked)"

X1=48100; X2=71900; Y1=227200; Y2=251000
while true; do
  EV=$(grep -A6 "synaptics_tcm_touch" /proc/bus/input/devices 2>/dev/null | grep -o "event[0-9]*" | head -1)
  [ -n "$EV" ] || EV=event7
  EV=/dev/input/$EV
  log "using $EV"
  id=ffffffff; x=0; y=0; pressed=0
  LK=$(cat $ST 2>/dev/null)
  /system/bin/getevent -lt "$EV" | while IFS= read -r line; do
    line=${line%"${line##*[! ]}"}
    case "$line" in
      *ABS_MT_TRACKING_ID*) id=${line##* } ;;
      *ABS_MT_POSITION_X*) v=${line##* }; [ -n "$v" ] && x=$((0x$v)) ;;
      *ABS_MT_POSITION_Y*) v=${line##* }; [ -n "$v" ] && y=$((0x$v)) ;;
      *SYN_REPORT*)
        if [ "$id" = "ffffffff" ]; then
          if [ $pressed -eq 1 ]; then
            extc 4 0
            pressed=0
            log "release"
          fi
        else
          if [ $pressed -eq 0 ] && [ $x -ge $X1 ] && [ $x -le $X2 ] && [ $y -ge $Y1 ] && [ $y -le $Y2 ]; then
            if [ "$LK" = "1" ]; then
              W=$(dumpsys power 2>/dev/null | grep -m1 'mWakefulness=' | cut -d= -f2)
              if [ "$W" = "Awake" ]; then
                extc 4 1
                log "press x=$x y=$y (locked, awake)"
              else
                log "press x=$x y=$y (locked, wake=$W -> wake screen)"
                /system/bin/input keyevent KEYCODE_WAKEUP >/dev/null 2>&1
                sleep 0.35
                extc 4 0
                extc 4 1
                log "re-triggered capture after wake"
              fi
              pressed=1
            fi
          fi
        fi ;;
    esac
  done
  log "getevent exited; restarting"
  sleep 1
done

