"""Create a separate legacy multi-image. Never replace known-good images."""
from pathlib import Path
import struct
import zlib
import hashlib

repo = Path(__file__).resolve().parent.parent
fmt = '>7I4B32s'

def read_image(path, expected_type):
    raw = path.read_bytes()
    h = list(struct.unpack(fmt, raw[:64]))
    assert h[0] == 0x27051956 and h[9] == expected_type
    assert h[3] == len(raw) - 64
    old_crc = h[1]
    h[1] = 0
    assert zlib.crc32(struct.pack(fmt, *h)) == old_crc
    assert zlib.crc32(raw[64:]) == h[6]
    return h, raw[64:]

k, kernel = read_image(repo / 'outputs/buildroot-h32m2600/uImage-h32m2600-rescue-initrd', 2)
r, initrd = read_image(repo / 'outputs/vendor-usb-v1/payload/uInitrd-h32m2600-usb-vendor-v1', 3)
assert k[7:9] == r[7:9] == [5, 2]  # Linux ARM
assert k[10] == 0, 'Only uncompressed kernel supported by this builder'
payload = struct.pack('>3I', len(kernel), len(initrd), 0)
payload += kernel + b'\0' * (-len(kernel) % 4) + initrd
h = k.copy()
h[1] = 0
assert k[4:6] == [0x7fc0, 0x8000]
# Original image executes in place: its payload begins at header+64.
# A relocated multi-image must COPY that payload to 0x8000, not 0x7fc0.
h[4] = 0x8000
h[3] = len(payload)
h[6] = zlib.crc32(payload)
h[9] = 4  # IH_TYPE_MULTI
h[11] = b'H32 USB MULTI RAM TEST'
h[1] = zlib.crc32(struct.pack(fmt, *h))
result = struct.pack(fmt, *h) + payload
out = repo / 'outputs/usb-multi-test'
out.mkdir(exist_ok=True)
target = out / 'uMulti-h32-usb-test-v2'
with target.open('xb') as f:
    f.write(result)
print(f'{target.name}: {len(result)} bytes; sha256={hashlib.sha256(result).hexdigest()}')
print(f'kernel={len(kernel)} initramfs={len(initrd)} load={h[4]:08x} entry={h[5]:08x}')
