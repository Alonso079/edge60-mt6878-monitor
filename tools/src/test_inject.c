/* SPDX-License-Identifier: GPL-2.0-only */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <linux/if_packet.h>
#include <net/ethernet.h>
#include <arpa/inet.h>
#include <errno.h>

int main(int argc, char *argv[]) {
    const char *ifname = (argc > 1) ? argv[1] : "wlan0";
    printf("[*] Abriendo socket crudo AF_PACKET en %s...\n", ifname);

    int sock = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL));
    if (sock < 0) {
        perror("[-] socket(AF_PACKET)");
        return 1;
    }

    /* Monitor interfaces intentionally have no carrier. Bypass qdisc so the
     * frame reaches ndo_start_xmit instead of being dropped before the driver.
     */
    int bypass = 1;
    if (setsockopt(sock, SOL_PACKET, PACKET_QDISC_BYPASS,
                   &bypass, sizeof(bypass)) < 0) {
        perror("[-] setsockopt(PACKET_QDISC_BYPASS)");
        close(sock);
        return 1;
    }

    struct ifreq ifr;
    memset(&ifr, 0, sizeof(ifr));
    strncpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name) - 1);
    if (ioctl(sock, SIOCGIFINDEX, &ifr) < 0) {
        perror("[-] ioctl(SIOCGIFINDEX)");
        close(sock);
        return 1;
    }

    struct sockaddr_ll sa;
    memset(&sa, 0, sizeof(sa));
    sa.sll_family = AF_PACKET;
    sa.sll_ifindex = ifr.ifr_ifindex;
    sa.sll_protocol = htons(ETH_P_ALL);

    if (bind(sock, (struct sockaddr *)&sa, sizeof(sa)) < 0) {
        perror("[-] bind");
        close(sock);
        return 1;
    }

    /* Construir Radiotap minimo + una trama 802.11 Probe Request. */
    unsigned char frame[128];
    memset(frame, 0, sizeof(frame));

    /* Radiotap v0, longitud 8, sin campos opcionales. */
    frame[0] = 0x00; frame[1] = 0x00;
    frame[2] = 0x08; frame[3] = 0x00;
    frame[4] = 0x00; frame[5] = 0x00;
    frame[6] = 0x00; frame[7] = 0x00;

    const int mac = 8;

    // IEEE 802.11 Header (24 bytes)
    frame[mac + 0] = 0x40; frame[mac + 1] = 0x00; // Probe Request
    frame[mac + 2] = 0x00; frame[mac + 3] = 0x00; // Duration
    // Dest MAC: Broadcast
    frame[mac + 4] = 0xff; frame[mac + 5] = 0xff;
    frame[mac + 6] = 0xff; frame[mac + 7] = 0xff;
    frame[mac + 8] = 0xff; frame[mac + 9] = 0xff;
    // Src MAC: Fake local address
    frame[mac + 10] = 0x02; frame[mac + 11] = 0x12;
    frame[mac + 12] = 0x34; frame[mac + 13] = 0x56;
    frame[mac + 14] = 0x78; frame[mac + 15] = 0x9a;
    // BSSID: Broadcast
    frame[mac + 16] = 0xff; frame[mac + 17] = 0xff;
    frame[mac + 18] = 0xff; frame[mac + 19] = 0xff;
    frame[mac + 20] = 0xff; frame[mac + 21] = 0xff;
    // Sequence Control
    frame[mac + 22] = 0x00; frame[mac + 23] = 0x00;

    // Tag: SSID "EDGE60_INJECT_TEST"
    const char *ssid = "EDGE60_INJECT_TEST";
    int ssid_len = strlen(ssid);
    frame[mac + 24] = 0x00; // Tag Number: SSID
    frame[mac + 25] = ssid_len;
    memcpy(&frame[mac + 26], ssid, ssid_len);

    int pos = mac + 26 + ssid_len;
    // Tag: Supported Rates (1, 2, 5.5, 11 Mbps)
    frame[pos++] = 0x01; // Tag Number: Supported Rates
    frame[pos++] = 0x04; // Length
    frame[pos++] = 0x82; frame[pos++] = 0x84; frame[pos++] = 0x8b; frame[pos++] = 0x96;

    int total_len = pos;
    printf("[*] Enviando Radiotap + Probe Request (%d bytes)...\n",
           total_len);

    ssize_t sent = send(sock, frame, total_len, 0);
    if (sent < 0) {
        perror("[-] send()");
        close(sock);
        return 1;
    }

    printf("[+] EXITO: send() envio %zd bytes al driver!\n", sent);

    // Enviar una rafaga de 5 tramas
    printf("[*] Enviando rafaga de 5 tramas...\n");
    int ok = 0;
    for (int i = 0; i < 5; i++) {
        if (send(sock, frame, total_len, 0) == total_len) ok++;
        usleep(50000);
    }
    printf("[+] %d/5 tramas enviadas correctamente sin rechazo del driver.\n", ok);

    close(sock);
    return 0;
}
