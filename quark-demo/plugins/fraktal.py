# Fraktal-Plugin: rechnet die Mandelbrot-Menge und gibt ein PNG als Text aus (BEGIN-FILE/END-FILE).
import zlib, struct, base64, sys
W, H, N = 240, 160, 40
def farbe(i):
    if i >= N: return (10, 10, 30)
    t = i / N
    return (int(255 * min(1, t * 3)), int(255 * min(1, max(0, t * 3 - 1))), int(255 * min(1, max(0, t * 3 - 2))) if t > 0.66 else int(120 * t))
raw = bytearray()
for y in range(H):
    raw.append(0)
    ci = (y - H / 2) * 2.4 / H
    for x in range(W):
        cr = (x - W * 0.65) * 3.6 / W
        zr = zi = 0.0
        i = 0
        while i < N and zr * zr + zi * zi < 4:
            zr, zi = zr * zr - zi * zi + cr, 2 * zr * zi + ci
            i += 1
        raw += bytes(farbe(i))
def chunk(t, d):
    c = struct.pack(">I", len(d)) + t + d
    return c + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
print("BEGIN-FILE fraktal.png")
s = base64.b64encode(png).decode()
for k in range(0, len(s), 76):
    print(s[k:k + 76])
print("END-FILE")
sys.stdout.flush()
