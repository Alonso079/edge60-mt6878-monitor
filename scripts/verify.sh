#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)

bash -n "$ROOT/scripts/build-release.sh"
for script in "$ROOT"/module/*.sh "$ROOT"/module/tools/*.sh; do
    bash -n "$script"
done
python3 -m py_compile "$ROOT/scripts/extract_module_versions.py"

grep -q 'ucBssIdx = AIS_DEFAULT_INDEX' \
    "$ROOT/patches/mt6878-nl80211-monitor.patch"
grep -q 'qmIsMonitorInjection' \
    "$ROOT/patches/mt6878-nl80211-monitor.patch"
grep -q 'mtk_cfg80211_add_monitor_iface' \
    "$ROOT/patches/mt6878-nl80211-monitor.patch"
grep -q 'radiotapFillRadiotapClone' \
    "$ROOT/patches/mt6878-nl80211-monitor.patch"
grep -q 'instead of leaving analyzers with an unlabelled vendor blob' \
    "$ROOT/patches/mt6878-nl80211-monitor.patch"
grep -q 'nicRxIsRawMgmtFrame' \
    "$ROOT/patches/mt6878-nl80211-monitor.patch"
grep -q 'u4MonRxInvalidRaw' \
    "$ROOT/patches/mt6878-nl80211-monitor.patch"
grep -q 'dev->flags = IFF_NOARP' \
    "$ROOT/patches/mt6878-nl80211-monitor.patch"
grep -q 'NL80211_IFTYPE_MONITOR' \
    "$ROOT/patches/mt6878-nl80211-monitor.patch"
grep -q 'PACKET_QDISC_BYPASS' "$ROOT/tools/src/test_inject.c"
grep -q 'NL80211_CMD_NEW_INTERFACE' "$ROOT/tools/src/mtkmon.c"
grep -q 'NL80211_CMD_REMAIN_ON_CHANNEL' "$ROOT/tools/src/mtkmon.c"
grep -q '^version=1.2.0-rc4$' "$ROOT/module/module.prop"

if find "$ROOT" \( -path "$ROOT/.git" -o -path "$ROOT/.build" -o \
    -path "$ROOT/dist" \) -prune -o -type f \
    \( -name '*.ko' -o -name '*.zip' -o -name '*.pcap' \) -print | grep -q .; then
    echo 'generated binary or capture found in repository' >&2
    exit 1
fi

echo 'repository checks passed'
