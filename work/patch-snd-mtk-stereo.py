#!/usr/bin/env python3
"""Enable the advertised two-channel PCM mode in the verified H32 snd-mtk.ko."""
from hashlib import sha256
from pathlib import Path
import argparse

ORIGINAL_SHA256 = "fc93bbed1bea9bea5f6e5ed83de279c431d87c119005309b0dbb6d3c5a2be044"
PATCHED_SHA256 = "16991ef3f4026398a8b3a12bbda1967c892905ac3ecebb7d111c6bcbedfb0fba"
CHANNELS_MAX_OFFSET = 0x1D78

p = argparse.ArgumentParser(description="Patch the verified H32M2600 MT5882 ALSA module for stereo")
p.add_argument("source", type=Path)
p.add_argument("destination", type=Path)
args = p.parse_args()

data = bytearray(args.source.read_bytes())
digest = sha256(data).hexdigest()
if digest != ORIGINAL_SHA256:
    raise SystemExit(f"Refusing unknown module: SHA-256 is {digest}")
if len(data) <= CHANNELS_MAX_OFFSET or data[CHANNELS_MAX_OFFSET] != 1:
    raise SystemExit("Expected channels_max byte was not found")

data[CHANNELS_MAX_OFFSET] = 2
patched_digest = sha256(data).hexdigest()
if patched_digest != PATCHED_SHA256:
    raise SystemExit(f"Patched module verification failed: {patched_digest}")
args.destination.write_bytes(data)
print(f"Created {args.destination} ({patched_digest})")
