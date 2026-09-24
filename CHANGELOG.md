# Changelog

## 1.2.0

- Serialize mode and survey operations to prevent commands from racing.
- Recover automatically from an operation lock left by a terminated process.
- Restore survey state on interruption and keep `p2p0` ownership intact.
- Verify the resident payload before atomically replacing the active file in
  `/metadata`.
- Validate ten concurrent/MCC lifecycle cycles with uninterrupted station
  traffic.
- Validate Android Wi-Fi disable/enable, screen sleep/wake, exclusive monitor
  TX and return to managed mode on hardware.

## 1.2.0-rc4

- Add a bounded remain-on-channel command for MCC off-channel surveys.
- Restore `p2p0` state automatically after every survey window.
- Report standard Radiotap channel and flags when full RXV metadata is absent.
- Validate frame-control fields before cloning concurrent management RX.
- Reject descriptor-misclassified Ethernet payloads from `mon0`.
- Disable ARP and multicast on the capture-only netdev so local IPv6 MLD
  packets cannot contaminate Radiotap PCAPs.
- Confirm on hardware that RSDB is unavailable and DBDC is disabled.

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
