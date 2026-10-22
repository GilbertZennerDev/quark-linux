import re,sys
d=open(sys.argv[1],'rb').read()
m=re.match(rb'P6\s+(\d+)\s+(\d+)\s+255\s',d);w,h=int(m[1]),int(m[2]);o=m.end()
px=lambda x,y:tuple(d[o+(y*w+x)*3:o+(y*w+x)*3+3])
print('bg',px(10,10),'fenster',px(300,300),'titel',px(300,160),'start',px(20,h-20))
ws=[(x,y) for y in range(0,h-40) for x in range(0,w) if px(x,y)==(255,255,255)]
print('zeiger-pixel',len(ws),ws[:1])
print('tasten-pixel',sum(1 for y in range(190,260) for x in range(220,300) if px(x,y)==(32,32,32)))
