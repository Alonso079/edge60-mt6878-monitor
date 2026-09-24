/* SPDX-License-Identifier: GPL-2.0 */
/* Minimal libc-free nl80211 control utility for Android/aarch64. */

#include <asm/unistd.h>
#include <linux/genetlink.h>
#include <linux/netlink.h>
#include <linux/nl80211.h>
#include <linux/types.h>

#define AF_NETLINK 16
#define SOCK_RAW 3
#define STDOUT_FILENO 1
#define STDERR_FILENO 2

#ifndef NLA_OK
#define NLA_OK(nla, len) ((len) >= (int)sizeof(struct nlattr) && \
	(nla)->nla_len >= sizeof(struct nlattr) && (nla)->nla_len <= (len))
#endif
#ifndef NLA_NEXT
#define NLA_NEXT(nla, attrlen) \
	((attrlen) -= NLA_ALIGN((nla)->nla_len), \
	 (struct nlattr *)(((unsigned char *)(nla)) + NLA_ALIGN((nla)->nla_len)))
#endif

__asm__(
    ".global _start\n"
    ".type _start,%function\n"
    "_start:\n"
    "ldr x0, [sp]\n"
    "add x1, sp, #8\n"
    "bl app_main\n"
    "mov x8, #93\n"
    "svc #0\n");

static long syscall1(long nr, long a0)
{
	register long x0 __asm__("x0") = a0;
	register long x8 __asm__("x8") = nr;
	__asm__ volatile("svc #0" : "+r"(x0) : "r"(x8) : "memory");
	return x0;
}

static long syscall3(long nr, long a0, long a1, long a2)
{
	register long x0 __asm__("x0") = a0;
	register long x1 __asm__("x1") = a1;
	register long x2 __asm__("x2") = a2;
	register long x8 __asm__("x8") = nr;
	__asm__ volatile("svc #0" : "+r"(x0) : "r"(x1), "r"(x2), "r"(x8) : "memory");
	return x0;
}

static long syscall6(long nr, long a0, long a1, long a2,
		     long a3, long a4, long a5)
{
	register long x0 __asm__("x0") = a0;
	register long x1 __asm__("x1") = a1;
	register long x2 __asm__("x2") = a2;
	register long x3 __asm__("x3") = a3;
	register long x4 __asm__("x4") = a4;
	register long x5 __asm__("x5") = a5;
	register long x8 __asm__("x8") = nr;
	__asm__ volatile("svc #0" : "+r"(x0)
		: "r"(x1), "r"(x2), "r"(x3), "r"(x4), "r"(x5), "r"(x8)
		: "memory");
	return x0;
}

static unsigned long str_len(const char *s)
{
	unsigned long n = 0;
	while (s[n])
		n++;
	return n;
}

static int str_eq(const char *a, const char *b)
{
	while (*a && *a == *b) {
		a++;
		b++;
	}
	return *a == *b;
}

static void copy_bytes(void *dst, const void *src, unsigned long len)
{
	unsigned char *d = dst;
	const unsigned char *s = src;
	while (len--)
		*d++ = *s++;
}

static void zero_bytes(void *dst, unsigned long len)
{
	unsigned char *d = dst;
	while (len--)
		*d++ = 0;
}

static void write_str(int fd, const char *s)
{
	syscall3(__NR_write, fd, (long)s, str_len(s));
}

static void write_num(long value)
{
	char buf[24];
	unsigned int pos = sizeof(buf);
	unsigned long n;
	if (value < 0) {
		write_str(STDERR_FILENO, "-");
		n = (unsigned long)-value;
	} else {
		n = (unsigned long)value;
	}
	do {
		buf[--pos] = '0' + (n % 10);
		n /= 10;
	} while (n);
	syscall3(__NR_write, STDERR_FILENO, (long)&buf[pos], sizeof(buf) - pos);
}

