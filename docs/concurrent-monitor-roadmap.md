# Concurrent station plus monitor implementation

## Implemented result

Version 1.2.0 supports this topology on the MT6878 radio:

```text
wlan0: managed, associated, normal Android traffic
mon0:  monitor, Radiotap/IEEE 802.11 management RX
radio: station channel plus bounded, time-sliced MCC survey windows
```

The implementation keeps AIS and the Android station netdev intact. Creating
`mon0` does not send MediaTek's global `CMD_ID_SET_MONITOR`, and deleting it does
not change the station association.

## Driver changes

1. cfg80211 advertises a combination of one managed and one monitor interface,
   with at most one physical channel.
2. `mtk_cfg_add_iface()` has a dedicated monitor allocation path with its own
   `net_device` and `wireless_dev`.
3. The monitor pointer and counters live separately from the station interface.
4. Raw management RX is cloned, wrapped in Radiotap and delivered to `mon0`.
   Original RX processing continues for `wlan0`.
5. Channel requests are checked against every active AIS BSS, including MLO
   layouts. A conflicting frequency returns `-EBUSY`.
6. `mon0` TX is dropped by design in concurrent mode.
7. Driver shutdown unregisters a remaining monitor netdev safely.
8. A minimal vendor Radiotap fallback covers management frames without complete
   RXV groups and still publishes the standard channel field.
9. Frame-control validation admits only real raw management frames to `mon0`.
10. The monitor netdev has ARP and multicast disabled to prevent locally
    generated Ethernet/IPv6 packets from entering Radiotap captures.

## Device acceptance test

The physical-device test confirmed all milestone conditions:

- `wlan0` stayed associated and retained its address;
- `mon0` was created through nl80211 and reported Radiotap link type;
- station ping succeeded while `mon0` was up;
- `capture.sh` selected `mon0` automatically;
- a scan-driven capture produced 106 packets and zero kernel drops;
- Beacons and Probe Responses decoded as IEEE 802.11;
- an independent 66-packet capture had no malformed frames in `tshark`;
- a different fixed frequency was rejected with `-EBUSY`;
- five create/delete lifecycle cycles succeeded;
- removing `mon0` left station traffic operational;
- no panic, BUG, assert or firmware reset appeared in the checked logs.
- the final 144-packet mixed home/off-channel capture decoded with Radiotap
  version 0, management type only and zero malformed packets;
- MCC survey cleanup returned `p2p0` to its original DOWN state.
- station connectivity completed 12/12 probes during that test.

## Hardware limitation

The firmware reports `RSDB:0` and `DBDC Mode: Disable`, so two simultaneous
channels are unavailable. A conflicting fixed monitor frequency returns
`-EBUSY`. The `survey` command instead uses cfg80211 remain-on-channel and
temporarily time-slices the single radio. Short 100-250 ms dwell times reduce
the latency impact on the station; a measured 1 s dwell produced about 1 s of
added latency.

This MediaTek fullmac configuration translates ordinary station data frames to
Ethernet before host RX. The host receives raw 802.11 management frames, which
are the frames cloned to `mon0`. Concurrent capture therefore does not expose
all data MPDUs.

Exclusive `wlan0` monitor mode remains available for the firmware monitor path
and raw injection. An external receiver is still needed to prove over-the-air
transmission of injected frames.

## Release status

The stable release passed repeated monitor lifecycle, MCC, Android Wi-Fi
disable/enable, screen sleep/wake and exclusive-to-managed recovery tests.
Roaming and firmware updates remain compatibility variables to retest when the
device environment changes.
