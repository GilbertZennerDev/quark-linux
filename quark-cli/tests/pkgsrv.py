# Kleiner Paketserver fuer die Plugin-Tests: pkgsrv.py <Ordner> [Port]
# Der Standard-Server "python -m http.server" bleibt bei grossen Dateien (z. B. vim_common.apk, 8 MB) haengen;
# dieser hier sendet in 16-KB-Stuecken und liefert sie zuverlaessig aus.
import http.server, socketserver, os, sys
D = sys.argv[1]
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 8000
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        p = os.path.join(D, self.path.lstrip('/'))
        if not os.path.isfile(p): self.send_error(404); return
        self.send_response(200); self.send_header('Content-Length', str(os.path.getsize(p))); self.end_headers()
        with open(p, 'rb') as f:
            while True:
                b = f.read(16384)
                if not b: break
                try: self.wfile.write(b)
                except Exception: return
    def log_message(self, *a): pass
socketserver.ThreadingTCPServer.allow_reuse_address = True
socketserver.ThreadingTCPServer(('127.0.0.1', PORT), H).serve_forever()
