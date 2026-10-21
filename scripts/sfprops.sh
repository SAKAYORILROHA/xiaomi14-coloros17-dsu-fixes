#!/system/bin/sh
echo "before:"
getprop persist.sys.oplus.surfaceview_invisible
getprop persist.oplus.display.FingerprintHideAOD.disable
setprop persist.sys.oplus.surfaceview_invisible 0
setprop persist.oplus.display.FingerprintHideAOD.disable 1
echo "after:"
getprop persist.sys.oplus.surfaceview_invisible
getprop persist.oplus.display.FingerprintHideAOD.disable
