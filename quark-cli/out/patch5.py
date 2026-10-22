import re
p='src/kernel/syscalls/mod.rs'
s=open(p,encoding='utf-8',newline='').read().replace('\r\n','\n')
L=s.split('\n')
mods=['clock_gettime','fstat','rename','readlink']
consts=['SYS_GETGID','SYS_GETEGID','SYS_SIGALTSTACK','SYS_MPROTECT','SYS_ACCESS','SYS_FSTAT','SYS_RENAME','SYS_READLINK','SYS_CLOCK_GETTIME']
arms=['SYS_GETGID','SYS_GETEGID','SYS_SIGALTSTACK','SYS_MPROTECT','SYS_ACCESS','SYS_FSTAT','SYS_RENAME','SYS_READLINK','SYS_CLOCK_GETTIME']
targets=set()
for i,l in enumerate(L):
    t=l.strip()
    if t in [f'mod {m};' for m in mods]: targets.add(i)
    for c in consts:
        if t.startswith(f'const {c}:'): targets.add(i)
    for a in arms:
        if t.startswith(f'{a} =>'): targets.add(i)
n=0
for i in sorted(targets):
    j=i-1
    while j>=0 and L[j].strip().startswith('#[cfg('):
        if L[j].strip()=='#[cfg(feature = "rest")]':
            L[j]=L[j].replace('"rest"','"plug"'); n+=1
        j-=1
print(len(targets),'Ziele',n,'Gates')
open(p,'w',encoding='utf-8',newline='').write('\r\n'.join(L))
