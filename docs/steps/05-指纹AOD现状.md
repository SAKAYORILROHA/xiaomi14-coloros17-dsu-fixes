# 步骤 05：指纹 / AOD 指纹图标现状

## 当前状态

- `/dev/input/event7` = `synaptics_tcm_touch`（触摸屏），指纹 HAL = Xiaomi `mfp-daemon`（/odm/bin/hw）
- 光学指纹属性齐全（ROM 默认 + 本次对齐）：
  - `persist.vendor.fingerprint.sensor_type=optical`
  - `persist.vendor.fingerprint.optical.support=1`
  - `persist.vendor.fingerprint.optical.iconlocation=280`（原 335，已按上一轮实测对齐）
  - `persist.vendor.fingerprint.optical.sensorlocation=600::2391`
  - `persist.vendor.sys.fp.fod.location.X_Y=491,2282`、`size=218,218`
- `dumpsys fingerprint`：`count=0`（**这个 DSU 里没有任何已录指纹**）→ AOD 上不会出现指纹图标，这是正常的
- 已安装 `fodbridge`（KernelSU 模块 + 常驻进程），用于把屏幕底部触摸翻译成小米私有 `extCmd(4)`，
  这是 ColorOS 框架下小米 HAL 能触发采图（`fod high brightness capture start`）的唯一方式
  - 进程：`/data/adb/modules/fodbridge/fodbridge.sh`（running）
  - 日志：`/data/local/tmp/fodbridge.log`（能看到 press x/y 坐标）
- 设备**有 6 位锁屏密码**（`输出密码` 页，`设备已锁定`）→ 远程无法解锁，需要机主自己解锁

## 录入时遇到的问题（实测）

- 启动 `android.settings.FINGERPRINT_SETUP` → 进入 `com.oplus.settings.feature.fingerprint.NewFingerEnrollActivity`
- 页面文字是 **「转圈滑动手指 / 触摸电源键，按照引导持续滑动」**（侧边电源键指纹的引导页），
  而本机是屏下光学指纹 → 这是移植 ROM 的 Settings 资源/判定问题
- 框架内部其实已经按屏下指纹走：`SensorOverlays: showUdfpsOverlay : 5, 2`、`UdfpsController: showUdfpsOverlay`、
  `OplusFingerprintSupportUtil: getSupportSensorType mSensorType:optical`
- 手指按屏幕底部时，HAL 收到 `extCmd: cmd=4`、`HandleFodTouchCtl:1`、`setFodTouchCoordinatePollCtrl`，
  但走的是 `AUTH_STOP`（认证）分支，**没有 `fingerprint_enroll` 采图**，而且框架报
  `UdfpsController: Null request when onAcquired` → 录入会话没真正挂到 overlay 上
- 结论：**录入页 UI 是侧边指纹版**，光学录入在这套 Settings 里走不通；AOD 指纹图标必须先有指纹才会出现

## 可选的下一步（需要机主配合/同意）

1. 机主自己解锁后，在设置里试试「指纹、面部与密码 → 指纹」能否直接进入屏下录入页
2. 若仍是这个引导页：需要对 Settings（`NewFingerEnrollActivity` / 指纹特性判定）做类似 SystemUI 的静态补丁，
   或者用上一轮验证过的方式：`persist.*` 光学属性 + `setprop ctl.restart zygote`（框架软重启，不重启整机，但会杀掉所有 App）
3. 已装好的 fodbridge 保持运行，一旦录入通道打通即可直接录
