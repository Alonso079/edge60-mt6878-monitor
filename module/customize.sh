#!/system/bin/sh

case "$(getprop ro.build.fingerprint)" in
    *motorola/scout*W1VCS36H.14-20-19-7*) ;;
    *) abort "Unsupported firmware: this package is only for scout W1VCS36H.14-20-19-7" ;;
esac

TARGET=/metadata/edge60_wlan_monitor
MODULE_SOURCE="$MODPATH/payload/wlan_drv_gen4m_6878_resident.ko"
MODULE_TARGET="$TARGET/wlan_drv_gen4m_6878_resident.ko"
MODULE_TEMP="$TARGET/.wlan_drv_gen4m_6878_resident.ko.new"
CONFIG_SOURCE="$MODPATH/payload/init.insmod.mt6878.cfg"
CONFIG_TARGET="$TARGET/init.insmod.mt6878.cfg"
CONFIG_TEMP="$TARGET/.init.insmod.mt6878.cfg.new"

mkdir -p "$TARGET" || abort "Could not create $TARGET"
rm -f "$MODULE_TEMP" "$CONFIG_TEMP" || abort \
    "Could not clear stale staging files in $TARGET"

cp -f "$MODULE_SOURCE" "$MODULE_TEMP" || {
    rm -f "$MODULE_TEMP"
    abort "No space to stage the resident WLAN module in /metadata"
}
cmp -s "$MODULE_SOURCE" "$MODULE_TEMP" || {
    rm -f "$MODULE_TEMP"
    abort "Resident WLAN module verification failed"
}
cp -f "$CONFIG_SOURCE" "$CONFIG_TEMP" || {
    rm -f "$MODULE_TEMP" "$CONFIG_TEMP"
    abort "Could not stage the resident WLAN configuration"
}
cmp -s "$CONFIG_SOURCE" "$CONFIG_TEMP" || {
    rm -f "$MODULE_TEMP" "$CONFIG_TEMP"
    abort "Resident WLAN configuration verification failed"
}

chown 0:0 "$TARGET" "$MODULE_TEMP" "$CONFIG_TEMP" || abort \
    "Could not set resident WLAN ownership"
chmod 0755 "$TARGET" || abort "Could not set $TARGET permissions"
chmod 0644 "$MODULE_TEMP" "$CONFIG_TEMP" || abort \
    "Could not set resident WLAN file permissions"
chcon u:object_r:vendor_file:s0 "$TARGET" "$MODULE_TEMP" "$CONFIG_TEMP" || \
    abort "Could not label resident WLAN files"
sync
mv -f "$CONFIG_TEMP" "$CONFIG_TARGET" || abort \
    "Could not activate the resident WLAN configuration"
mv -f "$MODULE_TEMP" "$MODULE_TARGET" || abort \
    "Could not activate the resident WLAN module"
sync
chmod 0755 "$MODPATH"/tools 2>/dev/null || true
chmod 0755 "$MODPATH"/tools/* 2>/dev/null || true
chmod 0755 "$MODPATH"/*.sh 2>/dev/null || true

ui_print "- Atomically staged and verified resident WLAN payload in /metadata"
ui_print "- Configured executable permissions for tools"
ui_print "- Stock WLAN remains the automatic insertion fallback"
