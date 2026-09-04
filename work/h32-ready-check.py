"""Readiness probe run in the Arch chroot. No changes to desktop state."""
import socket
import tkinter

try:
    with socket.create_connection(('127.0.0.1', 5900), timeout=2) as conn:
        conn.settimeout(2)
        if not conn.recv(12).startswith(b'RFB '):
            raise RuntimeError('VNC is not ready')
    with socket.create_connection(('127.0.0.1', 445), timeout=2):
        pass
    root = tkinter.Tk()
    root.withdraw()
    root.update_idletasks()
    root.destroy()
except Exception:
    raise SystemExit(1)
