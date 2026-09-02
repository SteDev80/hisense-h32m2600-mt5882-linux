#!/usr/bin/env python3
import binascii
import pathlib
import re
import struct
import sys

source = pathlib.Path(sys.argv[1])
output = pathlib.Path(sys.argv[2])
line_re = re.compile(r"^([0-9a-fA-F]{8}):\s+((?:[0-9a-fA-F]{8}\s*){1,4})")

data = bytearray()
expected_address = 0x02000000
for line in source.read_text(encoding="utf-8", errors="strict").splitlines():
    match = line_re.match(line)
    if not match:
        continue
    address = int(match.group(1), 16)
    if address != expected_address:
        raise SystemExit(f"address discontinuity: got 0x{address:08x}, expected 0x{expected_address:08x}")
    words = match.group(2).split()
    for word in words:
        data.extend(struct.pack("<I", int(word, 16)))
    expected_address += 4 * len(words)

if len(data) < 64:
    raise SystemExit("no complete uImage header reconstructed")
magic, header_crc, timestamp, payload_size, load, entry, data_crc = struct.unpack(">7I", data[:28])
if magic != 0x27051956:
    raise SystemExit(f"bad uImage magic 0x{magic:08x}")
image_size = 64 + payload_size
if len(data) < image_size:
    raise SystemExit(f"short dump: {len(data)} < {image_size}")
image = bytes(data[:image_size])

header = bytearray(image[:64])
header[4:8] = b"\0\0\0\0"
calculated_hcrc = binascii.crc32(header) & 0xFFFFFFFF
calculated_dcrc = binascii.crc32(image[64:]) & 0xFFFFFFFF
if calculated_hcrc != header_crc:
    raise SystemExit(f"header CRC mismatch: {calculated_hcrc:08x} != {header_crc:08x}")
if calculated_dcrc != data_crc:
    raise SystemExit(f"data CRC mismatch: {calculated_dcrc:08x} != {data_crc:08x}")

output.write_bytes(image)
print(f"dump_bytes={len(data)}")
print(f"image_bytes={len(image)}")
print(f"payload_bytes={payload_size}")
print(f"load=0x{load:08x}")
print(f"entry=0x{entry:08x}")
print(f"header_crc=0x{header_crc:08x}")
print(f"data_crc=0x{data_crc:08x}")
print(f"uimage_crc_ok=yes")
for fill in (0x00, 0xFF):
    padded = image + bytes([fill]) * (0x400000 - len(image))
    print(f"partition_crc_fill_{fill:02x}=0x{binascii.crc32(padded) & 0xFFFFFFFF:08x}")
