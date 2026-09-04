"""Accept one authenticated package into the confirmed USB filesystem only."""
import hashlib
import hmac
import http.server
import json
import os
import pathlib
import sys
import time

cfg = json.loads(pathlib.Path(sys.argv[1]).read_text())
dest = pathlib.Path(cfg['destination'])
usb_dev = os.stat('/proc/1/root/dev/sda2').st_rdev
if os.stat(dest.parent).st_dev != usb_dev or dest.exists():
    raise SystemExit('USB destination unavailable or already exists')


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args): pass

    def do_PUT(self):
        if self.client_address[0] != cfg['client_ip'] or not hmac.compare_digest(
                self.headers.get('X-Package-Key', ''), cfg['token']):
            self.send_error(403)
            return
        if self.path != '/package' or int(self.headers.get('Content-Length', 0)) != cfg['size']:
            self.send_error(400)
            return
        if os.stat(dest.parent).st_dev != usb_dev:
            self.send_error(409)
            return
        partial = dest.with_name(dest.name + '.partial')
        remaining = cfg['size']
        digest = hashlib.sha256()
        self.connection.settimeout(90)
        with partial.open('xb') as output:
            if os.fstat(output.fileno()).st_dev != usb_dev:
                raise RuntimeError('Not writing to USB')
            while remaining:
                chunk = self.rfile.read(min(131072, remaining))
                if not chunk: raise RuntimeError('Truncated upload')
                output.write(chunk)
                digest.update(chunk)
                remaining -= len(chunk)
            output.flush()
            os.fsync(output.fileno())
        if digest.hexdigest() != cfg['sha256']:
            self.send_error(422)
            return
        partial.rename(dest)
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain; charset=utf-8')
        self.end_headers()
        self.wfile.write(b'USB_PACKAGE_VERIFIED\n')
        self.server.complete = True
        print('UPLOAD_COMPLETE', flush=True)


server = http.server.HTTPServer((cfg['bind_ip'], 8099), Handler)
server.timeout = 2
server.complete = False
deadline = time.monotonic() + 900
print('UPLOAD_READY', flush=True)
try:
    while not server.complete and time.monotonic() < deadline:
        server.handle_request()
finally:
    server.server_close()
