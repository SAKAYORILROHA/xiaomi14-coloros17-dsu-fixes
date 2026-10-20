# Xiaomi 14 · ColorOS 17 移植版 · DSU 修复集

> 把一台 **Xiaomi 14（houji / SM8650）** 上跑的 **ColorOS 17 移植 ROM（DSU 方式启动）** 的
> **AOD 熄屏显示、小米快充、屏下指纹** 三个大坑修到可用的补丁集。
> 全程**不重启整机**（DSU 一重启就回原系统），只重启过 SystemUI / 触摸 HAL / 充电 HAL。

---

## 一、适用环境

| 项目 | 值 |
|---|---|
| 机型 | Xiaomi 14（houji，SM8650） |
| 系统 | ColorOS 17 移植版（props 伪装 OnePlus，Android 17 / SDK 37） |
| 启动方式 | DSU（`ro.gsid.image_running=1`，`ro.gsid.dsu_slot=dsu`） |
| Root | KernelSU（uid=0，`u:r:ksu:s0`），SELinux permissive |
| 分区 | vendor = 小米（`qcom-battery`、`xiaomi_touch.ko`）；odm = ColorOS + 小米 HAL 混合 |
| 指纹 HAL | 小米 `mfp-daemon`（汇顶 Goodix 光学屏下） |
| 触摸 HAL | `vendor.xiaomi.hw.touchfeature.ITouchFeature/default` |

> 这套补丁**只对"ColorOS 框架 + 小米 HAL"这种混合移植 ROM 有意义**。
> 纯小米系统 / 纯 ColorOS 设备不需要。

---

## 二、修复了什么（问题 → 原因 → 方案）

### 1. AOD 只有小钟、亮一会儿就灭

| | |
|---|---|
| 现象 | 熄屏后只有一个小时钟，过一会儿整个 AOD 熄灭；插 USB 时屏幕还会每 10~16 秒自己亮 |
| 原因 | `mAlwaysOnEnabled=false`（全天候显示没开）；ColorOS 的全屏（全景）AOD 需要多个开关；`screensaver_activate_on_dock` 把 USB 当成 dock |
| 方案 | 写入 `doze_always_on=1`、`full_screen_aod=1`、`panoramic_aod_enable=1`、`Setting_AodState=2` 等；关闭 `screensaver_*` |
| 文件 | `scripts/apply_all.sh` 第 1~2 步 |

### 2. 小米快充失效（90W 变成普通充电）

| | |
|---|---|
| 现象 | 插充电器不走快充，`dumpsys battery` 里 `ChargeFastCharger: false` |
| 原因 | ColorOS 的 `/odm/bin/hw/vendor.oplus.hardware.charger-V6-service` 是 Rust binder 写的，只认 `ro.build.version.sdk <= 36`，而本机是 37 → 启动即崩：`Abort message: 'default: Unsupported Android SDK version: 37'`，死循环重启 |
| 方案 | 开机（`post-fs-data`）临时把 `ro.build.version.sdk` 设成 36，拉起 `oplus_charger_hal_service`，然后还原 37；`service.sh` 里带看门狗，HAL 掉了就再拉一次 |
| 结果 | `dumpsys battery` → `ChargeFastCharger: true, ChargerTechnology: 2` |
| 文件 | `modules/dsufix/post-fs-data.sh`、`modules/dsufix/service.sh`、`scripts/device_scripts/chg_fix1.sh` |

### 3. 屏下指纹完全不能用（录入没反应 / 解锁失败）

这是最复杂的一块，分四层：

#### 3.1 指纹 HAL 采不到图（录入界面毫无反应）

