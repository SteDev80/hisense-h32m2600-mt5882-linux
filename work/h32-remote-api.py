#!/usr/bin/python3
import json
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

PIN_FILE = Path('/root/.config/h32-remote-pin')
VOLUME_FILE = Path('/root/.config/h32-volume')
HOST_SERVICE = ['/usr/bin/chroot', '/proc/1/root', '/usr/local/sbin/h32-scream-service']


def pin():
    try:
        return PIN_FILE.read_text().strip()
    except OSError:
        return '2600'


def volume():
    try:
        return max(0, min(100, int(VOLUME_FILE.read_text().strip())))
    except (OSError, ValueError):
        return 10


def set_volume(value):
    value = max(0, min(100, int(value)))
    VOLUME_FILE.parent.mkdir(parents=True, exist_ok=True)
    VOLUME_FILE.write_text(f'{value}\n')
    subprocess.run(HOST_SERVICE + ['volume', str(value)], check=True)
    return value


def delayed_power(command):
    time.sleep(1)
    subprocess.run(['/usr/bin/chroot', '/proc/1/root', '/sbin/' + command])


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def reply(self, status, payload):
        data = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def request(self):
        query = parse_qs(urlparse(self.path).query)
        if query.get('pin', [''])[0] != pin():
            self.reply(403, {'ok': False, 'message': 'PIN non valido'})
            return
        route = urlparse(self.path).path
        if route == '/status':
            result = subprocess.run(HOST_SERVICE + ['status'], text=True, capture_output=True)
            self.reply(200, {'ok': True, 'volume': volume(), 'audio': result.stdout})
            return
        if route != '/action':
            self.reply(404, {'ok': False, 'message': 'Comando sconosciuto'})
            return
        action = query.get('name', [''])[0]
        try:
            if action == 'volume_up':
                value = set_volume(volume() + 2)
            elif action == 'volume_down':
                value = set_volume(volume() - 2)
            elif action == 'mute':
                value = set_volume(0)
            elif action == 'audio_start':
                subprocess.run(HOST_SERVICE + ['start'], check=True); value = volume()
            elif action == 'audio_stop':
                subprocess.run(HOST_SERVICE + ['stop'], check=True); value = volume()
            elif action in ('reboot', 'poweroff'):
                threading.Thread(target=delayed_power, args=(action,), daemon=True).start(); value = volume()
            else:
                self.reply(400, {'ok': False, 'message': 'Azione non valida'}); return
            self.reply(200, {'ok': True, 'action': action, 'volume': value})
        except (OSError, ValueError, subprocess.SubprocessError) as exc:
            self.reply(500, {'ok': False, 'message': str(exc)})

    do_GET = request
    do_POST = request


ThreadingHTTPServer(('0.0.0.0', 8766), Handler).serve_forever()
