# Edge 60 MT6878 resident monitor module

Target: Motorola Edge 60 `scout`, firmware `W1VCS36H.14-20-19-7`.

At `early-init`, this KernelSU module overrides the existing `insmod_sh`
service while retaining Motorola's loader executable and SELinux domain. It
loads the stock module lists in their original order, inserts the ABI-matched
resident WLAN driver at the original WLAN slot, and immediately requests the
stock module name as a fail-safe. If resident insertion fails, stock is loaded.

After reboot, verify:

```sh
su -c 'cat /sys/module/wlan_drv_gen4m_6878/parameters/monitor_nl80211_ready'
su -c '/data/adb/modules/edge60_wlan_monitor/tools/mtk-wifi status'
```

The mode switcher keeps the driver resident. It never calls `rmmod` or `insmod`:

```sh
su -c '/data/adb/modules/edge60_wlan_monitor/tools/mtk-wifi monitor 2412'
su -c '/data/adb/modules/edge60_wlan_monitor/tools/capture.sh /data/local/tmp/capture.pcap'
su -c '/data/adb/modules/edge60_wlan_monitor/tools/mtk-wifi normal'
```

Basic injection validation uses a harmless broadcast Probe Request. The tool
sends a standard minimal Radiotap header followed by an IEEE 802.11 frame:

```sh
su -c '/data/adb/modules/edge60_wlan_monitor/tools/mtk-wifi monitor 2412'
su -c '/data/adb/modules/edge60_wlan_monitor/tools/test_inject wlan0'
su -c '/data/adb/modules/edge60_wlan_monitor/tools/mtk-wifi normal'
```

Driver log messages prove that the packet passed validation and reached the
hardware TX path. Confirming over-the-air transmission still requires another
radio capturing on the same channel.
