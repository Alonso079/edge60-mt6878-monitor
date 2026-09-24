# Validación de monitor e inyección MT6878

## Resultado

El Motorola Edge 60 (`scout`, MT6878) ejecuta un único módulo Wi-Fi residente capaz de alternar entre station y monitor mediante nl80211. No se descarga el módulo durante los cambios de modo.

La versión validada es `edge60_wlan_monitor` **1.1.3**. Se comprobó:

- arranque en frío con el módulo residente;
- Wi-Fi normal, asociación y DHCP;
- cambio de `wlan0` a `NL80211_IFTYPE_MONITOR`;
- interfaz `ARPHRD_IEEE80211_RADIOTAP`, carrier y colas TX activos;
- canal monitor de 2412 MHz mediante nl80211;
- recepción 802.11 con Radiotap;
- aceptación de Radiotap desde un socket AF_PACKET;
- eliminación de la cabecera Radiotap antes de DMA;
- paso por la cola MediaTek, composición del descriptor CONNAC2X y escritura al HIF;
- retorno a station y reconexión de Android sin reiniciar ni descargar el controlador.

La comprobación que queda fuera del teléfono es capturar la Probe Request con otra radio en el mismo canal. La prueba interna demuestra entrega al hardware, pero una captura externa es la confirmación final de emisión por RF.

## Fuente y compilación

- WLAN Motorola: `android-16-release-w1vc36h.14-20-1`, commit `2ba37a3`.
- Kernel: `6.1.145-android14-11-g25baf8f7fb12`.
- Compilador: Android Clang `r487747c`, Clang 17.0.2.
- Arquitectura: AArch64.
- Variante: `user`.
- Monitor MediaTek: `CONFIG_SNIFFER_RADIOTAP=y`.
- ABI cfg80211: `CONFIG_NL80211_TESTMODE=y`.

El módulo conserva el nombre interno y el `vermagic` del dispositivo:

```text
wlan_drv_gen4m_6878
6.1.145-android14-11-g25baf8f7fb12 SMP preempt mod_unload modversions aarch64
```

Validación ABI:

```text
importaciones versionadas candidatas: 388
importaciones versionadas stock:      389
CRC comunes coincidentes:             388/388
CRC distintos:                        0
importaciones nuevas:                 0
mtk_cfg_ops:                           1008 bytes
```

La única importación adicional del stock es `aee_kernel_warning_api_func`.

## Cambios necesarios

La integración final modifica nueve archivos del driver:

1. Activa la implementación MediaTek de monitor/Radiotap para MT6878.
2. Selecciona `BandIdx=0` y propaga los errores del firmware al configurar el canal; también acepta 20 MHz no-HT y 6 GHz.
3. Mantiene carrier y colas TX activos en monitor.
4. Restaura `ucBssIdx=AIS_DEFAULT_INDEX` al crear el rol monitor. La ruta station lo dejaba en `0xff`, haciendo que toda transmisión terminara con `WLAN_STATUS_NOT_ACCEPTED` antes de analizar la trama.
5. Acepta tráfico sin asociación solamente cuando monitor está realmente activo.
6. Valida y elimina Radiotap, calcula la longitud MAC 802.11 y marca el skb como `ENUM_PKT_802_11`.
7. Obtiene el destino desde Addr1, desactiva agregación y evita protección automática para la trama cruda.
8. Redirige tramas monitor sin `STA_REC` a la cola BMCAST en la ruta activa `qmEnqueueTxPackets()`. Este build usa `CFG_TX_DIRECT=0`.
9. Construye el descriptor con `HEADER_FORMAT_802_11_NORMAL_MODE`.

La ruta debugfs de MediaTek permanece desactivada porque el build Motorola usa `CFG_SUPPORT_DEBUG_FS=0`. Una variante anterior que la conservaba falló durante la inicialización.

## Prueba de inyección 1.1.3

`test_inject` abre `AF_PACKET/SOCK_RAW`, activa `PACKET_QDISC_BYPASS` y envía seis Probe Requests de difusión con SSID `EDGE60_INJECT_TEST`. Cada envío lleva 8 bytes de Radiotap y 50 bytes de trama 802.11.

Kprobes temporales confirmaron para las seis tramas:

```text
kalHardStartXmit:      bss=0, retorno=0x0
qmEnqueueTxPackets:   alcanzada
nicTxFillDesc:        alcanzada
halWpdmaWriteData:    alcanzada
```

Los mensajes del controlador confirmaron además:

```text
[TX-INJECT] monitor mode: bypassing AIS conn check
[TX-INJECT] raw 802.11 len=50 hdr=24 rtap=1
[TX-INJECT] QM redirect STA_NOT_FOUND -> BMCAST
```

Contadores antes y después:

```text
HIF antes:   T[82 82 82 / 0 0 0 0], txreg[0]
HIF después: T[82 82 82 / 6 6 0 6], txreg[6]
netdev TX:   6 paquetes, 300 bytes, 0 errores, 0 descartes
```

Esto prueba que las seis MPDU sin Radiotap llegaron a la escritura del HIF. No se observó panic, BUG, assert ni reset del firmware. Después de la prueba, `mtk-wifi normal` restauró `type managed`, Android se asoció nuevamente y recuperó su dirección IP.

## Captura monitor previa

La recepción monitor ya se había validado con una captura real:

- 21.309 paquetes en 19,857142 segundos;
- 5.443.495 bytes;
- cero paquetes descartados por el kernel;
- Radiotap con frecuencia, PHY, tasa y RSSI;
- SHA-256 del PCAP: `861f1082a0e4db46b79112c86b14b832dbb620341b967b66e0258527edbe3772`.

## Operación diaria

```sh
su -c '/data/adb/modules/edge60_wlan_monitor/tools/mtk-wifi monitor 2412'
su -c '/data/adb/modules/edge60_wlan_monitor/tools/capture.sh /data/local/tmp/capture.pcap'
su -c '/data/adb/modules/edge60_wlan_monitor/tools/test_inject wlan0'
su -c '/data/adb/modules/edge60_wlan_monitor/tools/mtk-wifi normal'
```

No se debe usar `rmmod` para cambiar de modo. Una prueba anterior de descarga en vivo terminó en kernel panic por corrupción de memoria diferida. El flujo resident station↔monitor evita esa operación.

## Artefactos finales

```text
wlan_drv_gen4m_6878_resident.ko
SHA-256 4b0a0a87a4e2125a11de0263b201c15cd9dba303df558057337c8c088d03e71a

edge60-wlan-monitor-ksu-v1.1.3.zip
SHA-256 c261a4744fdc5c12988d42a7135575b33f3a32e87c026636e9fac7a703b40a22
```

El módulo está cargado desde `/metadata/edge60_wlan_monitor`, con fallback al módulo stock si la inserción residente falla durante el arranque.
