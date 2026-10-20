# 步骤 03：小米快充修复（oplus charger HAL 崩溃）

## 现象（日志证据）

`dmesg` / `logcat -b crash`：

```
Abort message: 'default: Unsupported Android SDK version: 37'
Process: /odm/bin/hw/vendor.oplus.hardware.charger-V6-service
init: Service 'oplus_charger_hal_service' received SIGABRT
init: process with updatable components 'oplus_charger_hal_service' exited 4 times in 4 minutes
```

`logcat` 每 1 秒一条：

```
libbinder.ServiceManagerCppClient: Waited one second for vendor.oplus.hardware.charger.ICharger/default
OplusBatteryServiceFeature: getIChargerService fail
OplusBatteryServiceFeature: failed to get ICharger service
```

`dumpsys battery`（修复前）：

```
Charger voltage : 0
ChargerTechnology: -1
ChargeFastCharger: false
UsbHwStatus: -1
BatteryHwStatus: -1
```

## 根因

- `/odm/bin/hw/vendor.oplus.hardware.charger-V6-service` 是 ROM 作者改的「OPLUS ICharger v11 bridge for Xiaomi」，用 Rust 写的，链接的 rust binder 库在 `ProcessState::init()` 里读
  `ro.build.version.sdk`，只认到 36，遇到本 ROM 的 **SDK 37（Android 17）** 直接 `abort()`。
- 于是 ColorOS 的 `OplusBatteryService` 永远拿不到 ICharger 服务 → 充电状态全是 0/-1（`ChargeFastCharger:false`），
  ColorOS 的充电控制/快充 UI 全部失效。
- 注意：**底层充电是内核 + 小米 qcom-battery 驱动在跑**（`/sys/class/qcom-battery/*` 节点齐全，
  `real_type=SDP`、`fastchg_mode`、`quick_charge_type`、`cp_mode` 等都在），所以慢充不是硬件问题。

## 修复（运行时，无需重启）

```
resetprop ro.build.version.sdk 36
setprop ctl.stop  oplus_charger_hal_service
setprop ctl.start oplus_charger_hal_service
```

结果：

```
init.svc.oplus_charger_hal_service=running
HAL 进程：19410 vendor.oplus.hardware.charger-V6-service（稳定运行）
OplusBatteryServiceFeature: mIChargerService = vendor.oplus.hardware.charger.ICharger$Stub$Proxy@...
dumpsys battery:
  ChargerTechnology: 2
  ChargeFastCharger: true
  UsbHwStatus: 0
```

## 副作用与后续

- `ro.build.version.sdk` 被改成 36（全局）；只影响**新启动进程**读到的 SDK_INT（已在跑的系统进程无影响）。
  为了不让 HAL 下次重启再崩，当前保留 36；后续可做 KSU 模块在开机时执行同样操作。
- 仍有 `OplusBatteryService: getDataFromHalByOldInterface` 每 60s 一条（bridge 与 ColorOS 17 的新接口不完全匹配），
  但不影响服务获取与快充标志。
- 真正验证 90W 快充需要插小米原装充电器（当前插在 PC USB 口，只能 500mA SDP）。
