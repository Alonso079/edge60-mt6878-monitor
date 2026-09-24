#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Extract CONFIG_MODVERSIONS entries from an Android/Linux kernel module."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path

from elftools.elf.elffile import ELFFile


def versions(path: Path) -> list[tuple[int, str]]:
    with path.open("rb") as handle:
        section = ELFFile(handle).get_section_by_name("__versions")
        if section is None:
            raise SystemExit(f"{path}: no __versions section")
        data = section.data()

    # struct modversion_info in this Android 6.1 arm64 build is an unsigned
    # long CRC followed by a 56-byte symbol name.
    entry_size = 64
    if len(data) % entry_size:
        raise SystemExit(f"{path}: unexpected __versions size {len(data)}")

    result = []
    for offset in range(0, len(data), entry_size):
        crc, raw_name = struct.unpack_from("<Q56s", data, offset)
        name = raw_name.split(b"\0", 1)[0].decode("ascii")
        result.append((crc, name))
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("module", type=Path)
    parser.add_argument("--symvers", type=Path)
    parser.add_argument("--whitelist", type=Path)
    args = parser.parse_args()

    entries = versions(args.module)
    if args.symvers:
        args.symvers.write_text(
            "".join(
                f"0x{crc:08x}\t{name}\tvmlinux\tEXPORT_SYMBOL\t\n"
                for crc, name in entries
            )
        )
    if args.whitelist:
        args.whitelist.write_text("".join(f"{name}\n" for _, name in entries))
    print(f"{len(entries)} versioned imports")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
