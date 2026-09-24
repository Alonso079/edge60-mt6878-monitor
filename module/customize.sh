#!/system/bin/sh

case "$(getprop ro.build.fingerprint)" in
    *motorola/scout*W1VCS36H.14-20-19-7*) ;;
    *) abort "Unsupported firmware: this package is only for scout W1VCS36H.14-20-19-7" ;;
esac

TARGET=/metadata/edge60_wlan_monitor
mkdir -p "$TARGET"
cp -f "$MODPATH/payload/wlan_drv_gen4m_6878_resident.ko" "$TARGET/"
cp -f "$MODPATH/payload/init.insmod.mt6878.cfg" "$TARGET/"
chown 0:0 "$TARGET" "$TARGET"/*
chmod 0755 "$TARGET"
chmod 0644 "$TARGET"/*
chcon u:object_r:vendor_file:s0 "$TARGET" "$TARGET"/*
chmod 0755 "$MODPATH"/tools 2>/dev/null || true
chmod 0755 "$MODPATH"/tools/* 2>/dev/null || true
chmod 0755 "$MODPATH"/*.sh 2>/dev/null || true

ui_print "- Staged resident WLAN payload in /metadata"
ui_print "- Configured executable permissions for tools"
ui_print "- Stock WLAN remains the automatic insertion fallback"
