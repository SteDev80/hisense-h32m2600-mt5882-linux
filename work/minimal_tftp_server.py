import socket
import struct
import sys
from pathlib import Path


ROOT = Path(sys.argv[1]).resolve()
ALLOWED = "uImage-mt5882-cbar"


def send_file(client, requested):
    if requested != ALLOWED:
        client.send(struct.pack("!HH", 5, 1) + b"File not found\0")
        return

    payload = (ROOT / ALLOWED).read_bytes()
    block = 1
    offset = 0
    while True:
        chunk = payload[offset:offset + 512]
        packet = struct.pack("!HH", 3, block) + chunk
        acknowledged = False
        for _ in range(8):
            client.send(packet)
            try:
                reply = client.recv(2048)
            except socket.timeout:
                continue
            if len(reply) >= 4:
                opcode, ack_block = struct.unpack("!HH", reply[:4])
                if opcode == 4 and ack_block == block:
                    acknowledged = True
                    break
        if not acknowledged:
            raise TimeoutError(f"No ACK for block {block}")
        offset += len(chunk)
        if len(chunk) < 512:
            print(f"[TFTP] Sent {len(payload)} bytes to {client.getpeername()}", flush=True)
            return
        block = (block + 1) & 0xFFFF


listener = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
listener.bind(("0.0.0.0", 69))
print(f"[TFTP] Serving {ROOT / ALLOWED} on UDP/69", flush=True)

while True:
    packet, peer = listener.recvfrom(2048)
    if len(packet) < 4 or struct.unpack("!H", packet[:2])[0] != 1:
        continue
    fields = packet[2:].split(b"\0")
    requested = fields[0].decode("ascii", "replace")
    print(f"[TFTP] RRQ {requested!r} from {peer}", flush=True)
    transfer = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    transfer.connect(peer)
    transfer.settimeout(1.0)
    try:
        send_file(transfer, requested)
    except Exception as exc:
        print(f"[TFTP] Transfer failed: {exc}", flush=True)
    finally:
        transfer.close()
