# Xiaomi 14 · ColorOS 17 移植版 · DSU 修复集

> 设备：**Xiaomi 14（houji / SM8650，23127PN0CC）**
> 系统：**ColorOS 17 移植 ROM（DSU 方式启动）**，Android 17 / SDK 37，KernelSU
> 内容：**AOD 全屏全天候、小米快充、屏下指纹** 三大坑的修复补丁，以及一路踩坑的完整分析
> 全程**不重启整机**（DSU 一重启就回原系统），只重启过 SystemUI / 触摸 HAL / 充电 HAL

---

## 目录

- [一、修好了什么](#一修好了什么)
- [二、快速使用](#二快速使用)
- [三、各修复的原理](#三各修复的原理)
  - [3.1 AOD 全屏全天候](#31-aod-全屏全天候)
  - [3.2 小米快充（充电 HAL 崩在 SDK 37）](#32-小米快充充电-hal-崩在-sdk-37)
  - [3.3 屏下指纹](#33-屏下指纹)
- [四、指纹理的四个关键结论](#四指纹里的四个关键结论)
- [五、实测数据](#五实测数据)
- [六、已知问题（未解决）](#六已知问题未解决)
- [七、目录结构](#七目录结构)
- [八、卸载 / 回滚](#八卸载--回滚)
- [九、免责声明](#九免责声明)

---

## 一、修好了什么

| # | 问题 | 修复 | 关键文件 |
|---|---|---|---|
| 1 | AOD 只有小钟、亮一会儿就灭；插 USB 每 10~16s 自亮 | 全屏（全景）AOD + 全天候常亮；关 dock/sleep 屏保 | `scripts/apply_all.sh` |
| 2 | 小米快充失效（`ChargeFastCharger: false`） | 充电 HAL 崩在 `Unsupported Android SDK version: 37`，用 `resetprop` 临时 SDK 36 拉起后还原 37 + 看门狗 | `modules/dsufix/`、`scripts/chg_fix1.sh` |
| 3 | 指纹完全不能用（录入没反应 / 解锁失败） | 桥接把屏幕底部触摸翻译成小米 HAL `extCmd(4)`；补 `colorfade/powermode`；打开 ColorOS 锁屏指纹开关 | `modules/fodbridge/`（v8）、`scripts/fp_setup.sh` |
| 4 | 锁屏不显示指纹图标 / 没有按压动画 / 录入没有进度 | secure 设置 `oplus_customize_fingerprint_unlock_switch=1`（SystemUI `haveFp()` 的总闸） | `scripts/apply_all.sh`、`scripts/fp_switch.sh` |
| 5 | 指纹图标与传感器错位 | `iconlocation=280`、`sensorlocation=600::2391`、`margin=170` | `scripts/apply_all.sh` |
| 6 | 触摸只能点、不能滑动（**踩坑**） | 桥接**不能**常驻 `support fod`、**不能** 1 秒一次 `extCmd(1,1)` | `history/fodbridge_v1.sh`、v8 |
| 7 | ColorOS 相机被误换成 MiuiCamera 后无法使用 | 删掉误放的 MiuiCamera，装开源 CameraX 相机 | 见 [docs/analysis](docs/analysis) |

---

## 二、快速使用

### 前置条件

- DSU 里已跑起 ColorOS 17 移植版，**KernelSU 可用**（`adb shell su -c id` → `uid=0`）
- `adb` 可用；SELinux permissive（`getprop ro.boot.selinux`）
- **不要重启整机**：下面所有操作都不需要重启

### 方式 A：用系统镜像里的载荷（推荐，烧进镜像后开自动生效）

镜像内位置：

```
/system/etc/dsufix/            脚本 + 模块 + 一键脚本
/system/etc/init/dsufix.rc     init 服务，开机执行 boot.sh
```

开机自动流程：

```
sys.boot_completed → boot.sh
  1) 校验 ro.build.version.oplusrom（非 ColorOS 直接退出）
  2) mkdir -p /data/adb/modules + 安装 fodbridge / dsufix 模块（不等 KSU）
  3) 等 resetprop 最多 10 分钟
  4) 执行 apply_all.sh：AOD / 指纹开关 / 图标位置 / 充电 HAL / 启动桥接
```

### 方式 B：手动一键修复

```bash
# 全部修复
adb shell su -c "sh /system/etc/dsufix/apply_all.sh"

# 只修指纹（推荐）
adb shell su -c "sh /system/etc/dsufix/scripts/fp_setup.sh"

# 只修充电
adb shell su -c "sh /system/etc/dsufix/scripts/chg_fix1.sh"
```

### 验收

```bash
# 指纹：count 应随录入增长，accept 随解锁增长
adb shell su -c "dumpsys fingerprint | head -3"

# 采图条件：希望 powermode:0
adb shell su -c "logcat -d -b all -v time | grep checkFodTouchStatus | tail -1"

# 快充
adb shell su -c "getprop init.svc.oplus_charger_hal_service"    # running
adb shell su -c "dumpsys battery | grep -E 'ChargeFastCharger|ChargerTechnology'"  # true / 2

# AOD
adb shell su -c "dumpsys power | grep mAlwaysOnEnabled"        # true
```

---

## 三、各修复的原理

### 3.1 AOD 全屏全天候

```
settings put secure doze_always_on 1
settings put secure full_screen_aod 1
settings put secure panoramic_aod_enable 1
settings put secure oplus_keyguard_panoramic_aod_support 1
settings put secure Setting_AodState 2
settings put secure Setting_AodEnable 1
settings put secure Setting_AodSwitchEnable 1

# 关掉屏保，否则插 USB 会被当 dock 每 10~16 秒自亮
settings put secure screensaver_enabled 0
settings put secure screensaver_activate_on_dock 0
settings put secure screensaver_activate_on_sleep 0
```

### 3.2 小米快充（充电 HAL 崩在 SDK 37）

**现象**

```
Abort message: 'default: Unsupported Android SDK version: 37'
init.svc.oplus_charger_hal_service = restarting
dumpsys battery: ChargeFastCharger: false, Max charging current: 500000
```

**原因**：odm 里的 `/odm/bin/hw/vendor.oplus.hardware.charger-V6-service` 是 ColorOS 16 的 Rust HAL，只认 SDK ≤ 36。

**修复**（`modules/dsufix/post-fs-data.sh` + `service.sh` + `scripts/chg_fix1.sh`）

```sh
resetprop ro.build.version.sdk 36
setprop ctl.stop oplus_charger_hal_service
setprop ctl.start oplus_charger_hal_service
sleep 3
resetprop ro.build.version.sdk 37
```

外加看门狗：`service.sh` 每 15 秒检查一次，HAL 掉线就重复上面的动作（实测掉线 12 秒内自愈）。

### 3.3 屏下指纹

**(a) HAL 采不到图 → 桥接**

ColorOS 指纹框架只走标准 AIDL，小米 `mfp-daemon` 需要厂商扩展命令：

| cmd | 含义 |
|---|---|
| 1 | 触摸控制（TouchEnable） |
| 2 | colorfade |
| 3 | powermode |
| 4 | 手指按下/抬起 |

桥接 `fodbridge.sh` 读 `/dev/input/event7`（`synaptics_tcm_touch`），命中屏幕底部指纹矩形时发 `extCmd(4,1/0)`。

**(b) 采图条件（v8 的关键修复）**

HAL 打日志 `checkFodTouchStatus`，六个条件必须全对：

```
FP:1 gxzwAnim:1 colorfade:0 lockoutmode:0 powermode:0 TouchEnable:1
```

其中 **`powermode` 必须是 0**。框架/息屏会把它置成 2，v1 桥接从不发 `extCmd(3,0)` → 一直 `powermode:2` → **不采图、不打光**。

v8 的修法：启动时 + **每次按压前**都补 `extCmd(2,0)` 和 `extCmd(3,0)`。

**(c) 锁屏指纹开关（ColorOS 的 UI 总闸）**

```
settings put secure oplus_customize_fingerprint_unlock_switch 1
settings put secure oplus_customize_fingerprint_unlock_enter_desktop 1
settings put secure fingerprint_enabled 1
settings put secure fingerprint_icon_margin_bottom 170
setprop persist.vendor.fingerprint.optical.iconlocation 280
setprop persist.vendor.fingerprint.optical.sensorlocation 600::2391
```

---

## 四、指纹里的四个关键结论

1. **采图路径**：THP（触摸 HAL）在 `support fod=1` 时写 `/sys/class/touch/touch_dev/fod_press_status` → HAL 收到 `SYS_NODE_EVENT_FINGER_DOWN` → `setLocalHBM 2`（打光）→ `fod high brightness capture start` → 算法出图
2. **`powermode` 是采图的硬条件**：`2` = 不采图，`0` = 正常；v8 每次按压前补 `extCmd(3,0)`
3. **`support fod` 不能常驻**：常驻会让触摸面板只剩"按下/抬起"，滑动手势全丢 → 表现为"只能点击、不能滑动"
4. **`extCmd(1,1)` 不能 1 秒一次**：会让触摸面板反复进 doze 模式（日志刷 `thp_set_doze_mode_func:enable doze mode`），同样是"滑动变点击"；30 秒一次即可

---

## 五、实测数据

### 指纹（v8）

```
set local hbm:2                     64 次
fod high brightness capture start   64 次
dumpsys fingerprint: count=2, accept=12, reject=6, acquire=222
录入门: BiometricScheduler [Finishing] success: true
```

对比 v1：`hbm:2` 出现 **0 次**，`fod high brightness capture start` **0 次**，录入门超时（`onErrorInternal code: 3` = ERROR_TIMEOUT）

### 快充

| 状态 | 输入限流 | 协议 | 电池电流 |
|---|---|---|---|
| 改前 | 500000（0.5A，SDP） | SDP | 0.45A |
| 三个 persist 属性改后 | 6000000（6A） | **PD_PPS / pd_verifed=1** | **2.09A** |

```
persist.vendor.batteryantiaging        0      （原 2）
persist.vendor.battery.health.optimise false  （原 true）
persist.vendor.night.charge            0      （原 1）
```

> 只能到 2A 是因为电池认证：`fcc: BattAuth-2000`（ADSP 固件算的，AP 侧已写 50A）。
> 详见 [docs/analysis/充电驱动分析.md](docs/analysis/充电驱动分析.md)

---

## 六、已知问题（未解决）

| 问题 | 原因 | 证据 |
|---|---|---|
| 指纹按压/录入动画、AOD 指纹图标不显示 | OPlus SurfaceFlinger 把 `OnScreenFingerprintPressedIcon` / `DimLayer` 判为 `invisible reason=oplusIsVisible{false,fingerPrint}` + `geomCrop=[0 0 -1 -1]` | `dumpsys SurfaceFlinger` |
| 识别率约 50% | 缺 ColorOS 的"采图压暗 + 局部高亮"链路（`OnScreenHighLightControl` 报 `feature = null`），`image_quality` 20~25、`match_score` 56~58 卡阈值 | `logcat GF_HAL` |
| HyperOS 上 90W 不激活 | 电池认证 FCC 限制；AP 侧已写 50A，限制在 ADSP/PMIC 固件 | `dmesg: fcc: BattAuth-2000` |
| KPM 模块不可用 | 原厂内核没有 KernelPatch/KPM loader（`ksud kpm version` → `Inappropriate ioctl for device`） | `ksud kpm version` |

---

## 七、目录结构

```
.
├─ modules/                 KernelSU 模块（可整目录打包成 zip 安装）
│  ├─ fodbridge/            指纹桥接 v8（module.prop / service.sh / fodbridge.sh）
│  └─ dsufix/               开机自愈（post-fs-data.sh / service.sh，带 ColorOS 判断）
├─ scripts/
│  ├─ apply_all.sh          一键应用全部修复
│  ├─ fp_setup.sh           指纹一键修复（设置 + 装模块 + 重启桥接 + 验证）
│  ├─ chg_fix1.sh           充电 HAL 修复
│  ├─ fp_switch.sh          锁屏指纹开关
│  ├─ sfprops.sh            SurfaceFlinger 指纹 AOD 属性
│  ├─ set_alwayson.sh       AOD 常亮
│  ├─ cam_diag.sh           相机诊断
│  ├─ snapshot.sh           抓指纹状态快照
│  └─ setfod.sh / fodpersist.sh   ⚠ 实验脚本（会让触摸不能滑动，已加警告头）
├─ image/
│  ├─ boot.sh               开机引导（装模块 → 等 resetprop → apply_all）
│  └─ dsufix.rc             init 服务
├─ history/                 fodbridge v1~v8 全版本
└─ docs/
   ├─ steps/00~14           逐步排查记录
   └─ analysis/             充电驱动分析、内核层方案、指纹 v8 说明
```

---

## 八、卸载 / 回滚

```bash
# 停桥接
adb shell su -c "pkill -f fodbridge.sh"

# 关掉触摸 HAL 的 FOD 模式（如果被实验脚本开过）
adb shell su -c "service call vendor.xiaomi.hw.touchfeature.ITouchFeature/default 9 i32 0 i32 10 i32 0"
adb shell su -c "setprop ctl.restart touchfeature-service"

# 删模块
adb shell su -c "rm -rf /data/adb/modules/fodbridge /data/adb/modules/dsufix"

# 还原指纹开关（可选）
adb shell su -c "settings delete secure oplus_customize_fingerprint_unlock_switch"
```

> ⚠ 以后**删 DSU 回原系统**前，务必先删 `/data/adb/modules/dsufix`
> —— 它的 `post-fs-data.sh` 开机把 `ro.build.version.sdk` 改成 36，原系统上会被误导。

---

## 九、免责声明

- 所有操作需要 root；按本文执行导致的数据丢失、系统无法启动，作者不负责
- 不同 ROM 版本、不同机型（即使同为 SM8650）行为可能不同，`extCmd` 语义以实测为准
- 文中命令均已在 Xiaomi 14 + ColorOS 17 移植版实测
