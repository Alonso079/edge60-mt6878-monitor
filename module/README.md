# Edge 60 MT6878 resident monitor module

Target: Motorola Edge 60 `scout`, firmware `W1VCS36H.14-20-19-7`.

At `early-init`, this KernelSU module overrides the existing `insmod_sh` service
while retaining Motorola's loader and SELinux domain. It inserts the ABI-matched
resident WLAN driver at the original WLAN slot and requests the stock module as
a fail-safe if resident insertion fails.

After reboot, verify:

```sh
su -c 'cat /sys/module/wlan_drv_gen4m_6878/parameters/monitor_nl80211_ready'
su -c '/data/adb/modules/edge60_wlan_monitor/tools/mtk-wifi status'
```

Concurrent capture keeps Android Wi-Fi connected:

```sh
su -c '/data/adb/modules/edge60_wlan_monitor/tools/mtk-wifi concurrent'
su -c '/data/adb/modules/edge60_wlan_monitor/tools/capture.sh /data/local/tmp/concurrent.pcap'
su -c '/data/adb/modules/edge60_wlan_monitor/tools/mtk-wifi concurrent-stop'
```

Concurrent `mon0` is RX-only and receives raw management frames exposed by the
fullmac firmware. Normal data traffic remains on `wlan0` as Ethernet.

Exclusive monitor mode retains the existing injection path:

```sh
su -c '/data/adb/modules/edge60_wlan_monitor/tools/mtk-wifi monitor 2412'
su -c '/data/adb/modules/edge60_wlan_monitor/tools/test_inject wlan0'
su -c '/data/adb/modules/edge60_wlan_monitor/tools/mtk-wifi normal'
```

Never unload the WLAN module live. Use the mode tools or a cold reboot.
