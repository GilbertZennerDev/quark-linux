import re,sys
feat=set(['paket','socket','connect','bind_listen','signals','sessions','filesystem','process','system','plug'])
L=open('src/kernel/syscalls/mod.rs',encoding='utf-8').read().replace('\r\n','\n').split('\n')
num={}
for l in L:
    m=re.match(r'\s*const (SYS_\w+): usize = (\d+);',l)
    if m: num[m.group(1)]=int(m.group(2))
# nur do_dispatch ab "match n"
start=[i for i,l in enumerate(L) if 'match n {' in l][0]
cfg=[];en=[]
for l in L[start:]:
    t=l.strip()
    if t.startswith('#[cfg('):
        cfg.append(re.findall(r'feature = "(\w+)"',t)); continue
    m=re.match(r'((?:SYS_\w+)(?: \| SYS_\w+)*) =>',t)
    if m:
        ok=all(f in feat for c in cfg for f in c)
        if ok:
            for s in m.group(1).split(' | '): en.append((num[s],s))
        cfg=[]
    elif t and not t.startswith('//'):
        if '=>' in t: cfg=[]
used={}
for l in open('out/sys29.txt'):
    p=l.split(); used[int(p[0])]=(p[1],int(p[2]),int(p[3].split('=')[1]))
print('aktiv aber nie erfolgreich genutzt:')
for n,s in sorted(en):
    u=used.get(n)
    if not u or u[1]-u[2]<=0: print(' ',n,s,u)
print('aktive Arme:',len(en))
