#!/system/bin/sh
# FOD bridge for ColorOS-on-Xiaomi (v8)
# v8 = v1 (touch-safe minimal) + 每次按压前补 colorfade=0 / powermode=0
#   根因：mfp-daemon 采图条件里 powermode 必须是 0，但框架/息屏会把 powermode 置成 2，
#   导致 checkFodTouchStatus 一直 powermode:2 -> 不采图、不打光。
#   注意：仍然不做 support fod 常驻、不做 1 秒一次的 extCmd(1,1)（会让触摸变"只能点不能滑"）
S=vendor.xiaomi.hardware.fingerprintextension.IXiaomiFingerprint/default
LOG=/data/local/tmp/fodbridge.log
log() { echo "$(date +%H:%M:%S.%N) $*" >> "$LOG"; }
extc() { /system/bin/service call $S 1 i32 "$1" i32 "$2" >/dev/null 2>&1; }

n=0
while [ $n -lt 180 ]; do
  if /system/bin/service call $S 1 i32 0 i32 0 >/dev/null 2>&1; then break; fi
  sleep 1; n=$((n+1))
done
log "hal ready after ${n}s"

extc 2 0
extc 3 0
extc 1 1
log "init: colorfade=0 powermode=0 touchctl=1"

( while true; do extc 1 1; sleep 30; done ) &
log "touch ctl keepalive started (30s)"

X1=48100; X2=71900; Y1=227200; Y2=251000
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
            extc 4 0
            pressed=0
            log "release"
          fi
        else
          if [ $pressed -eq 0 ] && [ $x -ge $X1 ] && [ $x -le $X2 ] && [ $y -ge $Y1 ] && [ $y -le $Y2 ]; then
            W=$(dumpsys power 2>/dev/null | grep -m1 'mWakefulness=' | cut -d= -f2)
            extc 2 0
            extc 3 0
            if [ "$W" = "Awake" ]; then
              extc 4 1
              log "press x=$x y=$y (awake)"
            else
              log "press x=$x y=$y (wake=$W -> wake screen)"
              /system/bin/input keyevent KEYCODE_WAKEUP >/dev/null 2>&1
              sleep 0.35
              extc 3 0
              extc 4 0
              extc 4 1
              log "re-triggered capture after wake"
            fi
            pressed=1
          fi
        fi ;;
    esac
  done
  log "getevent exited; restarting"
  sleep 1
done
