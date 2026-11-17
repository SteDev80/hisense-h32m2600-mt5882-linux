#!/usr/bin/env python3
"""Send a quiet one-second Scream-compatible PCM test tone."""
import math
import socket
import struct
import time

RATE = 48000
FRAMES_PER_PACKET = 288
AMPLITUDE = 160
HEADER = bytes((1, 16, 2, 3, 0))  # 48 kHz, S16LE, stereo, FL|FR

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 1)
destination = ("239.255.77.77", 4010)
started = time.perf_counter()
for base in range(0, RATE, FRAMES_PER_PACKET):
    pcm = bytearray()
    for frame in range(base, min(base + FRAMES_PER_PACKET, RATE)):
        sample = round(AMPLITUDE * math.sin(2 * math.pi * 440 * frame / RATE))
        pcm += struct.pack("<hh", sample, sample)
    sock.sendto(HEADER + pcm, destination)
    target = started + min(base + FRAMES_PER_PACKET, RATE) / RATE
    delay = target - time.perf_counter()
    if delay > 0:
        time.sleep(delay)
print("SCREAM_TEST_TONE_SENT")
