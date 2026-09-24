# Modo Wi-Fi diario para MT6878

## Modos disponibles

El módulo residente 1.2.0-rc1 se carga una sola vez durante el arranque y ofrece
dos formas de trabajo:

```text
uso normal + observación              captura/inyección exclusiva
wlan0 managed + mon0 monitor          wlan0 monitor
```

Ninguna transición usa `rmmod`. La interfaz concurrente comparte el canal físico
de la conexión administrada.

## Monitor concurrente

Activa `mon0` sin desconectar Android Wi-Fi:

```sh
su -c '/data/adb/modules/edge60_wlan_monitor/tools/mtk-wifi concurrent'
```

Captura con libpcap/tcpdump. `capture.sh` elige `mon0` automáticamente:

```sh
su -c '/data/adb/modules/edge60_wlan_monitor/tools/capture.sh /data/local/tmp/concurrent.pcap'
```

Detén el monitor sin tocar la asociación de `wlan0`:

```sh
su -c '/data/adb/modules/edge60_wlan_monitor/tools/mtk-wifi concurrent-stop'
```

Este modo captura RX de administración que el firmware entrega como 802.11
crudo. Los datos normales siguen llegando a `wlan0` traducidos a Ethernet. La
transmisión desde `mon0` está desactivada.

## Monitor exclusivo

Para el camino monitor completo y la inyección de prueba:

```sh
su -c '/data/adb/modules/edge60_wlan_monitor/tools/mtk-wifi monitor 2412'
su -c '/data/adb/modules/edge60_wlan_monitor/tools/capture.sh /data/local/tmp/exclusive.pcap'
su -c '/data/adb/modules/edge60_wlan_monitor/tools/test_inject wlan0'
su -c '/data/adb/modules/edge60_wlan_monitor/tools/mtk-wifi normal'
```

La emisión de la Probe Request por RF todavía debe confirmarse con otra radio en
el mismo canal.

## Estado y recuperación

```sh
su -c 'cat /sys/module/wlan_drv_gen4m_6878/parameters/monitor_nl80211_ready'
su -c '/data/adb/modules/edge60_wlan_monitor/tools/mtk-wifi status'
```

Si una captura termina de forma abrupta, `mtk-wifi concurrent-stop` elimina una
`mon0` existente aunque falte el archivo de estado. `mtk-wifi normal` también
limpia `mon0` antes de devolver el control completo a Android.

No descargues el módulo Wi-Fi en caliente. Esa operación produjo corrupción de
memoria diferida durante el desarrollo. Un reinicio en frío es el camino seguro
para cambiar el binario residente.

## Validación realizada

- asociación y tráfico Android preservados con `mon0` activa;
- captura Radiotap/802.11 válida y cero descartes del kernel;
- rechazo de una frecuencia incompatible con la estación;
- eliminación de `mon0` sin perder conectividad;
- cinco ciclos de creación/uso/eliminación;
- sin panic, BUG, assert ni reinicio del firmware en las pruebas finales.
