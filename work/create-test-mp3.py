"""Generate a quiet ten-second test melody with lameenc (no external media)."""
import array
import math
import sys
from pathlib import Path

base = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(base / 'outputs/audio-generator-deps'))
import lameenc

rate = 22050
notes = [261.63, 329.63, 392.00, 523.25, 392.00]
samples = array.array('h')
for i in range(rate * 10):
    t = i / rate
    phase = t % 2
    envelope = max(0, min(1, phase / .08, (1.8 - phase) / .2))
    samples.append(int(4500 * envelope * math.sin(2 * math.pi * notes[int(t // 2)] * t)))
if sys.byteorder != 'little':
    samples.byteswap()
encoder = lameenc.Encoder()
encoder.set_bit_rate(64)
encoder.set_in_sample_rate(rate)
encoder.set_channels(1)
encoder.set_quality(2)
output = encoder.encode(samples.tobytes()) + encoder.flush()
target = base / 'outputs/Prova-audio-10-secondi.mp3'
target.write_bytes(output)
print(target, len(output))
