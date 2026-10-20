# 步骤 01：设备与充电/AOD 现状侦察

## 充电（当前插在电脑 USB 口，非小米充电器）

- `battery/charge_type=Fast`、`status=Charging`、`current_now=-189mA`、`voltage_now=3.95V`
- `battery/uevent`：`MODEL_NAME=N3_4610mah_90w`、`CONSTANT_CHARGE_CURRENT=5350000`（5.35A，这是 90W 电池的 CC 上限）
- `usb/`：`type=USB`、`voltage_max=5V`、`current_max=500mA`、`input_current_limit=500mA`、`usb_type=Unknown [SDP] DCP CDP ACA C PD PD_DRP PD_PPS BrickID`
- `ucsi/`：`usb_type=[C] PD PD_PPS`、`current_max=3A`、`voltage_max=5V`
- 结论：现在确实只按 **SDP 500mA** 在充（插在 PC 口，正常现象），要验证 90W 快充必须插小米原装充电器
- 关键进程：`micharge-hal`（小米充电 HAL，running）与 `oplus_charger_hal_service`（ColorOS 充电 HAL，running）**同时在跑**
- ColorOS 的 `dumpsys battery` OPlus 段：`Charger voltage: 0 / ChargeFastCharger: false / ChargerTechnology: -1` → ColorOS 框架没拿到小米 HAL 的充电信息（UI 不会显示快充）

## AOD

- `doze_always_on=null`、`Setting_AodSwitchEnable=0`、`Setting_AodEnable=0`、`Setting_AodState=null`
- `dumpsys power`：`mAlwaysOnEnabled=false`、`mDreamsEnabledSetting=false`、`mDozeAfterScreenOff=true`
- `pm list features` 里没有 `oplus.software.display.aod_support` → ColorOS 判定「本机不支持 AOD」，AOD 总开关被强制关
- 屏 1200x2670、density 500

## 待办

1. 抓完整日志（已完成 35MB：`F:\C17\logs\session3\logcat_all.txt`）
2. 屏息一次，实测熄屏时是否进 doze/AOD（screencap + dumpsys）
3. 决定 AOD 修复落点：SystemUI 补丁 APK 已存在（`F:\C17\out\系统界面_强制AOD全屏.apk`），当前安装在 /system_ext 的是原版还是改版需确认
