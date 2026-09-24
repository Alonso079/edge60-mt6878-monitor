# edge60-mt6878-monitor

Monitor mode, Radiotap RX and raw IEEE 802.11 TX for the internal MediaTek
MT6878 Wi-Fi interface in the Motorola Edge 60 (`scout`). The driver remains
loaded while switching modes and now supports a second, concurrent monitor
interface.

Version 1.2.0-rc1 provides two operating models:

- `wlan0` managed plus RX-only `mon0`, both on the same physical radio;
- exclusive `wlan0` monitor mode for full capture and raw injection.

## Validated target

- Device: Motorola Edge 60 (`scout`)
- Firmware: `W1VCS36H.14-20-19-7`
- Kernel: `6.1.145-android14-11-g25baf8f7fb12`
- WLAN source: Motorola commit `2ba37a3`
- Root/module manager: KernelSU Next
- Current candidate: `1.2.0-rc1`

The installer rejects other firmware builds.

## Concurrent monitor result

Validated on the physical device:

- cfg80211 advertises one managed plus one monitor interface on one channel;
- `mon0` is created and deleted through nl80211 while `wlan0` stays associated;
- `mon0` reports `ARPHRD_IEEE80211_RADIOTAP`;
- `tcpdump` captured valid Beacons and Probe Responses as Radiotap/802.11;
- a 106-packet script-driven capture reported zero kernel drops;
- `tshark` found no malformed frames in the independently checked capture;
- changing `mon0` to a different channel while station is active is rejected;
- five create/use/delete cycles completed while station traffic continued;
- deleting `mon0` preserves the station association and IP;
- no kernel panic, BUG, driver assert or firmware reset was observed.

The fullmac firmware exposes raw management RX while associated. Normal data RX
remains firmware-translated Ethernet traffic on `wlan0`, so concurrent `mon0`
does not contain every station data frame. It is deliberately RX-only. Use
exclusive monitor mode when raw TX or the existing full monitor path is needed.

## Daily use

Concurrent capture without disconnecting Android Wi-Fi:

```sh
su -c '/data/adb/modules/edge60_wlan_monitor/tools/mtk-wifi concurrent'
su -c '/data/adb/modules/edge60_wlan_monitor/tools/capture.sh /data/local/tmp/capture.pcap'
su -c '/data/adb/modules/edge60_wlan_monitor/tools/mtk-wifi concurrent-stop'
```

Exclusive monitor and injection:

```sh
su -c '/data/adb/modules/edge60_wlan_monitor/tools/mtk-wifi monitor 2412'
su -c '/data/adb/modules/edge60_wlan_monitor/tools/capture.sh /data/local/tmp/capture.pcap'
su -c '/data/adb/modules/edge60_wlan_monitor/tools/test_inject wlan0'
su -c '/data/adb/modules/edge60_wlan_monitor/tools/mtk-wifi normal'
```

Never use `rmmod` to switch modes. Live unloading caused delayed kernel memory
corruption during development.

## Repository layout

- `patches/`: complete patch against Motorola gen4m commit `2ba37a3`.
- `module/`: KernelSU package template and mode controller.
- `tools/src/`: source for the static nl80211 controller and test injector.
- `scripts/`: release build and validation helpers.
- `docs/`: implementation, validation and daily-use details.

Generated `.ko`, ZIP and PCAP files belong in release artifacts and are excluded
from Git history.

## Build

The release script expects prepared Motorola/AOSP kernel trees and the matching
toolchains:

```sh
export EDGE60_WLAN_SOURCE=/path/to/clean/gen4m
export EDGE60_KERNEL=/path/to/kernel-mtk
export EDGE60_KOUT=/path/to/prepared/kernel-out
export EDGE60_AOSP=/path/to/aosp-staging
export EDGE60_DEVICE_MODULES=/path/to/kernel_device_modules-6.1
export EDGE60_CLANG=/path/to/clang-r487747c
export EDGE60_MUSL=/path/to/aarch64-linux-musl-cross
export EDGE60_STOCK_MODULE=/path/to/wlan_drv_gen4m_6878.stock.ko

./scripts/build-release.sh
```

The script applies the patch to a disposable clone, compiles the module, checks
the imported symbol CRCs against stock, builds the static AArch64 tools and
creates the KernelSU ZIP under `dist/`.

See [validation](docs/validation.md), [daily use](docs/daily-use.md) and the
[concurrent implementation notes](docs/concurrent-monitor-roadmap.md).

## License

GPL-2.0-only for repository-authored utilities and scripts. Patched Motorola
source files retain their existing license declarations. See `NOTICE`.

Use only on devices and networks you own or are authorized to test.
