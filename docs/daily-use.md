# Modo Wi-Fi diario para MT6878

## Estado actual

La arquitectura residente está implementada y validada en el Motorola Edge 60. El mismo `wlan_drv_gen4m_6878` se carga una vez durante el arranque y conserva station, monitor, Radiotap RX e inyección 802.11 TX.

```text
arranque en frío
      |
      v
wlan_drv_gen4m_6878 residente
      |                         |
      v                         v
station/AIS  <------------->  monitor/radiotap
Android Wi-Fi                captura e inyección
```

La transición se realiza mediante nl80211. No usa `rmmod`, `insmod` ni el comando privado `MONITOR=` durante la operación diaria.

## Uso

Estado:

```sh
su -c 'cat /sys/module/wlan_drv_gen4m_6878/parameters/monitor_nl80211_ready'
su -c '/data/adb/modules/edge60_wlan_monitor/tools/mtk-wifi status'
```

Monitor en canal 1:

```sh
su -c '/data/adb/modules/edge60_wlan_monitor/tools/mtk-wifi monitor 2412'
```

Captura:

```sh
su -c '/data/adb/modules/edge60_wlan_monitor/tools/capture.sh /data/local/tmp/capture.pcap'
```

Prueba de inyección inocua:

```sh
su -c '/data/adb/modules/edge60_wlan_monitor/tools/test_inject wlan0'
```

Regreso a uso común:

```sh
su -c '/data/adb/modules/edge60_wlan_monitor/tools/mtk-wifi normal'
```

## Validación realizada

- Arranque en frío con KernelSU y módulo 1.1.3.
- Wi-Fi station asociado y con DHCP.
- Cambio a monitor/Radiotap en 2412 MHz.
- RX monitor con miles de tramas y cero descartes del kernel.
- Seis Probe Requests aceptadas, encoladas, descritas y escritas al HIF.
- Contador HIF TX incrementado en seis y netdev TX en seis paquetes.
- Regreso a station, asociación y DHCP sin reinicio.
- Sin panic, BUG, assert ni reset del firmware en el ciclo final.

La emisión por RF debe confirmarse con otra radio capturando en 2412 MHz y buscando el SSID `EDGE60_INJECT_TEST`.

## Seguridad y recuperación

No descargar el módulo Wi-Fi en caliente. Esa operación produjo anteriormente un kernel panic por corrupción de memoria diferida.

El módulo KernelSU conserva el cargador de Motorola y solicita el módulo stock como fallback si la inserción residente falla. El paquete instalable validado es `edge60-wlan-monitor-ksu-v1.1.3.zip`.

## Siguiente fase recomendada

Antes de considerarlo estable para uso diario prolongado:

1. Confirmar la Probe Request con una segunda radio.
2. Ejecutar varios ciclos station→monitor→station en días distintos.
3. Probar suspensión, reanudación y cambio entre 2,4/5 GHz.
4. Probar herramientas que usen nl80211/libpcap y registrar cuáles requieren adaptaciones por tratarse de un fullmac MediaTek.

Una interfaz virtual `mon0` concurrente con station no está implementada. La operación validada usa `wlan0` de forma exclusiva en uno de los dos modos.
