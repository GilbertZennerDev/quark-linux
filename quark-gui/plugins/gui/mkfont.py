import gzip,sys,struct
d=gzip.open('/usr/share/consolefonts/Lat15-Terminus16.psf.gz').read()
if d[:2]==b'\x36\x04': n=512 if d[2]&1 else 256; cs=d[3]; g=d[4:]
else:
    hs,fl,n,cs,h,w=struct.unpack('<6I',d[8:32]); g=d[hs:]; assert (h,w)==(16,8),(h,w)
assert cs==16,cs
EX=[0xa7,0xb0,0xc4,0xd6,0xdc,0xdf,0xe4,0xf6,0xfc]  # Zeichen: Paragraph Grad Ae Oe Ue ss ae oe ue
ch=list(range(32,127))+EX
out=['/* Terminus 8x16: ASCII 32..126 + Zeichen aus FX (Latin-15), erzeugt von mkfont.py */',
'static const unsigned char FX[]={'+','.join(str(c) for c in EX)+'};',
'static const unsigned char FONT[%d][16]={'%len(ch)]
for c in ch:
    out.append('{'+','.join(str(b) for b in g[c*16:c*16+16])+'},')
out.append('};')
open('/x/out/gui/font.h','w').write(chr(10).join(out)+chr(10))
print(n,len(out))
