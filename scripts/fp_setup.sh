#!/system/bin/sh
# 指纹一键修复（实测有效版：v8 桥接 + ColorOS 锁屏指纹开关）
# 用法：su -c "sh /system/etc/dsufix/scripts/fp_setup.sh"
#
# 做什么：
#   1. 写入 ColorOS 锁屏指纹图标/解锁开关 + 指纹图标位置
#   2. 把 v8 桥接模块装到 /data/adb/modules/fodbridge
#   3. 重启桥接（先补 colorfade/powermode，再发 extCmd(4)）
#   4. 打印验证信息
#
# 注意：不要常驻 support fod（setModeValue 0,10,1），会让触摸只剩点击、不能滑动

D=/system/etc/dsufix
M=/data/adb/modules/fodbridge
S=vendor.xiaomi.hardware.fingerprintextension.IXiaomiFingerprint/default

echo "[1/5] 写入指纹设置"
settings put secure oplus_customize_fingerprint_unlock_switch 1
settings put secure oplus_customize_fingerprint_unlock_enter_desktop 1
settings put secure fingerprint_enabled 1
settings put secure fingerprint_icon_margin_bottom 170
setprop persist.vendor.fingerprint.optical.iconlocation 280
setprop persist.vendor.fingerprint.optical.sensorlocation 600::2391
echo "  switch=$(settings get secure oplus_customize_fingerprint_unlock_switch)"

echo "[2/5] 安装/更新桥接模块（v8）"
mkdir -p /data/adb/modules
if [ -d "$D/modules/fodbridge" ]; then
  rm -rf "$M"
  cp -r "$D/modules/fodbridge" "$M"
  chmod 755 "$M"/*.sh 2>/dev/null
  chmod 644 "$M"/module.prop 2>/dev/null
  echo "  installed -> $M ($(stat -c %s $M/fodbridge.sh) B)"
else
  echo "  !! 找不到 $D/modules/fodbridge"
  exit 1
fi

echo "[3/5] 重启桥接"
for p in /proc/[0-9]*/cmdline; do
  c=$(tr '\0' ' ' < "$p" 2>/dev/null)
  case "$c" in
    *fodbridge.sh*) pid=${p#/proc/}; pid=${pid%/cmdline}; kill -9 "$pid" 2>/dev/null ;;
  esac
done
sleep 1
setsid sh "$M/fodbridge.sh" </dev/null >/dev/null 2>&1 &
sleep 4

echo "[4/5] 验证"
n=0
for p in /proc/[0-9]*/cmdline; do
  c=$(tr '\0' ' ' < "$p" 2>/dev/null)
  case "$c" in *fodbridge.sh*) n=$((n+1));; esac
done
echo "  bridge_procs=$n"
echo "  --- 桥接日志 ---"
tail -4 /data/local/tmp/fodbridge.log 2>/dev/null | sed 's/^/  /'
echo "  --- 采图条件 ---"
logcat -d -b all -v time 2>/dev/null | grep 'checkFodTouchStatus' | tail -1 | sed 's/^/  /'
echo "  --- 指纹状态 ---"
dumpsys fingerprint 2>/dev/null | sed -n '1,3p' | sed 's/^/  /'

echo "[5/5] 提示"
echo "  · 录入/解锁时用指腹按住屏幕底部正中约 1~2 秒"
echo "  · 每次按完等 2~3 秒再按（HAL 采图有重试节流）"
echo "  · 锁屏/录入界面才有认证会话，桌面上按压不会打光，属正常"
