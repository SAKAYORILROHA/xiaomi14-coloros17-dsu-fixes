#!/system/bin/sh
# Runs early (post-fs-data). The ported OPlus charger HAL (Rust binder) aborts on SDK 37,
# so present SDK 36 while the vendor HALs are being started.
resetprop ro.build.version.sdk 36
