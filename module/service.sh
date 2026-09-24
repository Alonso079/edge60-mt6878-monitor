#!/system/bin/sh
MODDIR=${0%/*}
STATUS=/metadata/edge60_wlan_monitor/last-boot-status
if [ -r /sys/module/wlan_drv_gen4m_6878/parameters/monitor_nl80211_ready ]; then
    printf '%s\n' resident > "$STATUS"
else
    printf '%s\n' stock-fallback > "$STATUS"
fi
chmod 0644 "$STATUS"
chcon u:object_r:vendor_file:s0 "$STATUS" 2>/dev/null || true
