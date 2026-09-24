# Validación de monitor e inyección MT6878

## Resultado 1.2.0-rc1

El Motorola Edge 60 (`scout`, MT6878) ejecuta un módulo Wi-Fi residente que
mantiene el modo exclusivo de 1.1.3 y añade una interfaz monitor concurrente.

```text
wlan0 managed + mon0 monitor/Radiotap RX
```

`mon0` se crea y elimina con nl80211. AIS, la asociación y el tráfico normal de
Android permanecen activos.

## Fuente, compilación y ABI

- WLAN Motorola: commit `2ba37a3`.
- Kernel: `6.1.145-android14-11-g25baf8f7fb12`.
- Compilador: Android Clang `r487747c`, Clang 17.0.2.
- Arquitectura/variante: AArch64 `user`.
- Módulo candidato SHA-256:
  `1db98cbb70407021b7307743e3490c6e00c3a9438429801e9b085ae7f3a805d5`.
- Vermagic: coincidencia exacta con el dispositivo.
- Símbolos importados comunes: 388/388 CRC iguales.
- CRC distintos: 0.
- Importaciones nuevas: 0.

## Implementación concurrente

Los cambios cubren 17 archivos del driver:

1. combinación cfg80211 de una interfaz managed y una monitor en un canal;
2. netdev y `wireless_dev` independientes para `mon0`;
3. registro, borrado y apagado seguros del monitor secundario;
4. clonación de RX 802.11 crudo sin consumir el skb/RFB de la estación;
5. entrega Radiotap independiente a `mon0`;
6. fallback Radiotap para administración sin RXV completo;
7. validación de canal contra todos los BSS AIS activos;
8. TX descartado deliberadamente en la interfaz concurrente.

Los cambios previos de monitor exclusivo se conservan: selección de canal,
Radiotap RX, validación y retiro de Radiotap TX, clasificación 802.11, cola
BMCAST y descriptor CONNAC2X nativo.

## Prueba en el dispositivo

Se comprobó en el teléfono físico:

- la combinación managed+monitor aparece en `iw phy`;
- creación de `mon0` mientras `wlan0` estaba asociado;
- tipo de enlace `ieee802.11/radiotap` y estado UP;
- ping 5/5 mientras ambas interfaces estaban activas;
- frecuencia diferente rechazada con `-EBUSY`;
- captura final independiente: 66 paquetes, 33.074 bytes, cero malformados en
  `tshark`;
- prueba de `capture.sh`: 106 capturados, 121 recibidos por filtro y cero
  descartados por el kernel;
- decodificación de Beacons y Probe Responses;
- `concurrent-stop` preservó tráfico de estación 5/5;
- cinco ciclos adicionales crear/usar/eliminar finalizaron correctamente;
- sin panic, BUG, assert ni reset en los registros revisados.

El contador de cierre del driver también mostró clonación activa y cero fallos
de clonación en la prueba principal.

## Límite observado

El firmware fullmac entrega datos normales ya traducidos a Ethernet. El host no
puede reconstruir de forma fiable sus cabeceras y metadatos 802.11, por lo que
`mon0` concurrente expone administración cruda y no todo el tráfico de datos.
Durante un escaneo activo, la interfaz observa los canales que recorre la radio;
fuera de esos periodos comparte el canal de la estación.

## Monitor exclusivo e inyección

La validación 1.1.3 sigue siendo aplicable: seis Probe Requests atravesaron
`kalHardStartXmit`, `qmEnqueueTxPackets`, `nicTxFillDesc` y
`halWpdmaWriteData`; los contadores HIF y netdev aumentaron en seis. Esa prueba
demuestra llegada al HIF. Una segunda radio todavía debe confirmar emisión RF.

Nunca se debe usar `rmmod` para cambiar de modo. El flujo residente y el reinicio
en frío evitan la descarga en caliente que provocó corrupción diferida.
