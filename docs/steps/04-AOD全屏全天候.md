# 步骤 04：AOD 全屏全天候 修复（settings 层，无需改 SystemUI）

## 关键发现

- ColorOS 17 的 AOD 不是纯 SystemUI 渲染，图层里有 `com.oplus.aod/.activity.AodHomeActivity`，
  但实际 AOD 内容由 SystemUI 的 `AodController`（ClassicAodController / PanoramicAodController）渲染，
  布局/资源来自 AOD APK（`/product/app/Aod`）。
- 熄屏后系统状态：`mWakefulness=Dozing`，`mScreenState=DOZE_SUSPEND`，面板背光 `panel0-backlight/brightness=279`
  （亮屏 2360）→ AOD 是**真的在亮**，DOZE_SUSPEND 只是低刷/低功耗标记，不是黑屏。

## 原来为什么不是全屏/不全天候

| 现象 | 原因 |
|---|---|
| 小钟（经典 AOD），非全屏 | `Setting_AodState=0`、`full_screen_aod=0`、`panoramic_aod_enable=0`、`oplus_keyguard_panoramic_aod_support=0` |
| AOD 亮一会儿就灭 / 屏幕自己乱亮 | `doze_always_on=null` → `mAlwaysOnEnabled=false`；且插 USB 被当成 dock，`screensaver_activate_on_dock=true` 触发 Dream 循环（每 10~16s 屏亮一次） |

## 修复命令（已执行）

```
settings put secure doze_always_on 1
settings put secure full_screen_aod 1
settings put secure panoramic_aod_enable 1
settings put secure oplus_keyguard_panoramic_aod_support 1
settings put secure Setting_AodState 2
settings put secure Setting_AodEnable 1
settings put secure Setting_AodSwitchEnable 1
settings put secure screensaver_enabled 0
settings put secure screensaver_activate_on_dock 0
settings put secure screensaver_activate_on_sleep 0
```

## 实测结果

- 熄屏后截图（screencap，熄屏状态不会点亮屏幕）：
  - 修复前：整屏只有顶部中间一个 ~270x460 的小钟，lit 占比 0.69%
  - 修复后：**整屏亮起**（mean=68.8，全屏像素>8），大号时钟 + 渐隐壁纸 → 全景/全屏 AOD
- `dumpsys power`：`mAlwaysOnEnabled=true`
- 熄屏 60s 内 `mScreenState` 稳定在 DOZE_SUSPEND，不再自动亮屏；背光稳定 279
- 指纹图标：当前 `dumpsys fingerprint` count=0（DSU 里没有任何已录指纹）→ AOD 上不显示指纹图标是正常的，
  要先录入指纹（见步骤 05）
