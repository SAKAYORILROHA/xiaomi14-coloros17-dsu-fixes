# 步骤 02：熄屏实测 —— AOD 现在到底什么样

## 实测方法

- `input keyevent KEYCODE_POWER` 熄屏后，`dumpsys power` 显示 `mWakefulness=Dozing`、`dumpsys display` 显示 `mScreenState=DOZE_SUSPEND`
- 熄屏状态下 `screencap` 抓图（不会把屏幕点亮），PNG 只有 50KB → 几乎全黑
- 用 Python(PIL/numpy) 分析像素：

```
size 1200x2670
mean 1.18（几乎全黑）
lit(>8) 像素 22195 个，占比 0.69%
bbox x 462..732, y 476..938   ← 只有屏幕上方中间一个 ~270x460 的时钟
y=2200~2600 全黑              ← 指纹区域没有任何图标
```

## 结论

1. **AOD 其实已经在跑**：SurfaceFlinger 里有
   `ActivityRecord{... com.oplus.aod/.activity.AodHomeActivity t16}` 图层
2. 但现在是**「经典 AOD」小钟**（顶部一个小表盘），不是全屏全天候显示
3. 指纹图标（FOD）在 AOD 上**完全不显示**（y=2200~2600 全黑）
4. 而且 `DOZE_SUSPEND` 说明AOD 亮一小会儿就被 suspend（因为 `mAlwaysOnEnabled=false` / `doze_always_on` 未开）
5. `dumpsys power`：`mAlwaysOnEnabled=false`，`Setting_AodSwitchEnable=0`、`Setting_AodEnable=0`、`Setting_AodState=null`

→ 修复目标：① AOD 常亮（不 suspend）② 全屏（全景）AOD ③ 指纹图标显示在 AOD 上
