#include <fcntl.h>
#include <stdio.h>
#include <stdint.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>
struct fb_var_screeninfo{uint32_t xres,yres,xv,yv,xo,yo,bpp,gray,rest[32];};
struct fb_fix_screeninfo{char id[16];uint64_t smem_start;uint32_t smem_len,type,aux,visual;uint16_t xp,yp,yw,pad;uint32_t line_length;uint32_t pad2;uint64_t mmio;uint32_t mlen,accel;uint16_t cap,res[2];};
#define FBIOGET_VSCREENINFO 0x4600
#define FBIOGET_FSCREENINFO 0x4602
int main(void){
  int fd=open("/dev/fb0",O_RDWR);
  if(fd<0){puts("FB: open fehlt");return 1;}
  struct fb_var_screeninfo v; struct fb_fix_screeninfo f;
  if(ioctl(fd,FBIOGET_VSCREENINFO,&v)||ioctl(fd,FBIOGET_FSCREENINFO,&f)){puts("FB: ioctl fehlt");return 2;}
  printf("FB: %ux%u bpp=%u ll=%u len=%u\n",v.xres,v.yres,v.bpp,f.line_length,f.smem_len);
  uint32_t*p=mmap(0,f.smem_len,PROT_READ|PROT_WRITE,MAP_SHARED,fd,0);
  if(p==MAP_FAILED){puts("FB: mmap fehlt");return 3;}
  uint32_t col[4]={0xff0000,0x00ff00,0x0000ff,0xffff00};
  for(unsigned y=0;y<v.yres;y++)for(unsigned x=0;x<v.xres;x++)
    p[y*(f.line_length/4)+x]= (y<384)? col[x*4/v.xres] : (x<512?0xffffff:0x808080);
  puts("FB: gezeichnet");
  {char c;read(0,&c,1);}
  return 0;}
