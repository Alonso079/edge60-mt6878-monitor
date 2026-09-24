# edge60-mt6878-monitor

Monitor mode, Radiotap RX and raw IEEE 802.11 TX for the internal MediaTek
MT6878 Wi-Fi interface in the Motorola Edge 60 (`scout`). The driver remains
loaded while `wlan0` switches between Android station mode and monitor mode.

Version 1.1.3 uses `wlan0` exclusively in one mode at a time. Concurrent
`wlan0` station plus a separate `mon0` monitor interface is a 1.2.x goal and is
not implemented yet.

## Validated target

- Device: Motorola Edge 60 (`scout`)
- Firmware: `W1VCS36H.14-20-19-7`
- Kernel: `6.1.145-android14-11-g25baf8f7fb12`
- WLAN source: Motorola commit `2ba37a3`
- Root/module manager: KernelSU Next
- Current package: `1.1.3`

Do not install this package on another firmware build. The installer checks the
build fingerprint and aborts if it does not match.

## Current status

Validated on the physical device:

- cold boot with the resident ABI-matched module;
- normal Android Wi-Fi association and DHCP;
- station → monitor → station without unloading the module;
- monitor RX with Radiotap metadata;
- channel selection through nl80211;
- six Radiotap Probe Requests accepted by `kalHardStartXmit`;
- all six frames passed through `qmEnqueueTxPackets`, `nicTxFillDesc` and
  `halWpdmaWriteData`;
- HIF TX and netdev TX counters increased by six;
- normal Wi-Fi recovered after the test without a kernel or firmware reset.

An external radio is still required to confirm the test Probe Request over the
air. The internal trace proves delivery to the MT6878 HIF.

## Daily use

```sh
su -c '/data/adb/modules/edge60_wlan_monitor/tools/mtk-wifi status'
su -c '/data/adb/modules/edge60_wlan_monitor/tools/mtk-wifi monitor 2412'
su -c '/data/adb/modules/edge60_wlan_monitor/tools/capture.sh /data/local/tmp/capture.pcap'
su -c '/data/adb/modules/edge60_wlan_monitor/tools/test_inject wlan0'
su -c '/data/adb/modules/edge60_wlan_monitor/tools/mtk-wifi normal'
```

Never use `rmmod` to switch modes. Live unloading caused delayed kernel memory
corruption during testing. The resident station/monitor transition avoids that
path.

## Repository layout

- `patches/`: complete patch against Motorola gen4m commit `2ba37a3`.
- `module/`: KernelSU package template and the safe mode switcher.
- `tools/src/`: source for the nl80211 controller and harmless injector.
- `scripts/`: release build and validation helpers.
- `docs/`: device validation evidence and daily usage notes.

Generated `.ko` and ZIP files belong in GitHub Releases and are deliberately
excluded from Git history.

## Build

The release script expects already prepared Motorola/AOSP kernel trees and the
same Clang and module symbol inputs used by the phone:

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
all imported symbol CRCs against stock, builds the static AArch64 tools and
creates the KernelSU ZIP under `dist/`.

More detail is available in [validation](docs/validation.md) and
[daily use](docs/daily-use.md). The remaining work for concurrent station plus
monitor is tracked in the [concurrent monitor roadmap](docs/concurrent-monitor-roadmap.md).

## License

GPL-2.0-only for repository-authored utilities and scripts. Patched Motorola
source files retain their existing license declarations. See `NOTICE`.

Use only on devices and networks you own or are authorized to test.
