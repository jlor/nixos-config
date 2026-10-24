#!/usr/bin/env python3
"""Extract BT_RAM_CODE_MT6639_2_1_hdr.bin from an ASUS/MediaTek MT7925/MT7927
Windows 11 driver zip.

The zip contains mtkwlan.dat, a container holding one entry per firmware
blob (BT and Wi-Fi). Entry layout:
  - null-terminated ASCII name
  - null padding, then an optional 14-digit numeric build timestamp
  - padded to a 4-byte boundary, then the payload's u32 LE offset and size
The parsing follows the community extraction for the MT6639
(https://gist.github.com/xaviermarquez-alba/a9ccb67ac299a6d4756afd2d62fbf5bd,
as used by https://github.com/jetm/mediatek-mt7927-dkms).

Usage: extract-mt7927-bt-firmware.py DRIVER_ZIP OUT/BT_RAM_CODE_MT6639_2_1_hdr.bin
"""

import os
import struct
import sys
import zipfile

BLOB = "BT_RAM_CODE_MT6639_2_1_hdr.bin"
MIN_BLOB_SIZE = 64  # guard against container-format drift


def entry_payload(data: bytes, name: str) -> bytes:
    marker = name.encode("ascii")
    idx = data.find(marker)
    if idx == -1:
        raise SystemExit(f"entry {name!r} not found in mtkwlan.dat")
    pos = idx + len(marker)
    while pos < len(data) and data[pos] == 0x00:
        pos += 1
    timestamp = data[pos:pos + 14]
    if len(timestamp) == 14 and all(0x30 <= b <= 0x39 for b in timestamp):
        pos += 14
    pos = (pos + 3) & ~3
    if pos + 8 > len(data):
        raise SystemExit(f"truncated mtkwlan.dat entry for {name!r}")
    offset, size = struct.unpack_from("<II", data, pos)
    if size == 0 or offset + size > len(data):
        raise SystemExit(
            f"bad payload bounds for {name!r}: offset={offset}, size={size}"
        )
    return data[offset:offset + size]


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    driver_zip, out_path = sys.argv[1], sys.argv[2]
    with zipfile.ZipFile(driver_zip) as zf:
        if "mtkwlan.dat" not in zf.namelist():
            raise SystemExit("mtkwlan.dat not found in driver zip")
        data = zf.read("mtkwlan.dat")
    blob = entry_payload(data, BLOB)
    if len(blob) < MIN_BLOB_SIZE:
        raise SystemExit(f"extracted blob implausibly small: {len(blob)} bytes")
    out_dir = os.path.dirname(out_path)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
    with open(out_path, "wb") as f:
        f.write(blob)
    print(f"extracted {BLOB}: {len(blob)} bytes")


if __name__ == "__main__":
    main()
