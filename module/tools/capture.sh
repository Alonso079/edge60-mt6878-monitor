#!/system/bin/sh
set -u

STATE_FILE=/dev/edge60-monitor-resident.active
[ "$(id -u)" = 0 ] || { echo "ERROR: ejecuta con su -c" >&2; exit 1; }
[ -f "$STATE_FILE" ] || { echo "ERROR: monitor no está activo" >&2; exit 1; }

OUTPUT=${1:-/data/local/tmp/edge60-monitor.pcap}
echo "capturando en $OUTPUT; Ctrl+C termina la captura"
exec tcpdump -i wlan0 -s 0 -U -w "$OUTPUT"
