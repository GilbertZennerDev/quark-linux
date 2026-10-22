import socket, zlib, sqlite3
print("IMPORT-OK", zlib.crc32(b"abc"), sqlite3.sqlite_version, flush=True)
from http.server import HTTPServer, BaseHTTPRequestHandler
class H(BaseHTTPRequestHandler):
    def do_GET(s):
        b = b"hallo aus der VM " + s.path.encode()
        s.send_response(200)
        s.send_header("Content-Length", str(len(b)))
        s.end_headers()
        s.wfile.write(b)
    def log_message(s, *a):
        pass
print("SERVER-BEREIT", flush=True)
HTTPServer(("0.0.0.0", 8080), H).serve_forever()
