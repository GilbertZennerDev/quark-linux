import socket, sys, time
name = sys.argv[1]
cmds = [c.strip() for c in (sys.argv[2] if len(sys.argv) > 2 else '').split(';') if c.strip()]
s = socket.create_connection(('127.0.0.1', 4455)); time.sleep(.5)
s.settimeout(.3)
def talk(c):
    if c.startswith('wait '):
        time.sleep(float(c.split()[1])); return
    s.send(c.encode() + b'\n'); time.sleep(.6)
    try: r = s.recv(65536).decode(errors='ignore')
    except Exception: r = ''
    print('MON>', c, '|', r.replace('\r', '').strip().splitlines()[-1:] )
for c in cmds: talk(c)
time.sleep(1.5)
talk('screendump ' + name + '.ppm'); time.sleep(1.5)
s.send(b'quit\n')
