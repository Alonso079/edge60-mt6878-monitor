# Changelog

## 1.1.3

- Restore the default AIS BSS index when entering monitor mode.
- Route raw monitor frames through the active non-direct queue manager.
- Validate and strip Radiotap before DMA.
- Preserve native 802.11 headers in the CONNAC2X TX descriptor.
- Keep carrier and TX queues available on the monitor interface.
- Validate station recovery and the full driver-to-HIF injection path.
