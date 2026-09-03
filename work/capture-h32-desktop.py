import ctypes as C
import struct
import zlib
from pathlib import Path

class XImage(C.Structure):
    _fields_=[('width',C.c_int),('height',C.c_int),('xoffset',C.c_int),('format',C.c_int),
              ('data',C.c_void_p),('byte_order',C.c_int),('bitmap_unit',C.c_int),
              ('bitmap_bit_order',C.c_int),('bitmap_pad',C.c_int),('depth',C.c_int),
              ('bytes_per_line',C.c_int),('bits_per_pixel',C.c_int),
              ('red_mask',C.c_ulong),('green_mask',C.c_ulong),('blue_mask',C.c_ulong)]
x=C.CDLL('libX11.so.6')
x.XOpenDisplay.argtypes=[C.c_char_p]; x.XOpenDisplay.restype=C.c_void_p
x.XDefaultRootWindow.argtypes=[C.c_void_p]; x.XDefaultRootWindow.restype=C.c_ulong
x.XDisplayWidth.argtypes=[C.c_void_p,C.c_int]; x.XDisplayHeight.argtypes=[C.c_void_p,C.c_int]
x.XGetImage.argtypes=[C.c_void_p,C.c_ulong,C.c_int,C.c_int,C.c_uint,C.c_uint,C.c_ulong,C.c_int]
x.XGetImage.restype=C.POINTER(XImage)
d=x.XOpenDisplay(b':0')
if not d: raise RuntimeError('No display')
w,h=x.XDisplayWidth(d,0),x.XDisplayHeight(d,0)
im=x.XGetImage(d,x.XDefaultRootWindow(d),0,0,w,h,0xffffffff,2).contents
data=C.string_at(im.data,im.bytes_per_line*h)
bpp=im.bits_per_pixel//8
masks=[im.red_mask,im.green_mask,im.blue_mask]
shifts=[(m & -m).bit_length()-1 for m in masks]
raw=bytearray()
lookup = [bytes(((pix & mask) >> shift) * 255 // (mask >> shift) for mask,shift in zip(masks,shifts)) for pix in range(65536)] if bpp == 2 else None
for y in range(h):
    raw.append(0)
    if lookup is not None:
        pixels=struct.unpack(('<' if im.byte_order==0 else '>')+str(w)+'H',data[y*im.bytes_per_line:y*im.bytes_per_line+w*2])
        raw.extend(b''.join(map(lookup.__getitem__,pixels)))
        continue
    for xx in range(w):
        off=y*im.bytes_per_line+xx*bpp
        pix=int.from_bytes(data[off:off+bpp], 'little' if im.byte_order==0 else 'big')
        for mask,shift in zip(masks,shifts): raw.append(((pix&mask)>>shift)*255//(mask>>shift))
def chunk(tag,payload):
    return struct.pack('!I',len(payload))+tag+payload+struct.pack('!I',zlib.crc32(tag+payload)&0xffffffff)
png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('!IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b'')
Path('/tmp/h32-preview').mkdir(exist_ok=True)
Path('/tmp/h32-preview/h32-desktop.png').write_bytes(png)
print('Screenshot:',w,h,len(png))
