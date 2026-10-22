import socket, time, os
s = socket.create_connection(('127.0.0.1', 20023), timeout=20)
s.sendall(os.environ.get('CMD', 'echo VERBUNDEN; exit').encode() + b'\n')
s.settimeout(int(os.environ.get('W', '3')))
buf = b''
try:
    while True:
        d = s.recv(65536)
        if not d: break
        buf += d
except Exception: pass
print(buf.decode(errors='replace'))
