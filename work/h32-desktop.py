#!/usr/bin/python3
"""Small X11 desktop companion; runs in the USB Arch chroot, not systemd."""
import datetime
import os
import fcntl
import sys
from pathlib import Path
import subprocess
import tkinter as tk
from tkinter import messagebox, filedialog, simpledialog

BG, PANEL, CARD, TEXT, MUTED, ACCENT = '#101c30', '#132239', '#21344f', '#edf4ff', '#9cb2cf', '#4dd7bb'
HOST = '/proc/1/root'
ARCH = '/mnt/usb2/archlinux/rootfs'
CATALOG = [
    ('builtin-files', 'File manager', 'Gestore leggero integrato: cartelle e file USB', ['builtin-files']),
    ('mousepad', 'Editor di testo', 'Documenti e configurazioni', ['mousepad']),
    ('galculator', 'Calcolatrice', 'Calcoli semplici e scientifici', ['galculator']),
    ('xarchiver', 'Archivi', 'Aprire e creare archivi compressi', ['xarchiver']),
    ('geany', 'Editor di codice', 'Editor leggero per programmare', ['geany']),
    ('htop', 'Monitor sistema', 'Memoria e processi nel terminale', ['htop']),
    ('nano', 'Nano', 'Editor nel terminale', ['nano']),
    ('builtin-video', 'Lettore video', 'FFplay del sistema USB: scegli un file locale', ['builtin-video']),
]

def host(*args):
    return ['chroot', HOST, *args]

def spawn(argv):
    try:
        with open('/tmp/h32-applications.log', 'a') as log:
            subprocess.Popen(argv, stdout=log, stderr=log, start_new_session=True)
    except OSError as exc:
        messagebox.showerror('Avvio non riuscito', str(exc))

def terminal(title, argv):
    spawn(host('xterm', '-title', title, '-geometry', '100x28', '-bg', '#101c30',
               '-fg', '#edf4ff', '-e', *argv))

def button(parent, text, command, accent=False):
    return tk.Button(parent, text=text, command=command, bg=ACCENT if accent else CARD,
                     fg=BG if accent else TEXT, activebackground='#345474',
                     activeforeground=TEXT, bd=0, padx=14, pady=10,
                     font=('DejaVu Sans', 10), cursor='hand2', relief='flat')

