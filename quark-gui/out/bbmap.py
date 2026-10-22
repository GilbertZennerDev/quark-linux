import re,collections
t=open('bb.map',errors='replace').read()
i=t.index('Linker script and memory map')
lines=t[i:].split('\n')
tot=collections.Counter(); cur=None
pat=re.compile(r'^\s+(\S+)\s+0x[0-9a-f]+\s+(0x[0-9a-f]+)\s+(\S.*)$')
for j,l in enumerate(lines):
    m=re.match(r'^ (\.\S+)\s*$',l)
    if m: sec=m.group(1); continue
    m=re.match(r'^ (\.\S+)\s+0x[0-9a-f]+\s+(0x[0-9a-f]+)\s+(\S.*)$',l)
    if not m: 
        m2=re.match(r'^\s+0x[0-9a-f]+\s+(0x[0-9a-f]+)\s+(\S.*)$',l)
        if m2 and sec: 
            sz=int(m2.group(1),16); o=m2.group(2)
        else: continue
    else:
        sz=int(m.group(2),16); o=m.group(3)
    if sz==0: continue
    s=sec if 'sec' in dir() else ''
    if not(s.startswith('.text') or s.startswith('.rodata') or s.startswith('.data')): continue
    if 'libc.a' in o or 'crt1' in o or 'libgcc' in o:
        mm=re.search(r'\((.+?)\)',o); k='musl: '+(mm.group(1) if mm else o)
        tot['_libc']+=sz; tot[k]+=sz
    else:
        k=o.split('/')[-1] if '/' in o else o
        d='/'.join(o.split('/')[:-1])
        tot['_bb']+=sz; tot['bb:'+(o.split('/')[0] if '/' in o else o)+'/'+k]+=sz
print('musl gesamt',tot['_libc'],'busybox gesamt',tot['_bb'])
for k,v in tot.most_common(45):
    if not k.startswith('_'): print(v,k)
