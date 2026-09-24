#!/system/bin/sh

SCRIPT_DIR=${0%/*}
[ "$SCRIPT_DIR" = "$0" ] && SCRIPT_DIR=.

MODULE_NAME=wlan_drv_gen4m_6878
DRIVER_READY=/sys/module/$MODULE_NAME/parameters/monitor_nl80211_ready
MTKMON="$SCRIPT_DIR/mtkmon"
STATE_FILE=/dev/edge60-monitor-resident.active
CONCURRENT_STATE_FILE=/dev/edge60-monitor-concurrent.active
SURVEY_STATE_FILE=/dev/edge60-monitor-survey.active
WMT_DEVICE=/dev/wmtWifi

die()
{
	echo "ERROR: $*" >&2
	exit 1
}

require_root()
{
	[ "$(id -u)" = 0 ] || die "ejecuta con su -c"
}

check_device()
{
	case "$(getprop ro.build.fingerprint)" in
		*motorola/scout*W1VCS36H.14-20-19-7*) ;;
		*) die "firmware distinto de scout W1VCS36H.14-20-19-7" ;;
	esac
	[ -x "$MTKMON" ] || die "no se puede ejecutar $MTKMON"
	[ -c "$WMT_DEVICE" ] || die "no existe $WMT_DEVICE"
}

require_resident_driver()
{
	[ -r "$DRIVER_READY" ] || die \
		"el módulo cargado no es la variante nl80211 residente"
	case "$(cat "$DRIVER_READY")" in
		Y|y|1|true) ;;
		*) die "la variante residente no declara monitor nl80211 activo" ;;
	esac
}

wait_for_interface()
{
	EXPECTED=$1
	i=0
	while [ "$i" -lt 15 ]; do
		if [ "$EXPECTED" = present ] && [ -r /sys/class/net/wlan0/ifindex ]; then
			return 0
		fi
		if [ "$EXPECTED" = absent ] && [ ! -e /sys/class/net/wlan0 ]; then
			return 0
		fi
		sleep 1
		i=$((i + 1))
	done
	return 1
}

stop_android_wifi()
{
	cmd wifi set-wifi-enabled disabled >/dev/null 2>&1 || \
		svc wifi disable >/dev/null 2>&1 || true
	sleep 3
	stop wpa_supplicant 2>/dev/null || true
	stop wificond 2>/dev/null || true
	stop vendor.wifi_hal_legacy 2>/dev/null || true
	stop moto.sarwifi 2>/dev/null || true
}

start_android_wifi()
{
	start vendor.wifi_hal_legacy 2>/dev/null || true
	start wificond 2>/dev/null || true
	start wpa_supplicant 2>/dev/null || true
	start moto.sarwifi 2>/dev/null || true
	cmd wifi set-wifi-enabled enabled >/dev/null 2>&1 || \
		svc wifi enable >/dev/null 2>&1 || true
}

power_off_wifi()
{
	echo 0 > "$WMT_DEVICE" 2>/dev/null || true
	wait_for_interface absent || true
}

power_on_wifi_for_monitor()
{
	echo S > "$WMT_DEVICE" || die "WMT no pudo encender la radio"
	wait_for_interface present || die "wlanProbe no creó wlan0"
}

iface_index()
{
	cat /sys/class/net/wlan0/ifindex
}

best_effort_stop_survey()
{
	if [ -r "$SURVEY_STATE_FILE" ] &&
	   [ "$(cat "$SURVEY_STATE_FILE" 2>/dev/null)" = raised ] &&
	   [ -e /sys/class/net/p2p0 ]; then
		ip link set p2p0 down 2>/dev/null || true
	fi
	rm -f "$SURVEY_STATE_FILE"
}

best_effort_normal()
{
	best_effort_stop_survey
	if [ -r /sys/class/net/mon0/ifindex ]; then
		MON_IFINDEX=$(cat /sys/class/net/mon0/ifindex)
		ip link set mon0 down 2>/dev/null || true
		"$MTKMON" del "$MON_IFINDEX" >/dev/null 2>&1 || true
	fi
	if [ -r /sys/class/net/wlan0/ifindex ]; then
		IFINDEX=$(iface_index)
		ip link set wlan0 down 2>/dev/null || true
		"$MTKMON" iface "$IFINDEX" station >/dev/null 2>&1 || true
		ip link set wlan0 up 2>/dev/null || true
	fi
	power_off_wifi
	start_android_wifi
	rm -f "$STATE_FILE"
	rm -f "$CONCURRENT_STATE_FILE"
}
