#!/usr/bin/python3
"""Topmost visual-mode button for the active FFplay audio window."""
import ctypes as C
import os
import re
import subprocess
import time
import tkinter as tk

os.environ.setdefault("DISPLAY", ":0")


def ffplay_window():
    try:
        listing = subprocess.check_output(["/usr/bin/xprop", "-root", "_NET_CLIENT_LIST"], text=True)
        for item in re.findall(r"0x[0-9a-fA-F]+", listing):
            properties = subprocess.check_output(
                ["/usr/bin/xprop", "-id", item, "WM_CLASS"], text=True,
                stderr=subprocess.DEVNULL)
            if "ffplay" in properties.lower():
                return int(item, 16)
    except (OSError, subprocess.SubprocessError):
        pass
    return None


window = None
for _ in range(100):
    window = ffplay_window()
    if window:
        break
    time.sleep(0.1)
if not window:
    raise SystemExit(0)

x11 = C.CDLL("libX11.so.6")
xtst = C.CDLL("libXtst.so.6")
x11.XOpenDisplay.argtypes = [C.c_char_p]
x11.XOpenDisplay.restype = C.c_void_p
x11.XSetInputFocus.argtypes = [C.c_void_p, C.c_ulong, C.c_int, C.c_ulong]
x11.XStringToKeysym.argtypes = [C.c_char_p]
x11.XStringToKeysym.restype = C.c_ulong
x11.XKeysymToKeycode.argtypes = [C.c_void_p, C.c_ulong]
x11.XKeysymToKeycode.restype = C.c_uint
x11.XFlush.argtypes = [C.c_void_p]
xtst.XTestFakeKeyEvent.argtypes = [C.c_void_p, C.c_uint, C.c_int, C.c_ulong]
display = x11.XOpenDisplay(os.environ["DISPLAY"].encode())
if not display:
    raise SystemExit(0)

modes = ["Spettro FFT", "Forma d'onda", "Video / copertina"]
mode = 0
root = tk.Tk()
root.title("Grafica audio")
root.overrideredirect(True)
root.attributes("-topmost", True)
root.configure(bg="#132239", padx=5, pady=5)
root.geometry(f"210x48+{max(10, root.winfo_screenwidth() - 230)}+18")


def change_mode():
    global mode
    target = ffplay_window()
    if not target:
        root.destroy()
        return
    x11.XSetInputFocus(display, C.c_ulong(target), 2, 0)
    symbol = x11.XStringToKeysym(b"w")
    keycode = x11.XKeysymToKeycode(display, symbol)
    xtst.XTestFakeKeyEvent(display, keycode, 1, 0)
    xtst.XTestFakeKeyEvent(display, keycode, 0, 0)
    x11.XFlush(display)
    mode = (mode + 1) % len(modes)
    button.configure(text=f"Grafica: {modes[mode]}  ›")


def monitor():
    if not ffplay_window():
        root.destroy()
    else:
        root.after(700, monitor)


button = tk.Button(root, text=f"Grafica: {modes[mode]}  ›", command=change_mode,
                   bg="#4dd7bb", fg="#101c30", activebackground="#8af0da",
                   activeforeground="#101c30", relief="flat", bd=0,
                   font=("DejaVu Sans", 10, "bold"), cursor="hand2")
button.pack(fill="both", expand=True)
monitor()
root.mainloop()
