#!/system/bin/sh
# 只在本移植系统（ColorOS，oplusrom 非空）上执行；原厂系统直接跳过。
[ -z "$(getprop ro.build.version.oplusrom)" ] && exit 0
# Runs early (post-fs-data). The ported OPlus charger HAL (Rust binder) aborts on SDK 37,
# so present SDK 36 while the vendor HALs are being started.
resetprop ro.build.version.sdk 36
