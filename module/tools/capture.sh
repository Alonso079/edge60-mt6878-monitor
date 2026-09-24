#!/system/bin/sh
set -u

STATE_FILE=/dev/edge60-monitor-resident.active
CONCURRENT_STATE_FILE=/dev/edge60-monitor-concurrent.active
[ "$(id -u)" = 0 ] || { echo "ERROR: ejecuta con su -c" >&2; exit 1; }

if [ -f "$CONCURRENT_STATE_FILE" ] && [ -e /sys/class/net/mon0 ]; then
	INTERFACE=mon0
elif [ -f "$STATE_FILE" ]; then
	INTERFACE=wlan0
else
	echo "ERROR: monitor no está activo" >&2
	exit 1
fi

OUTPUT=${1:-/data/local/tmp/edge60-monitor.pcap}
echo "capturando $INTERFACE en $OUTPUT; Ctrl+C termina la captura"
exec tcpdump -i "$INTERFACE" -s 0 -U -w "$OUTPUT"
