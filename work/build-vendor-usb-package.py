"""Build a private USB overlay and RAM bootstrap; original artifacts unchanged."""
import gzip
import hashlib
import pathlib
import re
import shutil
import struct
import tarfile
import time
import zlib

repo = pathlib.Path(__file__).resolve().parent.parent
out = repo / 'outputs/vendor-usb-v1'
stage = out / 'payload'
stage.mkdir(exist_ok=False)
overlay = stage / 'overlay'
vendor = overlay / 'opt/h32-vendor'
recovered = out / 'recovered'
for source in recovered.rglob('*.ko'):
    dest = vendor / 'modules' / source.relative_to(recovered)
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, dest)

profile = recovered / 'etc/Wireless/RT2870STA/MT7603USTA.dat'
text = profile.read_text()
lines = []
for line in text.splitlines():
    if '=' in line:
        key, value = line.split('=', 1)
        if re.fullmatch(r'(SSID\d*|WPAPSK\d*|Key[1-4]Str\d*|WscSSID|WscKey|WscPinCode)', key, re.I):
            value = ''
        if key.lower() in ('autoreconnect', 'wscconfmode', 'wscmode', 'wscv2support'):
            value = '0'
        line = key + '=' + value
    lines.append(line)
if not any(line.startswith('AutoReconnect=') for line in lines): lines.append('AutoReconnect=0')
config_dir = overlay / 'etc/Wireless/RT2870STA'
config_dir.mkdir(parents=True)
(config_dir / profile.name).write_text('\n'.join(lines) + '\n')
shutil.copyfile(profile.parent / 'SingleSKU.dat', config_dir / 'SingleSKU.dat')
for source, target in [('h32-vendor-wifi', 'usr/local/sbin/h32-vendor-wifi'),
                       ('S97vendor-wifi', 'etc/init.d/S97vendor-wifi')]:
    dest = overlay / target
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(repo / 'work' / source, dest)
    dest.chmod(0o755)
source = repo / 'buildroot/rootfs-overlay/etc/init.d/S99mt5882'
text = source.read_text().replace('=== BUILDROOT P27 MODE ===', '=== BUILDROOT USB VENDOR MODE ===')
(overlay / 'etc/init.d/S99mt5882').write_text(text)
(overlay / 'etc/init.d/S99mt5882').chmod(0o755)
vendor.joinpath('README.txt').write_text(
    'Recovered original 3.10.27 modules. Only MT7603U is enabled automatically.\n'
    'Mali needs mtk_fb_get_property; audio needs AUD_* exports from the vendor stack.\n'
    'DTV and duplicate USB/storage modules are archived but NOT loaded.\n'
    'No Wi-Fi credentials included. h32vendor=0 disables Wi-Fi module autoload.\n')
vendor.joinpath('SHA256SUMS').write_text(''.join(
    hashlib.sha256(p.read_bytes()).hexdigest() + '  ' + p.relative_to(vendor).as_posix() + '\n'
    for p in sorted(vendor.rglob('*.ko'))))

# Replace only /init in the known-good gzip/newc bootstrap, preserving devices.
template = (repo / 'outputs/buildroot-h32m2600/uInitrd-h32m2600-bootstrap').read_bytes()
header = list(struct.unpack('>7I4B32s', template[:64]))
assert header[0] == 0x27051956 and header[6] == zlib.crc32(template[64:])
assert header[5] == 0 and header[4] == 0 and header[9] == 3 and header[10] == 1
raw = gzip.decompress(template[64:])
pos = 0
records = []
replaced = 0
while True:
    old = raw[pos:pos+110]
    assert old[:6] == b'070701'
    fields = [int(old[6+i*8:14+i*8], 16) for i in range(13)]
    name = raw[pos+110:pos+110+fields[11]]
    start = (pos + 110 + fields[11] + 3) & ~3
    data = raw[start:start+fields[6]]
    pos = (start + fields[6] + 3) & ~3
    if name.rstrip(b'\0') in (b'init', b'./init'):
        data = (repo / 'work/usb-vendor-init').read_bytes()
        replaced += 1
        fields[6] = len(data)
    record = b'070701' + b''.join(('%08x' % v).encode() for v in fields) + name
    record += b'\0' * ((-len(record)) % 4)
    record += data
    record += b'\0' * ((-len(record)) % 4)
    records.append(record)
    if name.rstrip(b'\0') == b'TRAILER!!!': break
assert replaced == 1
payload = gzip.compress(b''.join(records), compresslevel=9, mtime=0)
header[1] = 0
header[2] = int(time.time())
header[3] = len(payload)
header[6] = zlib.crc32(payload)
header[11] = b'H32 USB vendor v1'.ljust(32, b'\0')
header[1] = zlib.crc32(struct.pack('>7I4B32s', *header))
image = stage / 'uInitrd-h32m2600-usb-vendor-v1'
image.write_bytes(struct.pack('>7I4B32s', *header) + payload)
shutil.copyfile(repo / 'work/install-vendor-usb.sh', stage / 'install-vendor-usb.sh')
stage.joinpath('SHA256SUMS').write_text(''.join(
    hashlib.sha256(p.read_bytes()).hexdigest() + '  ' + p.relative_to(stage).as_posix() + '\n'
    for p in sorted(stage.rglob('*')) if p.is_file() and p != stage / 'SHA256SUMS'))
bundle = out / 'h32-vendor-v1.tar.gz'
with tarfile.open(bundle, 'w:gz') as tar:
    tar.add(stage, arcname='h32-vendor-v1')
print('initrd_bytes=' + str(image.stat().st_size))
print('bundle_sha256=' + hashlib.sha256(bundle.read_bytes()).hexdigest())
print('bundle_bytes=' + str(bundle.stat().st_size))