static int parse_u32(const char *s, __u32 *value)
{
	unsigned long n = 0;
	if (!*s)
		return -1;
	while (*s) {
		if (*s < '0' || *s > '9')
			return -1;
		n = n * 10 + (*s++ - '0');
		if (n > 0xffffffffUL)
			return -1;
	}
	*value = (__u32)n;
	return 0;
}

static unsigned int add_attr(unsigned char *buf, unsigned int offset,
			     __u16 type, const void *data, unsigned int len)
{
	struct nlattr *attr = (struct nlattr *)(buf + offset);
	unsigned int total = NLA_HDRLEN + len;
	unsigned int aligned = NLA_ALIGN(total);
	attr->nla_type = type;
	attr->nla_len = total;
	copy_bytes((unsigned char *)attr + NLA_HDRLEN, data, len);
	if (aligned > total)
		zero_bytes((unsigned char *)attr + total, aligned - total);
	return offset + aligned;
}

static long nl_send(int fd, const void *buf, unsigned int len)
{
	struct sockaddr_nl peer;
	zero_bytes(&peer, sizeof(peer));
	peer.nl_family = AF_NETLINK;
	return syscall6(__NR_sendto, fd, (long)buf, len, 0,
			(long)&peer, sizeof(peer));
}

static long nl_recv(int fd, void *buf, unsigned int len)
{
	return syscall6(__NR_recvfrom, fd, (long)buf, len, 0, 0, 0);
}

static int resolve_nl80211(int fd)
{
	unsigned char request[128];
	unsigned char response[8192];
	struct nlmsghdr *nlh = (struct nlmsghdr *)request;
	struct genlmsghdr *genl;
	unsigned int offset;
	const char family[] = "nl80211";
	long received;

	zero_bytes(request, sizeof(request));
	nlh->nlmsg_type = GENL_ID_CTRL;
	nlh->nlmsg_flags = NLM_F_REQUEST;
	nlh->nlmsg_seq = 1;
	genl = (struct genlmsghdr *)NLMSG_DATA(nlh);
	genl->cmd = CTRL_CMD_GETFAMILY;
	genl->version = 1;
	offset = NLMSG_LENGTH(GENL_HDRLEN);
	offset = add_attr(request, offset, CTRL_ATTR_FAMILY_NAME,
			  family, sizeof(family));
	nlh->nlmsg_len = offset;
	if (nl_send(fd, request, offset) < 0)
		return -1;
	received = nl_recv(fd, response, sizeof(response));
	if (received < 0)
		return (int)received;

	for (nlh = (struct nlmsghdr *)response;
	     NLMSG_OK(nlh, received); nlh = NLMSG_NEXT(nlh, received)) {
		struct nlattr *attr;
		int remaining;
		if (nlh->nlmsg_type == NLMSG_ERROR)
			return ((struct nlmsgerr *)NLMSG_DATA(nlh))->error;
		genl = (struct genlmsghdr *)NLMSG_DATA(nlh);
		attr = (struct nlattr *)((unsigned char *)genl + GENL_HDRLEN);
		remaining = nlh->nlmsg_len - NLMSG_LENGTH(GENL_HDRLEN);
		while (NLA_OK(attr, remaining)) {
			if (attr->nla_type == CTRL_ATTR_FAMILY_ID &&
			    attr->nla_len >= NLA_HDRLEN + sizeof(__u16))
				return *(__u16 *)((unsigned char *)attr + NLA_HDRLEN);
			attr = NLA_NEXT(attr, remaining);
		}
	}
	return -2;
}

