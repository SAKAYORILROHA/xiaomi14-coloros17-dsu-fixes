#!/system/bin/sh
# 相机诊断：在 ColorOS 移植系统上跑一遍，看是"应用问题"还是"相机 HAL 问题"
echo "=== 1) media.camera ==="
dumpsys media.camera 2>/dev/null | head -40
echo
echo "=== 2) camera services ==="
service list 2>/dev/null | grep -i camera
echo
echo "=== 3) camera 相关进程 ==="
ps -A -o PID,NAME 2>/dev/null | grep -i -E 'camera|provider'
echo
echo "=== 4) 最近的相机错误 ==="
logcat -d -b all -v time 2>/dev/null | grep -i -E 'CameraService|CameraProvider|camera.*(error|fail|crash|exception)' | tail -40
echo
echo "=== 5) camera 权限文件 ==="
ls /system/etc/permissions 2>/dev/null | grep -i camera
ls /product/etc/permissions 2>/dev/null | grep -i camera
echo
echo "=== 6) 已安装相机应用 ==="
pm list packages 2>/dev/null | grep -i camera
