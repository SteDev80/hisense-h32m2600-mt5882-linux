#!/usr/bin/python3
"""Learn MT5882 IR keys, dispatch desktop actions, and play local playlists."""
import argparse
import ctypes as C
import difflib
import fcntl
import json
import mmap
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import threading
import time
import tkinter as tk
from tkinter import filedialog, messagebox, ttk


HOST = Path("/proc/1/root")
ARCH = "/mnt/usb2/archlinux/rootfs"
CONFIG = Path("/root/.config/h32-ir-map.json")
VOLUME_CONFIG = Path("/root/.config/h32-volume")
LEARNING = Path("/tmp/h32-ir-learning")
MMIO_BASE = 0xF0028000
MMIO_SIZE = 0x1000
BG, PANEL, CARD, TEXT, MUTED, ACCENT = "#101c30", "#132239", "#21344f", "#edf4ff", "#9cb2cf", "#4dd7bb"

ACTIONS = [
    ("up", "Su", "Up"),
    ("down", "Giù", "Down"),
    ("left", "Sinistra", "Left"),
    ("right", "Destra", "Right"),
    ("ok", "OK / Conferma", "Return"),
    ("back", "Indietro", "Escape"),
    ("home", "Menu Start", None),
    ("volume_up", "Volume +", "0"),
    ("volume_down", "Volume −", "9"),
    ("play_pause", "Play / Pausa", "space"),
    ("stop", "Stop", "q"),
]


def safety_check():
    if os.uname().release != "3.10.27":
        raise RuntimeError("Kernel inatteso: operazione IR rifiutata.")
    mounts = (HOST / "proc/mounts").read_text().splitlines()
    if not any(line.startswith("/dev/sda2 / ") for line in mounts):
        raise RuntimeError("Il sistema non è avviato dalla USB.")
    if (HOST / "sys/block/mmcblk0/ro").read_text().strip() != "1":
        raise RuntimeError("eMMC non in sola lettura: operazione IR rifiutata.")


def load_config():
    try:
        data = json.loads(CONFIG.read_text(encoding="utf-8"))
        if data.get("version") == 1 and isinstance(data.get("bindings"), dict):
            return data
    except (OSError, ValueError):
        pass
    return {"version": 1, "bindings": {}}


def save_config(data):
    CONFIG.parent.mkdir(parents=True, exist_ok=True)
    temporary = CONFIG.with_suffix(".tmp")
    temporary.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    temporary.replace(CONFIG)


class RawReceiver:
    def __init__(self):
        safety_check()
        self.fd = os.open(HOST / "dev/mem", os.O_RDONLY | os.O_SYNC)
        self.memory = mmap.mmap(self.fd, MMIO_SIZE, mmap.MAP_SHARED, mmap.PROT_READ, offset=MMIO_BASE)

    def close(self):
        self.memory.close()
        os.close(self.fd)

    def snapshot(self):
        status = struct.unpack_from("<I", self.memory, 0x200)[0]
        raw = bytes(self.memory[0x2BC:0x308])
        return status, raw

    @staticmethod
    def signature(raw):
        widths = [value for value in raw if value]
        if len(widths) < 14:
            return None
        # MT5882 stores pulse widths in 50-us units. The tested remote uses
        # two duration families around 0x11 and 0x24; quantisation absorbs
        # normal timing jitter while retaining the complete code pattern.
        return "".join("L" if value >= 0x1A else "S" for value in widths)

    def read_frame(self, timeout=10.0):
        deadline = time.monotonic() + timeout
        _status, baseline = self.snapshot()
        candidate = None
        changed_at = None
        while time.monotonic() < deadline:
            _status, raw = self.snapshot()
            count = sum(value != 0 for value in raw)
            # The vendor ISR leaves the most recent frame in this buffer and
            # the status word can remain non-zero indefinitely.  Treating that
            # stale state as a new key made every learned button identical.
            # Wait for the pulse buffer itself to change, then allow it to
            # settle before producing a signature.
            if raw != baseline and count >= 14:
                if raw != candidate:
                    candidate = raw
                    changed_at = time.monotonic()
                elif changed_at and time.monotonic() - changed_at >= 0.018:
                    return self.signature(candidate)
            time.sleep(0.001)
        return None


