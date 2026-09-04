"""Generate an original, quiet PCM startup chime (no downloaded media)."""
from pathlib import Path
import math
import struct
import wave

out = Path(__file__).resolve().parent.parent / 'outputs/ready-chime'
out.mkdir(exist_ok=True)
samples = bytearray()
rate = 48000
for frequency, duration in [(523.25, .24), (659.25, .24), (783.99, .24), (1046.5, .55)]:
    count = int(rate * duration)
    for i in range(count):
        t = i / rate
        envelope = min(1, t / .025) * min(1, (duration - t) / .12)
        value = .40 * envelope * math.sin(2 * math.pi * frequency * t)
        samples.extend(struct.pack('<h', int(value * 32767)))
    samples.extend(b'\0\0' * int(rate * .065))
with wave.open(str(out / 'ready.wav'), 'wb') as sound:
    sound.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
    sound.writeframes(samples)
print(out / 'ready.wav')
