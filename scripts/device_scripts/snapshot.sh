#!/system/bin/sh
dumpsys fingerprint > /data/local/tmp/fp_dump.txt
settings list secure | grep -i -E 'finger|aod|doze' > /data/local/tmp/fp_settings.txt
getprop | grep -i -E 'fingerprint|fod' > /data/local/tmp/fp_props.txt
echo "=== fingerprint dumpsys ==="
sed -n '1,5p' /data/local/tmp/fp_dump.txt
echo "=== settings ==="
cat /data/local/tmp/fp_settings.txt
echo "=== props ==="
cat /data/local/tmp/fp_props.txt