static int send_nl80211(int fd, int family_id, __u8 command,
			__u32 ifindex, const __u16 *types,
			const __u32 *values, unsigned int count)
{
	unsigned char request[512];
	unsigned char response[4096];
	struct nlmsghdr *nlh = (struct nlmsghdr *)request;
	struct genlmsghdr *genl;
	unsigned int offset;
	long received;

	zero_bytes(request, sizeof(request));
	nlh->nlmsg_type = family_id;
	nlh->nlmsg_flags = NLM_F_REQUEST | NLM_F_ACK;
	nlh->nlmsg_seq = 2;
	genl = (struct genlmsghdr *)NLMSG_DATA(nlh);
	genl->cmd = command;
	genl->version = 0;
	offset = NLMSG_LENGTH(GENL_HDRLEN);
	offset = add_attr(request, offset, NL80211_ATTR_IFINDEX,
			  &ifindex, sizeof(ifindex));
	for (unsigned int i = 0; i < count; i++)
		offset = add_attr(request, offset, types[i],
				  &values[i], sizeof(values[i]));
	nlh->nlmsg_len = offset;
	if (nl_send(fd, request, offset) < 0)
		return -1;
	received = nl_recv(fd, response, sizeof(response));
	if (received < 0)
		return (int)received;
	for (nlh = (struct nlmsghdr *)response;
	     NLMSG_OK(nlh, received); nlh = NLMSG_NEXT(nlh, received)) {
		if (nlh->nlmsg_type == NLMSG_ERROR)
			return ((struct nlmsgerr *)NLMSG_DATA(nlh))->error;
	}
	return -2;
}

static void usage(void)
{
	write_str(STDERR_FILENO,
		"usage:\n"
		"  mtkmon iface IFINDEX monitor|station\n"
		"  mtkmon channel IFINDEX FREQ_MHZ\n");
}

int app_main(int argc, char **argv)
{
	struct sockaddr_nl local;
	__u32 ifindex, value;
	__u16 attrs[3];
	__u32 values[3];
	int fd, family_id, result;

	if (argc < 4 || parse_u32(argv[2], &ifindex)) {
		usage();
		return 2;
	}
	fd = (int)syscall3(__NR_socket, AF_NETLINK, SOCK_RAW, NETLINK_GENERIC);
	if (fd < 0) {
		result = fd;
		goto error;
	}
	zero_bytes(&local, sizeof(local));
	local.nl_family = AF_NETLINK;
	result = (int)syscall3(__NR_bind, fd, (long)&local, sizeof(local));
	if (result < 0)
		goto close_error;
	family_id = resolve_nl80211(fd);
	if (family_id < 0) {
		result = family_id;
		goto close_error;
	}

	if (str_eq(argv[1], "iface")) {
		attrs[0] = NL80211_ATTR_IFTYPE;
		if (str_eq(argv[3], "monitor"))
			values[0] = NL80211_IFTYPE_MONITOR;
		else if (str_eq(argv[3], "station"))
			values[0] = NL80211_IFTYPE_STATION;
		else {
			usage();
			result = -22;
			goto close_error;
		}
		result = send_nl80211(fd, family_id, NL80211_CMD_SET_INTERFACE,
					ifindex, attrs, values, 1);
	} else if (str_eq(argv[1], "channel")) {
		if (parse_u32(argv[3], &value)) {
			usage();
			result = -22;
			goto close_error;
		}
		attrs[0] = NL80211_ATTR_WIPHY_FREQ;
		values[0] = value;
		attrs[1] = NL80211_ATTR_CHANNEL_WIDTH;
		values[1] = NL80211_CHAN_WIDTH_20;
		attrs[2] = NL80211_ATTR_CENTER_FREQ1;
		values[2] = value;
		result = send_nl80211(fd, family_id, NL80211_CMD_SET_WIPHY,
					ifindex, attrs, values, 3);
	} else {
		usage();
		result = -22;
	}

	if (result == 0)
		write_str(STDOUT_FILENO, "ok\n");

close_error:
	syscall1(__NR_close, fd);
error:
	if (result < 0) {
		write_str(STDERR_FILENO, "netlink/syscall error ");
		write_num(result);
		write_str(STDERR_FILENO, "\n");
		return 1;
	}
	return 0;
}
