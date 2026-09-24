# Changelog

## 1.2.0-rc1

- Add a concurrent `mon0` monitor netdev while `wlan0` remains managed.
- Advertise the managed+monitor single-channel cfg80211 combination.
- Clone raw management RX to Radiotap without consuming station RX.
- Enforce the active AIS channel and reject conflicting requests.
- Keep concurrent monitor RX-only and preserve normal station data traffic.
- Add nl80211 create/delete support to the static `mtkmon` utility.
- Add concurrent start/stop and automatic capture-interface selection.
- Validate captures, connectivity and repeated interface lifecycle on hardware.

## 1.1.3

- Restore the default AIS BSS index when entering monitor mode.
- Route raw monitor frames through the active non-direct queue manager.
- Validate and strip Radiotap before DMA.
- Preserve native 802.11 headers in the CONNAC2X TX descriptor.
- Keep carrier and TX queues available on the monitor interface.
- Validate station recovery and the full driver-to-HIF injection path.