class XKeys:
    def __init__(self):
        self.x11 = C.CDLL("libX11.so.6")
        self.xtst = C.CDLL("libXtst.so.6")
        self.x11.XOpenDisplay.argtypes = [C.c_char_p]
        self.x11.XOpenDisplay.restype = C.c_void_p
        self.x11.XStringToKeysym.argtypes = [C.c_char_p]
        self.x11.XStringToKeysym.restype = C.c_ulong
        self.x11.XKeysymToKeycode.argtypes = [C.c_void_p, C.c_ulong]
        self.x11.XKeysymToKeycode.restype = C.c_uint
        self.xtst.XTestFakeKeyEvent.argtypes = [C.c_void_p, C.c_uint, C.c_int, C.c_ulong]
        self.x11.XFlush.argtypes = [C.c_void_p]
        self.display = self.x11.XOpenDisplay(os.environ.get("DISPLAY", ":0").encode())
        if not self.display:
            raise RuntimeError("Display X11 :0 non disponibile")

    def press(self, name):
        symbol = self.x11.XStringToKeysym(name.encode())
        code = self.x11.XKeysymToKeycode(self.display, symbol)
        if not code:
            return
        self.xtst.XTestFakeKeyEvent(self.display, code, 1, 0)
        self.xtst.XTestFakeKeyEvent(self.display, code, 0, 0)
        self.x11.XFlush(self.display)


def similarity(left, right):
    return difflib.SequenceMatcher(None, left, right, autojunk=False).ratio()


def display_code(signature):
    """Render the quantised raw pulse train as a compact hexadecimal code."""
    bits = signature.replace("S", "0").replace("L", "1")
    width = (len(bits) + 3) // 4
    return "0x" + format(int(bits, 2), f"0{width}X")


