#!/usr/bin/env bash
# Build, ABI-check and package the Edge 60 MT6878 resident WLAN module.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD="$ROOT/.build"
DIST="$ROOT/dist"
PATCH="$ROOT/patches/mt6878-nl80211-monitor.patch"
MODULE_TEMPLATE="$ROOT/module"
SOURCE_REV=${EDGE60_SOURCE_REV:-2ba37a3}

: "${EDGE60_WLAN_SOURCE:?set EDGE60_WLAN_SOURCE to a clean Motorola gen4m repository}"
: "${EDGE60_KERNEL:?set EDGE60_KERNEL to kernel-mtk}"
: "${EDGE60_KOUT:?set EDGE60_KOUT to the prepared kernel output directory}"
: "${EDGE60_AOSP:?set EDGE60_AOSP to the AOSP staging root}"
: "${EDGE60_DEVICE_MODULES:?set EDGE60_DEVICE_MODULES to kernel_device_modules-6.1}"
: "${EDGE60_CLANG:?set EDGE60_CLANG to clang-r487747c}"
: "${EDGE60_MUSL:?set EDGE60_MUSL to aarch64-linux-musl-cross}"
: "${EDGE60_STOCK_MODULE:?set EDGE60_STOCK_MODULE to the stock WLAN module}"

MODULE_DIR="$EDGE60_AOSP/vendor/mediatek/kernel_modules/connectivity/wlan/core/gen4m"
PATCHED_SOURCE="$BUILD/gen4m-source"
STAGE="$BUILD/stage"
BUILT="$MODULE_DIR/wlan_drv_gen4m_6878.ko"
LLVM_STRIP="$EDGE60_CLANG/bin/llvm-strip"
MUSL_CC="$EDGE60_MUSL/bin/aarch64-linux-musl-gcc"
VERSION=$(sed -n 's/^version=//p' "$MODULE_TEMPLATE/module.prop")
ZIP="$DIST/edge60-wlan-monitor-ksu-v${VERSION}.zip"

for required in "$EDGE60_WLAN_SOURCE/.git" "$EDGE60_KERNEL" "$EDGE60_KOUT" \
    "$MODULE_DIR" "$EDGE60_DEVICE_MODULES" "$EDGE60_STOCK_MODULE" \
    "$EDGE60_CLANG/bin/clang" "$LLVM_STRIP" "$MUSL_CC" "$PATCH"; do
    [ -e "$required" ] || { echo "missing: $required" >&2; exit 1; }
done

rm -rf "$BUILD"
mkdir -p "$BUILD" "$DIST"
git clone -q --local --no-hardlinks "$EDGE60_WLAN_SOURCE" "$PATCHED_SOURCE"
git -C "$PATCHED_SOURCE" checkout -q --detach "$SOURCE_REV"
git -C "$PATCHED_SOURCE" apply --check "$PATCH"
git -C "$PATCHED_SOURCE" apply "$PATCH"

FILES=(
    Kbuild.6878
    chips/common/pre_cal.c
    include/config.h
    nic/nic_tx.c
    nic/nic_txd_v2.c
    nic/que_mgt.c
    os/linux/gl_cfg80211.c
    os/linux/gl_init.c
    os/linux/gl_kal.c
)
for file in "${FILES[@]}"; do
    cp -f "$PATCHED_SOURCE/$file" "$MODULE_DIR/$file"
done

env PATH="$EDGE60_CLANG/bin:/usr/bin" TARGET_BUILD_VARIANT=user \
    make -j"$(nproc)" -C "$EDGE60_KERNEL" O="$EDGE60_KOUT" \
    ARCH=arm64 LLVM=1 \
    LOCALVERSION=-android14-11-g25baf8f7fb12 \
    M="$MODULE_DIR" MODULE_NAME=wlan_drv_gen4m_6878 SEGMENT=SP \
    CONFIG_ARCH_MEDIATEK=y CONFIG_MTK_COMBO_WIFI=m \
    CONFIG_MTK_ADVANCED_80211_MLO=y CONFIG_MTK_ECCCI_DRIVER=m \
    CONFIG_MTK_MDDP_SUPPORT=m CONFIG_MTK_CONNSYS_DEDICATED_LOG_PATH=y \
    CONFIG_MTK_AEE_FEATURE=y CONFIG_NL80211_TESTMODE=y \
    DEVICE_MODULES_PATH="$EDGE60_DEVICE_MODULES" TOP="$EDGE60_AOSP" \
    KCFLAGS=-DCONFIG_NL80211_TESTMODE modules \
    2>&1 | tee "$DIST/build.log"

cp -f "$BUILT" "$DIST/wlan_drv_gen4m_6878_resident.unstripped.ko"
"$LLVM_STRIP" --strip-debug \
    -o "$DIST/wlan_drv_gen4m_6878_resident.ko" "$BUILT"

python3 "$ROOT/scripts/extract_module_versions.py" \
    "$DIST/wlan_drv_gen4m_6878_resident.ko" \
    --symvers "$BUILD/candidate.symvers"
python3 "$ROOT/scripts/extract_module_versions.py" \
    "$EDGE60_STOCK_MODULE" --symvers "$BUILD/stock.symvers"
python3 - "$BUILD/candidate.symvers" "$BUILD/stock.symvers" <<'PY'
import sys
from pathlib import Path

def load(path):
    return {parts[1]: parts[0] for parts in
            (line.split() for line in Path(path).read_text().splitlines())}

candidate, stock = map(load, sys.argv[1:])
common = candidate.keys() & stock.keys()
mismatch = sorted(name for name in common if candidate[name] != stock[name])
new = sorted(candidate.keys() - stock.keys())
if mismatch or new:
    raise SystemExit(f"ABI incompatible: CRC={mismatch}, new={new}")
print(f"ABI OK: {len(candidate)}/{len(candidate)} CRC; no new imports")
PY

mkdir -p "$BUILD/tools"
"$MUSL_CC" -nostdlib -static -Os -fno-stack-protector -fno-builtin \
    -Wl,--build-id=none,-e,_start \
    -o "$BUILD/tools/mtkmon" "$ROOT/tools/src/mtkmon.c"
"$MUSL_CC" -static -O2 -Wall -Wextra -Werror \
    -o "$BUILD/tools/test_inject" "$ROOT/tools/src/test_inject.c"
"$LLVM_STRIP" --strip-all "$BUILD/tools/mtkmon" "$BUILD/tools/test_inject"

cp -a "$MODULE_TEMPLATE" "$STAGE"
cp -f "$DIST/wlan_drv_gen4m_6878_resident.ko" \
    "$STAGE/payload/wlan_drv_gen4m_6878_resident.ko"
cp -f "$BUILD/tools/mtkmon" "$BUILD/tools/test_inject" "$STAGE/tools/"
chmod 0755 "$STAGE"/*.sh "$STAGE"/tools/*
(
    cd "$STAGE"
    sha256sum payload/wlan_drv_gen4m_6878_resident.ko \
        tools/mtkmon tools/test_inject > SHA256SUMS
)
rm -f "$ZIP"
(cd "$STAGE" && zip -qr -9 "$ZIP" .)
(
    cd "$DIST"
    sha256sum wlan_drv_gen4m_6878_resident.ko \
        wlan_drv_gen4m_6878_resident.unstripped.ko \
        "$(basename "$ZIP")" > SHA256SUMS
)
cat "$DIST/SHA256SUMS"