| | |
|---|---|
| 原因 | ColorOS 的指纹框架只走标准 AIDL，而小米 `mfp-daemon` 需要厂商扩展命令 `vendor.xiaomi.hardware.fingerprintextension.IXiaomiFingerprint.extCmd()`：<br>`cmd=1` 触摸控制、`cmd=2` colorfade、`cmd=3` powermode、`cmd=4` 手指按下/抬起 |
| 方案 | 写一个桥接守护进程：读 `/dev/input/event7`（`synaptics_tcm_touch`）原始触摸事件，命中屏幕底部指纹矩形时发 `extCmd(4,1/0)`；并在锁屏时把触摸 HAL 置于 `support fod=1`（`setModeValue(0,10,1)`），让 THP 在真实触摸时写 `/sys/class/touch/touch_dev/fod_press_status` → HAL 收到 `SYS_NODE_EVENT_FINGER_DOWN` → `setLocalHBM 2`（打光）→ `fod capture start` |
| 文件 | `modules/fodbridge/` |

#### 3.2 锁屏不显示指纹图标 / 没有按压动画 / 录入没有进度

| | |
|---|---|
| 原因 | ColorOS SystemUI 的 `haveFp()` = `KeyguardFeatureOption.isSupportUdfps() && FingerSwitchHelper.isFingerprintUnlockEnable()`，后者读 secure 设置 `oplus_customize_fingerprint_unlock_switch`，本机原来是 **null** |
| 方案 | 写入 `oplus_customize_fingerprint_unlock_switch=1`、`oplus_customize_fingerprint_unlock_enter_desktop=1`、`fingerprint_enabled=1` |
| 结果 | `initFpInfo fpIconShouldShowOnKeyguard=1`、`OnScreenFingerprintIcon isOnScreen=true`、解锁成功 |
| 文件 | `scripts/apply_all.sh` 第 3 步 |

#### 3.3 指纹图标位置和传感器错位

| | |
|---|---|
| 原因 | 传感器实际中心 (600, 2391)，图标默认位置偏下 |
| 方案 | `persist.vendor.fingerprint.optical.iconlocation=280`、`sensorlocation=600::2391`、`fingerprint_icon_margin_bottom=170` |

#### 3.4 熄屏状态下按指纹区不能解锁

| | |
|---|---|
| 原因 | 进入 AOD（Dream）时 ColorOS 调 `handleDreamingStateChanged → stopListeningForFingerprint`，把指纹监听停掉；同时 AOD 上的指纹图标被 OPlus SurfaceFlinger 隐藏 → 熄屏时既没图标也没认证会话 |
| 方案 | 桥接在**熄屏**时检测指纹区触摸 → `input keyevent KEYCODE_WAKEUP` 点亮屏幕 → 等 ~350ms → 补一次 `extCmd(4,0)+(4,1)` 触发采图 |
| 文件 | `history/fodbridge_v4.sh` 起的版本（当前 `modules/fodbridge/fodbridge.sh` 是 v7） |

### 4. 其它副作用修复

| 问题 | 方案 |
|---|---|
| 插 USB 被当 dock，屏幕每 10~16s 自亮 | 关闭 `screensaver_activate_on_dock` / `screensaver_enabled` |
| 指纹设置重启后丢失 | `modules/dsufix/service.sh` 开机重放 |
| **滑动变点击/长按**（踩坑记录） | `support fod` **不要常驻**、`extCmd(1,1)` **不要 1 秒一次**（会让触摸面板反复进 doze 模式，只报按下/抬起不报移动）。使用 `history/fodbridge_v1.sh` 的最小集合：只发 `extCmd(4)` + 每 30s 一次 `extCmd(1,1)` |

---

## 三、目录结构