def dispatch(action, xkeys):
    if action == "home":
        subprocess.Popen(["/usr/bin/fluxbox-remote", "RootMenu"], stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
        return
    if action in ("volume_up", "volume_down"):
        try:
            current = int(VOLUME_CONFIG.read_text().strip())
        except (OSError, ValueError):
            current = 10
        current = max(0, min(100, current + (10 if action == "volume_up" else -10)))
        VOLUME_CONFIG.parent.mkdir(parents=True, exist_ok=True)
        VOLUME_CONFIG.write_text(str(current) + "\n")
    keysym = next((key for name, _label, key in ACTIONS if name == action), None)
    if keysym:
        xkeys.press(keysym)


def daemon():
    lock = open("/tmp/h32-ir-daemon.lock", "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return 0
    receiver = RawReceiver()
    xkeys = XKeys()
    last_signature, last_time = None, 0.0
    print("H32_IR_DAEMON_READY", flush=True)
    try:
        while True:
            if LEARNING.exists():
                time.sleep(0.1)
                continue
            signature = receiver.read_frame(timeout=1.0)
            if not signature:
                continue
            now = time.monotonic()
            if signature == last_signature and now - last_time < 0.22:
                continue
            bindings = load_config()["bindings"]
            candidates = [(similarity(signature, item.get("signature", "")), action)
                          for action, item in bindings.items()]
            if not candidates:
                continue
            score, action = max(candidates)
            if score >= 0.82:
                dispatch(action, xkeys)
                print(f"KEY {action} score={score:.3f}", flush=True)
                last_signature, last_time = signature, now
    finally:
        receiver.close()


def playlist_entries(path):
    path = Path(path)
    lines = path.read_text(encoding="utf-8-sig", errors="replace").splitlines()
    entries = []
    if path.suffix.lower() == ".pls":
        values = {}
        for line in lines:
            match = re.match(r"File(\d+)=(.*)", line, re.I)
            if match:
                values[int(match.group(1))] = match.group(2).strip()
        source = [values[index] for index in sorted(values)]
    else:
        source = [line.strip() for line in lines if line.strip() and not line.lstrip().startswith("#")]
    for item in source:
        if re.match(r"^[a-z]+://", item, re.I):
            entries.append(item)
        else:
            candidate = Path(item)
            entries.append(str(candidate if candidate.is_absolute() else path.parent / candidate))
    return entries


class Manager:
    def __init__(self):
        safety_check()
        self.data = load_config()
        self.root = tk.Tk()
        self.root.title("Telecomando IR e Playlist · H32 Linux")
        self.root.geometry("760x620+125+55")
        self.root.configure(bg=BG, padx=18, pady=16)
        style = ttk.Style(self.root)
        style.theme_use("clam")
        style.configure("TNotebook", background=BG, borderwidth=0)
        style.configure("TNotebook.Tab", background=CARD, foreground=TEXT, padding=(16, 9))
        style.map("TNotebook.Tab", background=[("selected", ACCENT)], foreground=[("selected", BG)])
        tabs = ttk.Notebook(self.root)
        tabs.pack(fill="both", expand=True)
        self.remote_tab = tk.Frame(tabs, bg=BG, padx=14, pady=14)
        self.playlist_tab = tk.Frame(tabs, bg=BG, padx=14, pady=14)
        tabs.add(self.remote_tab, text="Telecomando")
        tabs.add(self.playlist_tab, text="Playlist")
        self.status = tk.StringVar(value="Scegli una funzione e premi Registra.")
        self.code_display = tk.StringVar(value="Nessun codice letto")
        self.rows = {}
        self.build_remote()
        self.build_playlist()
        self.root.mainloop()

    def label(self, parent, text, size=10, color=TEXT, bold=False):
        widget = tk.Label(parent, text=text, bg=parent.cget("bg"), fg=color,
                          font=("DejaVu Sans", size, "bold" if bold else "normal"))
        return widget

    def button(self, parent, text, command, accent=False):
        return tk.Button(parent, text=text, command=command, bg=ACCENT if accent else CARD,
                         fg=BG if accent else TEXT, activebackground="#345474", bd=0,
                         padx=12, pady=7, font=("DejaVu Sans", 9), cursor="hand2")

    def build_remote(self):
        self.label(self.remote_tab, "Apprendimento telecomando IR", 20, TEXT, True).pack(anchor="w")
        self.label(self.remote_tab, "La configurazione viene salvata esclusivamente sulla chiavetta USB.", 9, ACCENT).pack(anchor="w", pady=(2, 10))
        code_card = tk.Frame(self.remote_tab, bg="#07121f", highlightbackground=ACCENT,
                             highlightthickness=2, padx=12, pady=9)
        code_card.pack(fill="x", pady=(0, 10))
        self.label(code_card, "CODICE IR RILEVATO", 9, MUTED, True).pack(anchor="w")
        tk.Label(code_card, textvariable=self.code_display, bg="#07121f", fg=ACCENT,
                 anchor="w", font=("DejaVu Sans Mono", 12, "bold"),
                 wraplength=570).pack(side="left", fill="x", expand=True, pady=(3, 0))
        self.button(code_card, "Leggi codice", self.read_code, True).pack(side="right", padx=(8, 0))
        frame = tk.Frame(self.remote_tab, bg=BG)
        frame.pack(fill="both", expand=True)
        for action, title, _key in ACTIONS:
            row = tk.Frame(frame, bg=CARD, padx=10, pady=5)
            row.pack(fill="x", pady=2)
            self.label(row, title, 10, TEXT, True).pack(side="left")
            state = tk.Label(row, bg=CARD, fg=MUTED, width=13,
                             text="Configurato" if action in self.data["bindings"] else "Non registrato")
            state.pack(side="right", padx=8)
            self.button(row, "Registra", lambda selected=action: self.learn(selected), True).pack(side="right")
            self.button(row, "Prova", lambda selected=action: self.test(selected)).pack(side="right", padx=5)
            self.rows[action] = state
        self.label(self.remote_tab, "Non associare il tasto Power durante le prove.", 9, "#ffbd74").pack(anchor="w", pady=(8, 2))
        self.label(self.remote_tab, "", 10).configure(textvariable=self.status)
        status = tk.Label(self.remote_tab, textvariable=self.status, bg=BG, fg=TEXT, anchor="w")
        status.pack(fill="x", pady=(3, 0))

    def learn(self, action):
        if LEARNING.exists():
            return
        LEARNING.write_text(str(os.getpid()))
        self.status.set("In ascolto: premi una volta il tasto desiderato…")
        self.code_display.set("In ascolto…")
        def worker():
            receiver = None
            try:
                receiver = RawReceiver()
                signature = receiver.read_frame(timeout=12.0)
                if not signature:
                    raise RuntimeError("Nessun segnale completo ricevuto entro 12 secondi.")
                duplicates = [name for name, item in self.data["bindings"].items()
                              if name != action and item.get("signature") == signature]
                if duplicates:
                    raise RuntimeError("Questo segnale è già associato a: " + ", ".join(duplicates))
                self.data["bindings"][action] = {"signature": signature, "learned": int(time.time())}
                save_config(self.data)
                self.root.after(0, lambda: self.learned(action, len(signature)))
            except Exception as exc:
                self.root.after(0, lambda error=str(exc): self.learn_failed(error))
            finally:
                if receiver:
                    receiver.close()
                try:
                    LEARNING.unlink()
                except OSError:
                    pass
        threading.Thread(target=worker, daemon=True).start()

    def learned(self, action, pulses):
        self.rows[action].configure(text="Configurato", fg=ACCENT)
        self.code_display.set(display_code(self.data["bindings"][action]["signature"]))
        self.status.set(f"Tasto registrato ({pulses} impulsi). Puoi provarlo dal telecomando.")

    def learn_failed(self, error):
        self.code_display.set("Nessun codice ricevuto")
        self.status.set(error)
        messagebox.showerror("Registrazione IR", error, parent=self.root)

    def read_code(self):
        if LEARNING.exists():
            return
        LEARNING.write_text(str(os.getpid()))
        self.code_display.set("In ascolto…")
        self.status.set("Premi una volta un tasto del telecomando.")

        def worker():
            receiver = None
            try:
                receiver = RawReceiver()
                signature = receiver.read_frame(timeout=12.0)
                if not signature:
                    raise RuntimeError("Nessun segnale completo ricevuto entro 12 secondi.")
                code = display_code(signature)
                self.root.after(0, lambda: self.code_read(code, len(signature)))
            except Exception as exc:
                self.root.after(0, lambda error=str(exc): self.learn_failed(error))
            finally:
                if receiver:
                    receiver.close()
                try:
                    LEARNING.unlink()
                except OSError:
                    pass

        threading.Thread(target=worker, daemon=True).start()

    def code_read(self, code, pulses):
        self.code_display.set(code)
        self.status.set(f"Codice letto correttamente ({pulses} impulsi).")

    def test(self, action):
        try:
            dispatch(action, XKeys())
            self.status.set("Funzione inviata al desktop: " + action)
        except Exception as exc:
            messagebox.showerror("Prova funzione", str(exc), parent=self.root)

    def build_playlist(self):
        self.label(self.playlist_tab, "Lettore playlist", 20, TEXT, True).pack(anchor="w")
        self.label(self.playlist_tab, "Formati M3U, M3U8 e PLS · audio dagli altoparlanti TV", 9, ACCENT).pack(anchor="w", pady=(2, 10))
        bar = tk.Frame(self.playlist_tab, bg=BG)
        bar.pack(fill="x")
        self.playlist_name = tk.StringVar(value="Nessuna playlist aperta")
        self.label(bar, "", 10).configure(textvariable=self.playlist_name)
        tk.Label(bar, textvariable=self.playlist_name, bg=BG, fg=TEXT, anchor="w").pack(side="left", fill="x", expand=True)
        self.button(bar, "Apri playlist", self.open_playlist, True).pack(side="right")
        self.track_list = tk.Listbox(self.playlist_tab, bg=CARD, fg=TEXT, selectbackground="#345474",
                                     font=("DejaVu Sans", 10), activestyle="none")
        self.track_list.pack(fill="both", expand=True, pady=10)
        controls = tk.Frame(self.playlist_tab, bg=BG)
        controls.pack(fill="x")
        self.button(controls, "Riproduci selezionato", self.play_selected, True).pack(side="left")
        self.button(controls, "Riproduci tutto", self.play_all).pack(side="left", padx=6)
        self.button(controls, "Stop", self.stop_playlist).pack(side="left")
        self.playlist = []
        self.player = None
        self.stop_event = threading.Event()
        self.track_list.bind("<Double-Button-1>", lambda _event: self.play_selected())

    def open_playlist(self):
        path = filedialog.askopenfilename(parent=self.root, title="Apri playlist",
                                          initialdir="/srv/condivisa",
                                          filetypes=[("Playlist", "*.m3u *.m3u8 *.pls"), ("Tutti i file", "*")])
        if not path:
            return
        try:
            self.playlist = playlist_entries(path)
        except OSError as exc:
            messagebox.showerror("Playlist", str(exc), parent=self.root)
            return
        self.playlist_name.set(f"{Path(path).name} · {len(self.playlist)} elementi")
        self.track_list.delete(0, "end")
        for item in self.playlist:
            self.track_list.insert("end", Path(item).name if "://" not in item else item)

    def host_media_command(self, item):
        target = item if "://" in item else ARCH + item
        return ["chroot", str(HOST), "/usr/local/bin/h32-media-play", "-i", target]

    def play_item(self, item):
        self.player = subprocess.Popen(self.host_media_command(item), start_new_session=True)
        return self.player.wait()

    def play_selected(self):
        choice = self.track_list.curselection()
        if not choice:
            return
        self.stop_playlist()
        threading.Thread(target=self.play_item, args=(self.playlist[choice[0]],), daemon=True).start()

    def play_all(self):
        if not self.playlist:
            return
        self.stop_playlist()
        self.stop_event.clear()
        start = self.track_list.curselection()[0] if self.track_list.curselection() else 0
        def worker():
            for index in range(start, len(self.playlist)):
                if self.stop_event.is_set():
                    break
                self.root.after(0, lambda i=index: self.track_list.selection_clear(0, "end"))
                self.root.after(0, lambda i=index: self.track_list.selection_set(i))
                self.play_item(self.playlist[index])
        threading.Thread(target=worker, daemon=True).start()

    def stop_playlist(self):
        self.stop_event.set()
        if self.player and self.player.poll() is None:
            self.player.terminate()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--daemon", action="store_true")
    args = parser.parse_args()
    if args.daemon:
        return daemon()
    Manager()
    return 0


if __name__ == "__main__":
    sys.exit(main())
