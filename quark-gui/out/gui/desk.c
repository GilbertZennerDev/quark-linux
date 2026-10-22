/* Mini-Desktop fuer Quark-GUI: Hintergrund, Fenster, Taskleiste, Maus-Zeiger, Tastendruck-Anzeige */
#include <fcntl.h>
#include <stdio.h>
#include <stdint.h>
#include <time.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
struct fv{uint32_t xres,yres,xv,yv,xo,yo,bpp,gray,rest[32];};
struct ff{char id[16];uint64_t s;uint32_t len,type,aux,vis;uint16_t xp,yp,yw,pad;uint32_t ll;uint32_t pad2;uint64_t mm;uint32_t ml,acc;uint16_t cap,res[2];};
static uint32_t*fb,*scr;static uint32_t buf[1024*768];static int W,H,LL;
static void rect(int x,int y,int w,int h,uint32_t c){
  for(int j=y;j<y+h;j++){if(j<0||j>=H)continue;for(int i=x;i<x+w;i++)if(i>=0&&i<W)buf[j*1024+i]=c;}}
/* 5x7-Ziffern 0-9 und A-F */
static const uint8_t F[16][7]={{14,17,19,21,25,17,14},{4,12,4,4,4,4,14},{14,17,1,2,4,8,31},{30,1,1,14,1,1,30},{2,6,10,18,31,2,2},{31,16,30,1,1,17,14},{6,8,16,30,17,17,14},{31,1,2,4,8,8,8},{14,17,17,14,17,17,14},{14,17,17,15,1,2,12},{14,17,17,31,17,17,17},{30,17,17,30,17,17,30},{14,17,16,16,16,17,14},{30,17,17,17,17,17,30},{31,16,16,30,16,16,31},{31,16,16,30,16,16,16}};
static void hex(int x,int y,int v,int s,uint32_t c){
  for(int d=0;d<2;d++){int n=(v>>(4-4*d))&15;
    for(int r=0;r<7;r++)for(int b=0;b<5;b++)if(F[n][r]&(16>>b))rect(x+d*6*s+b*s,y+r*s,s,s,c);}}
static int mc=0;static int mx=512,my=384,old_mx=-1,old_my=-1;
static void cursor(void){
  for(int i=0;i<14;i++)rect(mx,my+i,i<9?1+i/2:1,1,0xffffff);
  rect(mx,my,2,14,0xffffff);rect(mx,my,10,2,0xffffff);}
int main(int argc,char**argv){
  if(argc>1&&fork()!=0){execl("/bin/sh","sh",(char*)0);return 1;} /* "desk sh": Desktop im Kind, Shell im Haupt-Prozess */
  int fd=open("/dev/fb0",O_RDWR),in=open("/dev/input",O_RDONLY);
  struct fv v;struct ff f;
  if(fd<0||in<0||ioctl(fd,0x4600,&v)||ioctl(fd,0x4602,&f)){puts("DESK: Geraet fehlt");return 1;}
  W=v.xres;H=v.yres;LL=f.ll/4;
  scr=mmap(0,f.len,PROT_READ|PROT_WRITE,MAP_SHARED,fd,0);
  fb=buf;if(scr==MAP_FAILED){puts("DESK: mmap fehlt");return 2;}
  puts("DESK: laeuft");
  int key=0,keys=0,btn=0,seq=0;uint8_t pk[3];
  for(;;){
    uint8_t b[64];int n=read(in,b,sizeof b);
    for(int i=0;i+1<n;i+=2){
      if(b[i]==0){if(!(b[i+1]&0x80)){key=b[i+1];keys++;}}
      else{if(seq==0&&!(b[i+1]&8))continue;mc++;pk[seq++]=b[i+1];if(seq==3){seq=0;        int dx=(int8_t)pk[1],dy=(int8_t)pk[2];if(pk[0]&0x10)dx=pk[1]-256;if(pk[0]&0x20)dy=pk[2]-256;
        mx+=dx;my-=dy;if(mx<0)mx=0;if(my<0)my=0;if(mx>W-1)mx=W-1;if(my>H-1)my=H-1;btn=pk[0]&7;}}}
    rect(0,0,W,H,0x2b5d8a);                       /* Hintergrund */
    rect(0,H-32,W,32,0x303030);rect(8,H-26,80,20,0x4caf50); /* Taskleiste + Start */
    rect(200,150,500,300,0xdddddd);rect(200,150,500,26,btn?0xd9534f:0x1f3f66); /* Fenster */
    rect(690,155,12,12,0xd9534f);
    hex(220,200,key,8,0x202020);                  /* letzter Tastencode */
    hex(220,300,keys&255,4,0x1f3f66);             /* Anzahl Tasten */
    cursor();
    for(int j=0;j<H;j++)for(int i=0;i<W;i++)scr[j*LL+i]=buf[j*1024+i];
    struct timespec ts={0,30000000};nanosleep(&ts,0);
  }
}