```
.
├─ README.md                       ← 本文件
├─ modules/                        ← KernelSU 模块（可整目录打包成 zip 安装）
│  ├─ fodbridge/                   ← 指纹桥接
│  │  ├─ module.prop
│  │  ├─ service.sh                ← 只在 ColorOS（ro.build.version.oplusrom 非空）时启动
│  │  └─ fodbridge.sh              ← 桥接守护进程
│  └─ dsufix/                      ← 开机自愈
│     ├─ module.prop
│     ├─ post-fs-data.sh           ← 开机临时 SDK=36（给充电 HAL）
│     └─ service.sh                ← 还原 SDK、写 AOD/指纹设置、充电 HAL 看门狗
├─ scripts/
│  ├─ apply_all.sh                 ← 一键重放全部设置类修复（幂等）
│  └─ device_scripts/              ← 从设备提取的单项修复/排查脚本
│     ├─ chg_fix1.sh               ← 充电 HAL 修复
│     ├─ fp_switch.sh              ← 锁屏指纹图标开关
│     ├─ sfprops.sh                ← SurfaceFlinger 指纹 AOD 属性
│     ├─ set_alwayson.sh           ← AOD 常亮
│     ├─ restartui.sh              ← 重启 SystemUI
│     ├─ snapshot.sh               ← 抓指纹状态快照
│     └─ touchsvc.sh / isolate.sh / stoptouch.sh / setfod.sh / fodpersist.sh  ← 触摸故障处理
├─ history/                        ← 桥接全部版本（v1 触摸正常，v3+ 有触摸问题，别直接用）
│  ├─ fodbridge_v1.sh ~ fodbridge_v7.sh
└─ docs/steps/                     ← 完整排查记录（00~14）
```

---

## 四、使用教程

### 0. 前置条件

- DSU 里已能跑 ColorOS 17 移植版，且 **KernelSU 可用**（`adb shell su -c id` → `uid=0`）
- `adb` 能连上（`adb devices`）
- SELinux 为 permissive（`adb shell getenforce` → `Permissive`；本移植版默认就是）
- **不要重启整机**：DSU 重启会回原系统，本文所有操作都不需要重启

### 1. 应用设置类修复（AOD / 指纹图标 / 图标位置 / 充电 HAL / 启动桥接）

```bash
adb push scripts/apply_all.sh /data/local/tmp/
adb shell su -c "sh /data/local/tmp/apply_all.sh"
```

`apply_all.sh` 会做：

```
1) AOD 全屏 + 全天候常亮
2) 关闭 dock/sleep 屏保
3) 指纹图标位置 + 打开锁屏指纹图标（oplus_customize_fingerprint_unlock_switch=1）
4) 修复充电 HAL（SDK 临时 36 → 重启 oplus_charger_hal_service → 还原 37）
5) 启动指纹桥接
```

### 2. 安装 KernelSU 模块（开机持久化）

```bash
adb push modules/fodbridge modules/dsufix /data/local/tmp/
adb shell su -c "cp -r /data/local/tmp/fodbridge /data/local/tmp/dsufix /data/adb/modules/ && chmod 755 /data/adb/modules/fodbridge/*.sh /data/adb/modules/dsufix/*.sh"
```

或者：把 `modules/` 下的两个目录分别打包成 zip，用 KernelSU 管理器从本地安装（模块结构已符合规范）。

> 模块生效需要**下一次开机**；本次可先用第 3 步手动拉起桥接。

### 3. 手动拉起指纹桥接（不重启整机）

```bash
adb shell su -c "pkill -f fodbridge.sh"
adb shell su -c "setsid sh /data/adb/modules/fodbridge/fodbridge.sh </dev/null >/dev/null 2>&1 &"
adb shell su -c "tail -5 /data/local/tmp/fodbridge.log"     # 看到 "hal ready" 即成功
```

### 4. 验证

```bash
# 指纹状态：count>=1 表示已录入，accept 随解锁增长
adb shell su -c "dumpsys fingerprint | head -3"

# 锁屏指纹图标开关（应为 1）
adb shell su -c "settings get secure oplus_customize_fingerprint_unlock_switch"
adb shell su -c "settings get global fingerprint_icon_info"     # fpIconShouldShowOnKeyguard=1

# 快充
adb shell su -c "getprop init.svc.oplus_charger_hal_service; dumpsys battery | head -9"
# 期望 running + ChargeFastCharger: true

# AOD 全天候
adb shell su -c "dumpsys power | grep mAlwaysOnEnabled"

# 桥接是否在跑
adb shell su -c "ps -A | grep fodbridge"
```

