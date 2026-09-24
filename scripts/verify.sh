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
grep -q 'PACKET_QDISC_BYPASS' "$ROOT/tools/src/test_inject.c"
grep -q '^version=1.1.3$' "$ROOT/module/module.prop"

if find "$ROOT" -path "$ROOT/.git" -prune -o -type f \
    \( -name '*.ko' -o -name '*.zip' -o -name '*.pcap' \) -print | grep -q .; then
    echo 'generated binary or capture found in repository' >&2
    exit 1
fi

echo 'repository checks passed'
