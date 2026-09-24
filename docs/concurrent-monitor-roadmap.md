# Concurrent station plus monitor roadmap

## Current result

Version 1.1.3 supports this resident transition:

```text
wlan0 managed -> wlan0 monitor -> wlan0 managed
```

It does not support simultaneous `wlan0` and `mon0`. A device test produced:

```text
iw phy phy0 interface add mon0 type monitor
command failed: Invalid argument (-22)
```

`wlan0` remained associated and kept its IP after the rejected operation.

The rejection matches the current source:

- advertised interface combinations contain managed and P2P roles, but no
  monitor role;
- `mtk_cfg_add_iface()` has no dedicated monitor allocation path;
- `nicRxProcessDataPacket()` sends RX to Radiotap and returns whenever the
  global monitor flag is active, so station processing does not continue;
- the existing monitor role changes the type of the original `wlan0` netdev;
- `CMD_ID_SET_MONITOR` controls a radio/band globally and has no per-vif BSS
  identifier.

## 1.2.0 target

The first concurrent implementation should provide:

```text
wlan0: managed, associated, IP and Internet retained
mon0:  monitor, Radiotap RX, same physical channel as wlan0
```

Raw TX from `mon0`, channel hopping, MCC, different bands and firmware monitor
mode are outside this milestone.

## Required driver work

1. Advertise a valid combination containing one station, one monitor and one
   physical channel.
2. Add a dedicated `NL80211_IFTYPE_MONITOR` create/delete path that allocates a
   separate netdev and wireless_dev without uninitializing AIS.
3. Store the monitor vif independently from the global station netdev.
4. Clone eligible RX data for Radiotap delivery to `mon0`; leave the original
   RFB and skb untouched so normal station processing continues.
5. Derive or validate the monitor channel from the connected AIS channel and
   reject attempts to move `mon0` elsewhere while station is associated.
6. Keep the firmware in station operation for the first experiment. Do not send
   the global `CMD_ID_SET_MONITOR` command merely because `mon0` exists.
7. Remove `mon0` without changing association, IP or the `wlan0` carrier.

## Acceptance test

The milestone is complete only when all of these hold at the same time:

- `wlan0` is managed and associated;
- `mon0` exists and reports monitor type;
- `wlan0` retains its SSID and IP;
- Internet traffic through `wlan0` continues;
- `tcpdump -i mon0` receives Radiotap plus IEEE 802.11;
- both interfaces remain on the same physical channel;
- deleting `mon0` leaves `wlan0` connected;
- no firmware reset, kernel panic, BUG or driver assert occurs.

The decisive test runs a sustained ping through `wlan0` while capturing a PCAP
from `mon0`, then verifies both interface counters and opens the PCAP as
Radiotap/IEEE 802.11.