### 5. 录入指纹

- 设置 → 指纹 → 添加指纹
- **忽略界面上"转圈滑动手指 / 触摸电源键"的文案**（移植 ROM 的侧边指纹文案 Bug）
- 用指腹**按住屏幕底部正中约 2 秒**，等滴一声再抬起；每个位置重复 2~3 次

### 6. 使用建议（识别率相关）

- 每次按完等 **2~3 秒**再按（HAL 采图有重试节流，期间按压不会打光）
- 指腹平贴、覆盖整个传感器区（离底边 1.2~1.7cm）
- 同一根手指多录 1~2 枚，HAL 取最佳匹配

---

## 五、原理速览（指纹桥接）

```
ColorOS 指纹框架 ──AIDL──> BiometricService ──> mfp-daemon（小米 HAL）
                                                   ▲
                                      extCmd(4)    │   SYS_NODE_EVENT_FINGER_DOWN
                                                   │        ▲
fodbridge.sh ──读 /dev/input/event7───────────────┘        │
     │  命中指纹矩形 x/y                                       │
     └──service call ...IXiaomiFingerprint 1 4 1/0 ──────────┘
                                     ▲
   锁屏时：service call ...ITouchFeature 9 0 10 1   → THP 写 fod_press_status
```

关键日志（正常工作时）：

```
mfp-daemon: checkFodTouchStatus FP:1 gxzwAnim:1 colorfade:0 lockoutmode:0 powermode:0 TouchEnable:1
mfp-daemon: [threadLoop] SYS_NODE_EVENT_FINGER_DOWN
mfp-daemon: setLocalHBM set local hbm:2
mfp-daemon: fod high brightness capture start
[GF_HAL][SZFingerprintCore]: [notifyAuthSuccess] match_score=57 image_quality=25
```

---

## 六、已知问题（未解决）

| 问题 | 原因 |
|---|---|
| 指纹按压动画、录入进度动画不显示 | OPlus SurfaceFlinger 把 `OnScreenFingerprintPressedIcon` / `OnScreenFingerprintDimLayer` 判为 `invisible reason=oplusIsVisible{false,fingerPrint}` + `geomCrop=[0 0 -1 -1]`，资源加载了也不合成 |
| AOD 上不显示指纹图标 | 同上 + 进入 doze 时 SystemUI 把 UDFPS 图标关掉；`persist.oplus.display.FingerprintHideAOD.disable=1` 需要重启 SF 才可能生效 |
| 识别率只有 ~50% | 缺少 ColorOS 的"采图压暗 + 局部高亮"链路（`OnScreenHighLightControl` 报 `feature = null`），环境光降低对比度，`image_quality` 只有 20~25、`match_score` 56~58 卡在阈值 |

---

## 七、卸载 / 回滚

```bash
# 停止桥接
adb shell su -c "pkill -f fodbridge.sh"

# 关掉触摸 HAL 的 FOD 模式（避免影响滑动）
adb shell su -c "service call vendor.xiaomi.hw.touchfeature.ITouchFeature/default 9 i32 0 i32 10 i32 0"
adb shell su -c "setprop ctl.restart touchfeature-service"

# 删除模块
adb shell su -c "rm -rf /data/adb/modules/fodbridge /data/adb/modules/dsufix"

# 还原指纹开关（可选）
adb shell su -c "settings delete secure oplus_customize_fingerprint_unlock_switch"
```

> ⚠️ 如果以后**删除 DSU 回到原系统**，务必先删掉 `/data/adb/modules/dsufix`
> ——它的 `post-fs-data.sh` 会在开机把 `ro.build.version.sdk` 改成 36，原系统上会被误导。

---

## 八、免责声明

- 所有操作需要 root，按本文执行导致的数据丢失、系统无法启动，作者不负责
- 不同 ROM 版本、不同机型（即使同为 SM8650）行为可能不同，`extCmd` 的语义以实测为准
- 文中命令均已在 Xiaomi 14 + ColorOS 17 移植版实测
