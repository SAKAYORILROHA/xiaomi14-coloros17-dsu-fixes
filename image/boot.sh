#!/system/bin/sh
# dsufix 开机引导脚本（由 /system/etc/init/dsufix.rc 以 root 调用）
# 作用：等系统启动完成 -> 把 KernelSU 模块装进 /data/adb/modules -> 应用全部修复
export PATH=/data/adb/ksu/bin:/data/adb/magisk:/system/bin:/system/xbin:/sbin

LOG=/data/local/tmp/dsufix_boot.log
mkdir -p /data/local/tmp 2>/dev/null
exec >>"$LOG" 2>&1
echo "===== dsufix boot $(date) ====="

D=/system/etc/dsufix
[ -d "$D" ] || { echo "!! payload dir missing"; exit 1; }

# 0) 只在本移植系统上执行（原厂 HyperOS 不做任何事）
ROM=$(getprop ro.build.version.oplusrom)
echo "oplusrom=$ROM"
if [ -z "$ROM" ]; then
  echo "not ColorOS port, skip"
  exit 0
fi

# 1) 等系统启动完成（最多 2 分钟）
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ $i -lt 60 ]; do
  sleep 2
  i=$((i+1))
done
echo "boot_completed=$(getprop sys.boot_completed) after $((i*2))s"
sleep 10

# 2) 安装 KernelSU 模块（不依赖 KSU 是否就绪：先建目录放进去，KSU 初始化后会自己加载）
mkdir -p /data/adb/modules 2>/dev/null
for m in fodbridge dsufix; do
  if [ -d "$D/modules/$m" ]; then
    rm -rf "/data/adb/modules/$m" 2>/dev/null
    cp -r "$D/modules/$m" "/data/adb/modules/$m" 2>/dev/null
    chmod 755 "/data/adb/modules/$m"/*.sh 2>/dev/null
    chmod 644 "/data/adb/modules/$m"/module.prop 2>/dev/null
    echo "module installed: $m"
  fi
done

# 2.5) 再等 resetprop（KSU 用户态可能很晚才就绪，最多再等 10 分钟）
i=0
while [ ! -x /data/adb/ksu/bin/resetprop ] && [ $i -lt 300 ]; do
  sleep 2
  i=$((i+1))
done
echo "resetprop ready after $((i*2))s (present=$([ -x /data/adb/ksu/bin/resetprop ] && echo yes || echo no))"


# 3) 应用修复（AOD / 指纹开关 / 图标位置 / 充电 HAL / 启动桥接）
sh "$D/apply_all.sh"

echo "===== dsufix boot done $(date) ====="