class Desktop:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title('H32 Desktop')
        self.root.overrideredirect(True)
        self.w, self.h = self.root.winfo_screenwidth(), self.root.winfo_screenheight()
        self.root.geometry(f'{self.w}x{self.h}+0+0')
        self.canvas = tk.Canvas(self.root, bg=BG, highlightthickness=0)
        self.canvas.pack(fill='both', expand=True)
        self.settings = Path('/root/.config/h32-wallpaper')
        try:
            self.wallpaper = int(self.settings.read_text()) % 2
        except (OSError, ValueError):
            self.wallpaper = 0
        self.paint()
        self.root.update_idletasks()
        self.root.lower()
        self.canvas.bind('<Button-3>', lambda e: self.menu())
        self.dock = tk.Toplevel(self.root, bg=PANEL)
        self.dock.overrideredirect(True)
        self.dock.geometry(f'{self.w}x54+0+{self.h-54}')
        self.dock.attributes('-topmost', True)
        button(self.dock, '◈  START', self.menu, True).pack(side='left', padx=10, pady=7)
        button(self.dock, 'Programmi', self.software).pack(side='left', padx=3)
        button(self.dock, 'Terminale', lambda: terminal('Arch Linux ARM', ['/usr/local/sbin/h32-arch-login'])).pack(side='left', padx=3)
        button(self.dock, 'Wi-Fi', self.wifi).pack(side='left', padx=3)
        button(self.dock, 'Desktop', lambda: spawn(host('fluxbox-remote', 'ShowDesktop'))).pack(side='left', padx=3)
        self.clock = tk.Label(self.dock, bg=PANEL, fg=TEXT, font=('DejaVu Sans', 10), padx=18)
        self.clock.pack(side='right')
        self.popup = None
        self.tick()
        self.root.after(100, self.root.lower)
        if '--programs' in sys.argv:
            self.root.after(500, self.software)
        if '--files' in sys.argv:
            self.root.after(500, self.files)
        self.root.mainloop()

    def paint(self):
        c, w, h = self.canvas, self.w, self.h
        c.delete('all')
        palettes = [('#101c30', '#1e3a52', '#25535b', '#4dd7bb'),
                    ('#211b32', '#3a294e', '#574366', '#dfa4d9')]
        bg, a, b, accent = palettes[self.wallpaper % len(palettes)]
        c.configure(bg=bg)
        c.create_polygon(w*.38, h, w*.72, h*.12, w*1.2, h, fill=a, outline='')
        c.create_polygon(w*.57, h, w*.88, h*.35, w*1.2, h, fill=b, outline='')
        c.create_line(w*.72, h*.12, w*.93, h*.49, fill=accent, width=2)
        c.create_text(58, 68, anchor='nw', text='H32 / LINUX', fill=TEXT,
                      font=('DejaVu Sans', 29, 'bold'))
        c.create_text(60, 119, anchor='nw', text='Un nuovo spazio per la tua TV.', fill=MUTED,
                      font=('DejaVu Sans', 13))
        c.create_text(60, h-91, anchor='sw', text='ARCH ARM  /  FLUXBOX  /  USB EDITION', fill=MUTED,
                      font=('DejaVu Sans', 9))
        for idx, (title, subtitle, callback) in enumerate([
            ('Programmi', 'Installa e apri applicazioni', self.software),
            ('Home Assistant', 'Indirizzo per il browser del PC', self.homeassistant),
            ('Personalizza', 'Cambia i colori dello sfondo', self.change_wallpaper)]):
            y = 196 + idx*91
            tag = f'card{idx}'
            c.create_rectangle(60, y, 367, y+73, fill=PANEL, outline='#2b415c', tags=tag)
            c.create_text(80, y+22, text=title, anchor='w', fill=TEXT, font=('DejaVu Sans', 12, 'bold'), tags=tag)
            c.create_text(80, y+49, text=subtitle, anchor='w', fill=MUTED, font=('DejaVu Sans', 9), tags=tag)
            c.tag_bind(tag, '<Button-1>', lambda e, fn=callback: fn())

    def tick(self):
        self.clock.configure(text=datetime.datetime.now().strftime('%d/%m  %H:%M'))
        self.root.after(1000, self.tick)

    def window(self, title, size='650x480'):
        win = tk.Toplevel(self.root, bg=BG)
        win.title(title)
        win.geometry(size + '+180+70')
        win.configure(padx=22, pady=20)
        return win

    def change_wallpaper(self):
        self.wallpaper += 1
        self.settings.parent.mkdir(parents=True, exist_ok=True)
        self.settings.write_text(str(self.wallpaper % 2))
        self.paint()
        self.root.lower()

    def homeassistant(self):
        messagebox.showinfo('Home Assistant', 'Apri sul PC o sul telefono:\nhttp://192.168.1.52:8123\n\nL’indirizzo può cambiare con DHCP.\nIl browser Dillo non supporta questa interfaccia moderna.', parent=self.root)

    def wifi(self):
        terminal('Stato Wi-Fi', ['/bin/sh', '-c', '/usr/local/sbin/h32-wifi-status; printf "\\nPremi Invio per chiudere"; read answer'])

    def menu(self):
        if self.popup is not None and self.popup.winfo_exists():
            self.popup.destroy()
            self.popup = None
            return
        win = self.popup = self.window('Start', '335x490')
        win.geometry(f'335x490+10+{max(0,self.h-558)}')
        tk.Label(win, text='H32 Linux', bg=BG, fg=TEXT, font=('DejaVu Sans', 20, 'bold')).pack(anchor='w', pady=(0,14))
        actions = [
            ('Programmi / installa applicazioni', self.software),
            ('Terminale Arch', lambda: terminal('Arch Linux ARM', ['/usr/local/sbin/h32-arch-login'])),
            ('Terminale Buildroot', lambda: terminal('Buildroot', ['/bin/sh'])),
            ('Browser Dillo', lambda: spawn(host('dillo'))),
            ('Home Assistant', self.homeassistant),
            ('Stato Wi-Fi', self.wifi),
            ('Cambia sfondo', self.change_wallpaper),
            ('Spegni Linux…', self.shutdown),
        ]
        for label, fn in actions:
            button(win, label, fn).pack(fill='x', pady=3)
        win.bind('<Escape>', lambda e: win.destroy())

    def shutdown(self):
        if messagebox.askyesno('Spegni Linux', 'Arrestare Linux? Non estrarre la USB prima dell’arresto.', parent=self.root):
            spawn(host('/sbin/poweroff'))

    def software(self):
        win = self.window('Programmi · Arch Linux ARM', '730x600')
        tk.Label(win, text='Programmi', font=('DejaVu Sans', 23, 'bold'), bg=BG, fg=TEXT).pack(anchor='w')
        tk.Label(win, text='Installazione sulla USB · nessuna modifica al firmware TV', bg=BG, fg=ACCENT).pack(anchor='w', pady=(3,7))
        tk.Label(win, text='Kernel 3.10: la disponibilità nel catalogo non garantisce la compatibilità.\nPrima di installare vedrai pacchetti, dimensioni e richiesta di conferma.',
                 bg=BG, fg=MUTED, justify='left').pack(anchor='w', pady=(0,12))
        container = tk.Frame(win, bg=BG)
        container.pack(fill='both', expand=True)
        scroll = tk.Scrollbar(container)
        scroll.pack(side='right', fill='y')
        viewport = tk.Canvas(container, bg=BG, highlightthickness=0, yscrollcommand=scroll.set)
        viewport.pack(side='left', fill='both', expand=True)
        scroll.configure(command=viewport.yview)
        listing = tk.Frame(viewport, bg=BG)
        item = viewport.create_window(0, 0, window=listing, anchor='nw')
        viewport.bind('<Configure>', lambda e: viewport.itemconfigure(item, width=e.width))
        listing.bind('<Configure>', lambda e: viewport.configure(scrollregion=viewport.bbox('all')))
        def refresh():
            for child in listing.winfo_children(): child.destroy()
            for package, title, desc, argv in CATALOG:
                installed = package.startswith('builtin-') or subprocess.run(['pacman', '-Q', package], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
                row = tk.Frame(listing, bg=CARD, padx=12, pady=7)
                row.pack(fill='x', pady=3)
                action = (lambda a=argv, t=title: self.open_app(a,t)) if installed else (lambda p=package: self.install(p))
                button(row, 'Apri' if installed else 'Installa', action, not installed).pack(side='right')
                tk.Label(row, text=title, bg=CARD, fg=TEXT, font=('DejaVu Sans',10,'bold')).pack(anchor='w')
                tk.Label(row, text=desc, bg=CARD, fg=MUTED, font=('DejaVu Sans',9)).pack(anchor='w')
        button(win, 'Aggiorna elenco dopo l’installazione', refresh).pack(fill='x', pady=(8,0))
        refresh()

    def install(self, package):
        terminal('Installa '+package, ['chroot', ARCH, '/usr/bin/bash', '/usr/local/bin/h32-package-task', package])

    def open_app(self, argv, title):
        if argv[0] == 'builtin-files':
            self.files()
        elif argv[0] == 'builtin-video':
            self.video()
        elif argv[0] in ('htop', 'nano'):
            terminal(title, ['chroot', ARCH, '/usr/bin/env', 'TERM=xterm', *argv])
        else:
            spawn(argv)

    def video(self, path=None):
        path = path or filedialog.askopenfilename(parent=self.root, title='Scegli un video', initialdir='/root')
        if not path:
            return
        # This is a host player: map the selected chroot filename to the USB.
        # SDL initializes audio even for silent videos; no ALSA device exists
        # on this vendor-kernel setup. Dummy audio keeps video playback usable.
        if Path(path).suffix.lower() in ('.mp3', '.wav', '.ogg', '.flac'):
            messagebox.showinfo('Audio non disponibile', 'Il file verrà aperto, ma non si sentirà: Linux non rileva una scheda audio e VNC non trasporta audio.', parent=self.root)
        terminal('Lettore · q per uscire', ['/usr/bin/env', 'SDL_RENDER_DRIVER=software', 'SDL_AUDIODRIVER=dummy', '/usr/bin/ffplay', '-nostats', '-loglevel', 'error', '-autoexit', '-x', '800', '-y', '450', '-i', ARCH + path])

    def files(self):
        win = self.window('File manager · USB', '730x560')
        current = tk.StringVar(value='/root')
        bar = tk.Frame(win, bg=BG)
        bar.pack(fill='x')
        location = tk.Entry(bar, textvariable=current, font=('DejaVu Sans', 11))
        location.pack(side='left', fill='x', expand=True)
        listing = tk.Listbox(win, bg=CARD, fg=TEXT, selectbackground='#345474', font=('DejaVu Sans', 11))
        listing.pack(fill='both', expand=True, pady=10)
        entries = []
        def refresh():
            try:
                folder = Path(current.get()).resolve(strict=True)
                if not folder.is_dir():
                    raise ValueError('Seleziona una cartella.')
                items = sorted(folder.iterdir(), key=lambda p: (not p.is_dir(), p.name.lower()))
                current.set(str(folder))
                entries[:] = items
                listing.delete(0, 'end')
                for p in items:
                    listing.insert('end', ('[Cartella]  ' if p.is_dir() else '             ') + p.name)
            except (OSError, ValueError) as exc:
                messagebox.showerror('Cartella non accessibile', str(exc), parent=win)
        def selected():
            choice = listing.curselection()
            return entries[choice[0]] if choice else None
        def open_selected():
            p = selected()
            if p is None: return
            if p.is_dir():
                current.set(str(p)); refresh()
            elif p.suffix.lower() in ('.mp4','.mkv','.avi','.mov','.webm','.mp3','.wav','.ts','.mpeg','.mpg'):
                self.video(str(p))
            else:
                terminal('Modifica · '+p.name, ['chroot', ARCH, '/usr/bin/nano', str(p)])
        def up():
            current.set(str(Path(current.get()).parent)); refresh()
        def new_folder():
            name = simpledialog.askstring('Nuova cartella', 'Nome della cartella:', parent=win)
            if not name: return
            if name in ('.','..') or '/' in name:
                messagebox.showerror('Nome non valido', 'Usa un nome semplice senza slash.', parent=win); return
            try:
                (Path(current.get()) / name).mkdir(); refresh()
            except OSError as exc:
                messagebox.showerror('Creazione non riuscita', str(exc), parent=win)
        button(bar, 'Vai', refresh).pack(side='left', padx=5)
        actions = tk.Frame(win, bg=BG); actions.pack(fill='x')
        for label, action in [('Su', up), ('Apri', open_selected), ('Nuova cartella', new_folder), ('Aggiorna', refresh)]:
            button(actions, label, action).pack(side='left', padx=3)
        listing.bind('<Double-Button-1>', lambda e: open_selected())
        location.bind('<Return>', lambda e: refresh())
        refresh()

if __name__ == '__main__':
    lock = open('/tmp/h32-desktop.lock', 'w')
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        sys.exit(0)
    Desktop()
