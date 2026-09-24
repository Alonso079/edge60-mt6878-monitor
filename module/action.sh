#!/system/bin/sh
MODDIR=${0%/*}
exec "$MODDIR/tools/mtk-wifi" status
