/* Quark-Desktop: winziger Desktop fuer /dev/fb0 + /dev/input (Bochs-VGA, PS/2).
   Fenster verschiebbar, Terminal, Editor, Dateien, Info, Startmenue, Taskleiste. Statisch mit musl bauen. */
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
#include <sys/syscall.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include "font.h"

struct fv{uint32_t xres,yres,xv,yv,xo,yo,bpp,gray,rest[32];};
struct ff{char id[16];uint64_t s;uint32_t len,type,aux,vis;uint16_t xp,yp,yw,pad;uint32_t ll;uint32_t pad2;uint64_t mm;uint32_t ml,acc;uint16_t cap,res[2];};

#define SW 1024
#define SH 768
#define TB 32            /* Taskleiste */
#define TITLE 22
#define MAXW 6
#define TL 160
#define TCM 100
#define EDMAX 8192
enum{T_TERM=1,T_EDIT,T_FILES,T_INFO};
enum{K_LEFT=0x101,K_RIGHT,K_UP,K_DOWN,K_HOME,K_END,K_DEL};
#define C_BG 0x2b5d8a
#define C_TA 0x1f3f66
#define C_TI 0x6c7a8c

typedef struct{
  int used,type,x,y,w,h; char title[48];
  char lines[TL][TCM+1]; int nl,tc,cl; char in[200]; int il; char cwd[160]; char hist[200];
  char tx[EDMAX]; int tl,cp; char path[160];
  char dir[160]; char names[80][64]; unsigned char isd[80]; int nn,sel,top;
} Win;

static uint32_t *scr,buf[SW*SH];
static int LL=SW,mx=512,my=384,btn=0,dirty=1;
static Win ws[MAXW]; static int z[MAXW],nz;
static int drag=-1,dx0,dy0,menu=0,de=1,shift,ctrl,altgr,caps,e0;
static unsigned char t0[128],t1[128];

/* kleine Ersatzfunktionen statt printf/stdio (spart ca. 10 KB) */
static void sc(char*d,int n,const char*a,const char*b,const char*c){
  int i=0;const char*p[3]={a,b,c};
  for(int k=0;k<3;k++)for(const char*q=p[k];*q&&i<n-1;q++)d[i++]=*q;
  d[i]=0;}
static void msg(const char*s){write(1,s,strlen(s));}
/* Intern Latin-1 (1 Byte je Umlaut, passt zur Schrift); der Kernel will UTF-8 in Pfaden/Argumenten */
static int l2u(char*d,const char*s,int n){int o=0;
  for(int i=0;i<n;i++){unsigned char c=s[i];
    if(c<0x80)d[o++]=c;else{d[o++]=0xc0|(c>>6);d[o++]=0x80|(c&0x3f);}}
  d[o]=0;return o;}
static int u2l(char*d,const char*s,int n){int o=0;
  for(int i=0;i<n;i++){unsigned char c=s[i];
    if((c==0xc3||c==0xc2)&&i+1<n&&(s[i+1]&0xc0)==0x80){d[o++]=c==0xc3?(s[i+1]|0x40):s[i+1];i++;}
    else d[o++]=c;}
  d[o]=0;return o;}

/* ---------- Zeichnen ---------- */
static void rect(int x,int y,int w,int h,uint32_t c){
  if(x<0){w+=x;x=0;} if(y<0){h+=y;y=0;} if(x+w>SW)w=SW-x; if(y+h>SH)h=SH-y;
  for(int j=0;j<h;j++){uint32_t*p=buf+(y+j)*SW+x;for(int i=0;i<w;i++)p[i]=c;}}
static void chr(int x,int y,int c,uint32_t fg,int bg){
  int k=0; if(c>32&&c<127)k=c-32; else for(int i=0;i<(int)sizeof FX;i++)if(FX[i]==c)k=95+i;
  const unsigned char*g=FONT[k];
  if(bg>=0)rect(x,y,8,16,bg);
  for(int r=0;r<16;r++)for(int b=0;b<8;b++)if(g[r]&(128>>b)){int px=x+b,py=y+r;if(px>=0&&px<SW&&py>=0&&py<SH)buf[py*SW+px]=fg;}}
static void str(int x,int y,const char*s,uint32_t fg,int bg){for(;*s;s++,x+=8)chr(x,y,(unsigned char)*s,fg,bg);}
static int inb(int px,int py,int x,int y,int w,int h){return px>=x&&px<x+w&&py>=y&&py<y+h;}

/* ---------- Fenster ---------- */
static void raise_(int i){int k;for(k=0;k<nz&&z[k]!=i;k++);if(k==nz)return;for(;k<nz-1;k++)z[k]=z[k+1];z[nz-1]=i;}
static void newline(Win*w){
  if(w->nl>=TL){memmove(w->lines[0],w->lines[1],(TL-1)*(TCM+1));w->nl=TL-1;}
  w->lines[w->nl][0]=0;w->nl++;w->cl=0;}
static void tput(Win*w,int c){
  if(c=='\r')return; if(c=='\n'){newline(w);return;}
  if(c=='\t'){do tput(w,' ');while(w->cl%8);return;}
  if(c<32)return;
  if(w->cl>=w->tc)newline(w);
  char*l=w->lines[w->nl-1];l[w->cl++]=c;l[w->cl]=0;}
static void tprint(Win*w,const char*s){for(;*s;s++)tput(w,(unsigned char)*s);}
static int pend;                      /* halbes UTF-8-Zeichen zwischen zwei read()-Blöcken */
static void tputu(Win*w,int c){
  if(pend){int p=pend;pend=0;
    if((c&0xc0)==0x80){tput(w,p==0xc3?(c|0x40):c);return;}
    tput(w,p);}
  if(c==0xc3||c==0xc2){pend=c;return;}
  tput(w,c);}

static void loaddir(Win*w){
  w->nn=0;w->sel=0;w->top=0;
  if(strcmp(w->dir,"/")){strcpy(w->names[0],"..");w->isd[0]=1;w->nn=1;}
  int d=open(w->dir,O_RDONLY|O_DIRECTORY);if(d<0)return;
  static char db[2048];int n;
  while(w->nn<80&&(n=syscall(SYS_getdents64,d,db,sizeof db))>0){
    for(int o=0;o<n&&w->nn<80;){
      char*e=db+o;int rl=*(uint16_t*)(e+16);const char*nm=e+19;o+=rl;
      if(!strcmp(nm,".")||!strcmp(nm,".."))continue;
      char p[300];sc(p,300,w->dir,strcmp(w->dir,"/")?"/":"",nm);
      struct stat st;int isd=(stat(p,&st)==0&&S_ISDIR(st.st_mode));
      strncpy(w->names[w->nn],nm,63);w->names[w->nn][63]=0;w->isd[w->nn]=isd;w->nn++;}}
  close(d);
  int s0=strcmp(w->dir,"/")?1:0;           /* ".." bleibt oben */
  for(int i=s0;i<w->nn;i++){ /* Einfuegesortierung: Ordner zuerst */
    char t[64];unsigned char td;int j=i;
    while(j>s0){
      int a=w->isd[j-1],b=w->isd[j];
      if(a>b||(a==b&&strcmp(w->names[j-1],w->names[j])<=0))break;
      memcpy(t,w->names[j-1],64);td=w->isd[j-1];
      memcpy(w->names[j-1],w->names[j],64);w->isd[j-1]=w->isd[j];
      memcpy(w->names[j],t,64);w->isd[j]=td;j--;}}
}
static Win*openwin(int type){
  int i;for(i=0;i<MAXW&&ws[i].used;i++);
  if(i==MAXW)return 0;
  Win*w=&ws[i];memset(w,0,sizeof *w);w->used=1;w->type=type;
  int off=(nz%5)*28;
  w->x=170+off;w->y=60+off;
  if(type==T_TERM){w->w=660;w->h=420;strcpy(w->title,"Terminal");w->tc=(w->w-12)/8;if(w->tc>TCM)w->tc=TCM;
    w->nl=1;if(!getcwd(w->cwd,sizeof w->cwd))strcpy(w->cwd,"/");
    tprint(w,"Quark-Terminal. Beispiele: ls, q ls, q add nano, cat /etc/passwd\n");}
  else if(type==T_EDIT){w->w=560;w->h=380;strcpy(w->path,"/tmp/notiz.txt");sc(w->title,48,"Editor - ",w->path,"");
    int f=open(w->path,O_RDONLY);if(f>=0){int n=read(f,w->tx,EDMAX-1);if(n>0)w->tl=u2l(w->tx,w->tx,n);close(f);}}
  else if(type==T_FILES){w->w=420;w->h=400;strcpy(w->dir,"/");strcpy(w->title,"Dateien");loaddir(w);}
  else{w->w=420;w->h=250;strcpy(w->title,"Info");}
  z[nz++]=i;dirty=1;return w;}
static void closewin(int i){
  ws[i].used=0;int k;for(k=0;k<nz&&z[k]!=i;k++);for(;k<nz-1;k++)z[k]=z[k+1];nz--;dirty=1;}

static void redraw(void);
static void flip(void){for(int j=0;j<SH;j++)memcpy(scr+j*LL,buf+j*SW,SW*4);}

static int busy,in;static void pump(void);
static void runcmd(Win*w,const char*cmd){
  char uc[2*200+1];pend=0;
  tprint(w,w->cwd);tprint(w,"$ ");tprint(w,cmd);tput(w,10);
  if(!*cmd)return;
  if(!strcmp(cmd,"clear")){w->nl=1;w->lines[0][0]=0;w->cl=0;return;}
  if(!strncmp(cmd,"cd",2)&&(!cmd[2]||cmd[2]==' ')){
    const char*p=cmd[2]?cmd+3:"/";while(*p==' ')p++;if(!*p)p="/";
    if(chdir(p)==0){if(!getcwd(w->cwd,sizeof w->cwd))strcpy(w->cwd,"/");}else tprint(w,"cd: geht nicht\n");return;}
  if(!strcmp(cmd,"exit")){closewin((int)(w-ws));return;}
  int o=open("/tmp/.out",O_RDWR|O_CREAT|O_TRUNC,0600),z0=open("/dev/null",O_RDONLY),rd=open("/tmp/.out",O_RDONLY);
  if(o<0||z0<0||rd<0){tprint(w,"tmp fehlt\n");return;}
  strcpy(w->title,"Terminal - laeuft ...");redraw();flip();
  pid_t pid=fork();
  if(pid==0){dup2(z0,0);dup2(o,1);dup2(o,2);close(o);close(z0);
    l2u(uc,cmd,strlen(cmd));execl("/bin/sh","sh","-c",uc,(char*)0);_exit(127);}
  close(z0);
  if(pid>0){char b[512];int n,tot=0,st,fin=0;busy=1;
    for(;;){
      while((n=read(rd,b,sizeof b))>0){for(int i=0;i<n&&tot<60000;i++)tputu(w,(unsigned char)b[i]);tot+=n;dirty=1;}
      if(fin)break;
      if(waitpid(pid,&st,WNOHANG)==pid)fin=1;
      else{pump();if(dirty){redraw();flip();dirty=0;}struct timespec t={0,30000000};nanosleep(&t,0);}}
    busy=0;}
  else tprint(w,"fork fehlt\n");
  close(o);close(rd);strcpy(w->title,"Terminal");dirty=1;}

/* ---------- Editor ---------- */
static void edlay(Win*w,int cols,int upto,int*r,int*c){
  int rr=0,cc=0;
  for(int i=0;i<upto;i++){if(w->tx[i]=='\n'){rr++;cc=0;}else{if(cc>=cols){rr++;cc=0;}cc++;}}
  if(cc>=cols){rr++;cc=0;}*r=rr;*c=cc;}
static void edmove(Win*w,int cols,int dir){
  int cr,cc;edlay(w,cols,w->cp,&cr,&cc);int tr=cr+dir;if(tr<0)return;
  int best=-1,rr=0,c2=0;
  for(int i=0;i<=w->tl;i++){
    int r=rr,c=c2;if(c>=cols){r++;c=0;}
    if(r==tr&&c<=cc)best=i; if(r>tr)break;
    if(i<w->tl){if(w->tx[i]=='\n'){rr++;c2=0;}else{if(c2>=cols){rr++;c2=0;}c2++;}}}
  if(best>=0)w->cp=best;}
static void edsave(Win*w){
  int f=open(w->path,O_WRONLY|O_CREAT|O_TRUNC,0644);
  if(f>=0){static char ub[2*EDMAX+1];write(f,ub,l2u(ub,w->tx,w->tl));close(f);sc(w->title,48,"Editor - ",w->path," (gespeichert)");}
  else sc(w->title,48,"Editor - Speichern fehlgeschlagen","","");}
static void edopen(const char*path){
  Win*w=0;for(int i=0;i<MAXW;i++)if(ws[i].used&&ws[i].type==T_EDIT){w=&ws[i];break;}
  if(!w)w=openwin(T_EDIT);if(!w)return;
  strncpy(w->path,path,159);w->path[159]=0;w->tl=0;w->cp=0;
  int f=open(path,O_RDONLY);if(f>=0){int n=read(f,w->tx,EDMAX-1);if(n>0)w->tl=u2l(w->tx,w->tx,n);close(f);}
  sc(w->title,48,"Editor - ",w->path,"");raise_((int)(w-ws));dirty=1;}

/* ---------- Tastatur ---------- */
static void onkey(int ch){
  if(!nz)return;Win*w=&ws[z[nz-1]];dirty=1;
  if(w->type==T_TERM){
    if(ch=='\n'){w->in[w->il]=0;strcpy(w->hist,w->in);char c[200];strcpy(c,w->in);w->il=0;w->in[0]=0;runcmd(w,c);}
    else if(ch==8){if(w->il)w->il--;}
    else if(ch==K_UP){strcpy(w->in,w->hist);w->il=strlen(w->in);}
    else if(ch>=32&&ch<256&&ch!=127&&w->il<198){w->in[w->il++]=ch;}
  }else if(w->type==T_EDIT){
    int cols=(w->w-16)/8;
    if(ch==19)edsave(w);
    else if(ch==K_LEFT){if(w->cp)w->cp--;}
    else if(ch==K_RIGHT){if(w->cp<w->tl)w->cp++;}
    else if(ch==K_HOME){while(w->cp&&w->tx[w->cp-1]!='\n')w->cp--;}
    else if(ch==K_END){while(w->cp<w->tl&&w->tx[w->cp]!='\n')w->cp++;}
    else if(ch==K_UP)edmove(w,cols,-1);
    else if(ch==K_DOWN)edmove(w,cols,1);
    else if(ch==K_DEL){if(w->cp<w->tl){memmove(w->tx+w->cp,w->tx+w->cp+1,w->tl-w->cp-1);w->tl--;}}
    else if(ch==8){if(w->cp){memmove(w->tx+w->cp-1,w->tx+w->cp,w->tl-w->cp);w->cp--;w->tl--;}}
    else if((ch>=32&&ch<256&&ch!=127)||ch=='\n'){
      if(w->tl<EDMAX-1){memmove(w->tx+w->cp+1,w->tx+w->cp,w->tl-w->cp);w->tx[w->cp++]=ch;w->tl++;}}
  }else if(w->type==T_FILES){
    int rows=(w->h-TITLE-8)/16;
    if(ch==K_UP&&w->sel>0)w->sel--;
    else if(ch==K_DOWN&&w->sel<w->nn-1)w->sel++;
    else if(ch=='\n'&&w->nn){
      char p[300];const char*n=w->names[w->sel];
      if(!strcmp(n,"..")){char*s=strrchr(w->dir,'/');if(s==w->dir)w->dir[1]=0;else *s=0;loaddir(w);}
      else{sc(p,sizeof p,w->dir,strcmp(w->dir,"/")?"/":"",n);
        if(w->isd[w->sel]){strncpy(w->dir,p,159);loaddir(w);}else edopen(p);}}
    if(w->sel<w->top)w->top=w->sel; if(w->sel>=w->top+rows)w->top=w->sel-rows+1;
  }
}
static void mk(int s,const char*a,const char*b){for(;*a;a++,b++,s++){t0[s]=*a;t1[s]=*b;}}
static void keyinit(void){
  mk(0x02,"1234567890-=","!@#$%^&*()_+");mk(0x10,"qwertyuiop[]","QWERTYUIOP{}");
  mk(0x1e,"asdfghjkl;'`","ASDFGHJKL:\"~");mk(0x2b,"\\zxcvbnm,./","|ZXCVBNM<>?");
  t0[0x1c]=t1[0x1c]='\n';t0[0x0e]=t1[0x0e]=8;t0[0x0f]=t1[0x0f]=' ';t0[0x39]=t1[0x39]=' ';}
static int lookup(int s){
  int ch=(shift?t1:t0)[s];
  if(de){
    if(altgr){switch(s){case 0x10:return '@';case 0x08:return '{';case 0x09:return '[';case 0x0a:return ']';
      case 0x0b:return '}';case 0x0c:return '\\';case 0x56:return '|';case 0x1b:return '~';}}
    switch(s){
      case 0x15:ch=shift?'Z':'z';break; case 0x2c:ch=shift?'Y':'y';break;
      case 0x03:if(shift)ch='"';break; case 0x04:if(shift)ch=0xa7;break; case 0x07:if(shift)ch='&';break;
      case 0x08:if(shift)ch='/';break; case 0x09:if(shift)ch='(';break; case 0x0a:if(shift)ch=')';break;
      case 0x0b:if(shift)ch='=';break; case 0x0c:ch=shift?'?':0xdf;break; case 0x0d:ch=shift?'`':'\'';break;
      case 0x1a:ch=shift?0xdc:0xfc;break; case 0x1b:ch=shift?'*':'+';break;
      case 0x27:ch=shift?0xd6:0xf6;break; case 0x28:ch=shift?0xc4:0xe4;break;
      case 0x29:ch=shift?0xb0:'^';break; case 0x2b:ch=shift?'\'':'#';break;
      case 0x33:ch=shift?';':',';break; case 0x34:ch=shift?':':'.';break; case 0x35:ch=shift?'_':'-';break;
      case 0x56:ch=shift?'>':'<';break;}}
  else if(s==0x56)ch=shift?'>':'<';
  if(caps&&ch>='a'&&ch<='z'&&!shift)ch-=32; else if(caps&&ch>='A'&&ch<='Z'&&shift)ch+=32;
  return ch;}
static void scan(int b){
  if(b==0xe0){e0=1;return;}
  int rel=b&0x80,s=b&0x7f,x=e0;e0=0;
  if(s==0x2a||s==0x36){if(!x)shift=!rel;return;}
  if(s==0x1d){ctrl=!rel;return;}
  if(s==0x38){if(x)altgr=!rel;return;}
  if(rel)return;
  if(s==0x3a){caps^=1;return;}
  int ch=0;
  if(x){switch(s){case 0x4b:ch=K_LEFT;break;case 0x4d:ch=K_RIGHT;break;case 0x48:ch=K_UP;break;case 0x50:ch=K_DOWN;break;
    case 0x47:ch=K_HOME;break;case 0x4f:ch=K_END;break;case 0x53:ch=K_DEL;break;case 0x1c:ch='\n';break;}}
  else if(s<0x58)ch=lookup(s);
  if(ctrl&&ch>='a'&&ch<='z')ch&=31; else if(ctrl&&ch>='A'&&ch<='Z')ch&=31;
  if(ch)onkey(ch);}

/* ---------- Anzeige ---------- */
static const char*MENU[4]={"Terminal","Editor","Dateien","Info"};
static void drawwin(int i){
  Win*w=&ws[i];int act=(nz&&z[nz-1]==i);
  rect(w->x-1,w->y-1,w->w+2,w->h+2,0x101010);
  rect(w->x,w->y,w->w,TITLE,act?C_TA:C_TI);
  str(w->x+8,w->y+3,w->title,0xffffff,-1);
  rect(w->x+w->w-20,w->y+3,16,16,0xd9534f);str(w->x+w->w-20,w->y+3,"x",0xffffff,-1);
  int bx=w->x,by=w->y+TITLE,bw=w->w,bh=w->h-TITLE;
  if(w->type==T_TERM){
    rect(bx,by,bw,bh,0x141414);int rows=(bh-8)/16;
    int n=w->nl-(w->cl==0?1:0);int sh=n<rows-1?n:rows-1,first=n-sh;
    for(int r=0;r<sh;r++)str(bx+6,by+4+r*16,w->lines[first+r],0xdcdcdc,-1);
    char pr[400];w->in[w->il]=0;sc(pr,sizeof pr,w->cwd,"$ ",w->in);
    int len=strlen(pr),mxc=w->tc-1;const char*s=len>mxc?pr+len-mxc:pr;
    str(bx+6,by+4+sh*16,s,0x7CFC7C,-1);rect(bx+6+strlen(s)*8,by+4+sh*16,8,16,0x7CFC7C);
  }else if(w->type==T_EDIT){
    rect(bx,by,bw,bh,0xffffff);int cols=(bw-16)/8,rows=(bh-8)/16;
    int cr,cc;edlay(w,cols,w->cp,&cr,&cc);int top=cr>=rows?cr-rows+1:0;
    int rr=0,c2=0;
    for(int k=0;k<w->tl;k++){unsigned char ch=w->tx[k];
      if(ch=='\n'){rr++;c2=0;continue;}
      if(c2>=cols){rr++;c2=0;}
      if(rr>=top&&rr<top+rows)chr(bx+8+c2*8,by+4+(rr-top)*16,ch,0x101010,-1);
      c2++;}
    rect(bx+8+cc*8,by+4+(cr-top)*16,2,16,0xd9534f);
    str(bx+8,by+bh-18,"Strg+S speichert",0x808080,-1);
  }else if(w->type==T_FILES){
    rect(bx,by,bw,bh,0xf4f4f4);str(bx+8,by+4,w->dir,0x202060,-1);
    int rows=(bh-8)/16-1;
    for(int r=0;r<rows&&w->top+r<w->nn;r++){int k=w->top+r;
      if(k==w->sel)rect(bx+2,by+22+r*16,bw-4,16,0xb8d0f0);
      char l[80],nm[64];u2l(nm,w->names[k],strlen(w->names[k]));sc(l,sizeof l,nm,w->isd[k]?"/":"","");
      str(bx+8,by+22+r*16,l,w->isd[k]?0x1f3f9f:0x202020,-1);}
  }else{
    rect(bx,by,bw,bh,0xeeeeee);
    str(bx+12,by+12,"Quark GUI",0x1f3f66,-1);
    str(bx+12,by+40,"Kernel: Kerla (Rust) mit Linux-ABI",0x202020,-1);
    str(bx+12,by+60,"Bildschirm: Bochs-VGA /dev/fb0",0x202020,-1);
    str(bx+12,by+80,"Eingabe: PS/2 Tastatur und Maus",0x202020,-1);
    str(bx+12,by+112,"Tastatur umschalten: DE/US unten rechts",0x202020,-1);
    str(bx+12,by+144,"Editor: Strg+S speichert",0x202020,-1);
    str(bx+12,by+164,"Terminal: Befehl + Enter, Pfeil hoch",0x202020,-1);
  }
}
static void icon(int i,uint32_t c,const char*n){
  int x=24,y=24+i*84;rect(x,y,48,48,c);rect(x+3,y+3,42,42,c+0x202020);str(x+24-strlen(n)*4,y+54,n,0xffffff,-1);}
static void redraw(void){
  rect(0,0,SW,SH,C_BG);
  icon(0,0x303030,"Terminal");icon(1,0xc08030,"Editor");icon(2,0x409050,"Dateien");icon(3,0x5060c0,"Info");
  for(int k=0;k<nz;k++)drawwin(z[k]);
  rect(0,SH-TB,SW,TB,0x303030);rect(8,SH-TB+5,80,22,0x4caf50);str(24,SH-TB+8,"Start",0xffffff,-1);
  int bx=100;
  for(int i=0;i<MAXW;i++)if(ws[i].used){char t[13];sc(t,13,ws[i].title,"","");
    rect(bx,SH-TB+5,116,22,(nz&&z[nz-1]==i)?0x5a7aa0:0x474747);str(bx+6,SH-TB+8,t,0xffffff,-1);bx+=120;}
  rect(SW-50,SH-TB+5,42,22,0x474747);str(SW-42,SH-TB+8,de?"DE":"US",0xffffff,-1);
  if(menu){rect(8,SH-TB-4*26-6,150,4*26+6,0x202020);
    for(int i=0;i<4;i++)str(20,SH-TB-4*26+i*26+3,MENU[i],0xffffff,-1);}
  for(int i=0;i<14;i++)rect(mx,my+i,i<9?1+i/2:1,1,0xffffff);
  rect(mx,my,2,14,0xffffff);rect(mx,my,10,2,0xffffff);
}

/* ---------- Maus ---------- */
static void spawn(int t){Win*w=openwin(t);if(w)raise_((int)(w-ws));}
static void press(void){
  dirty=1;
  if(menu){menu=0;if(inb(mx,my,8,SH-TB-4*26-6,150,4*26+6)){int i=(my-(SH-TB-4*26-6))/26;if(i>=0&&i<4)spawn(i+1);}return;}
  if(my>=SH-TB){
    if(inb(mx,my,8,SH-TB+5,80,22)){menu=1;return;}
    if(inb(mx,my,SW-50,SH-TB+5,42,22)){de=!de;return;}
    int bx=100;for(int i=0;i<MAXW;i++)if(ws[i].used){if(inb(mx,my,bx,SH-TB+5,116,22)){raise_(i);return;}bx+=120;}
    return;}
  for(int k=nz-1;k>=0;k--){Win*w=&ws[z[k]];
    if(inb(mx,my,w->x,w->y,w->w,w->h)){int i=z[k];raise_(i);
      if(my<w->y+TITLE){if(mx>=w->x+w->w-20){closewin(i);return;}drag=i;dx0=mx-w->x;dy0=my-w->y;}
      else if(w->type==T_FILES){int rows=(w->h-TITLE-8)/16-1,r=(my-(w->y+TITLE+22))/16;
        if(my>=w->y+TITLE+22&&r<rows&&w->top+r<w->nn){if(w->sel==w->top+r)onkey('\n');else w->sel=w->top+r;}}
      return;}}
  for(int i=0;i<4;i++)if(inb(mx,my,24,24+i*84,60,70)){spawn(i+1);return;}
}

static void pump(void){
  static int seq;static uint8_t pk[3];
  {
    uint8_t b[64];int n=read(in,b,sizeof b);
    for(int i=0;i+1<n;i+=2){
      if(b[i]==0){if(!busy)scan(b[i+1]);continue;}
      if(seq==0&&!(b[i+1]&8))continue;
      pk[seq++]=b[i+1];
      if(seq==3){seq=0;
        int ddx=(int8_t)pk[1],ddy=(int8_t)pk[2];if(pk[0]&0x10)ddx=pk[1]-256;if(pk[0]&0x20)ddy=pk[2]-256;
        mx+=ddx;my-=ddy;if(mx<0)mx=0;if(my<0)my=0;if(mx>SW-1)mx=SW-1;if(my>SH-1)my=SH-1;
        int nb=pk[0]&1;
        if(drag>=0){if(nb){Win*w=&ws[drag];w->x=mx-dx0;w->y=my-dy0;if(w->y<0)w->y=0;if(w->y>SH-TB-TITLE)w->y=SH-TB-TITLE;}else drag=-1;}
        if(nb&&!(btn&1)&&!busy)press();
        btn=pk[0]&7;dirty=1;}}
  }
}

int main(int argc,char**argv){
  if(argc>1&&fork()!=0){execl("/bin/sh","sh",(char*)0);return 1;} /* "desk sh": Desktop im Kind, Shell im Haupt-Prozess */
  int fd=open("/dev/fb0",O_RDWR);in=open("/dev/input",O_RDONLY);
  struct fv v;struct ff f;
  if(fd<0||in<0||ioctl(fd,0x4600,&v)||ioctl(fd,0x4602,&f)){msg("DESK: Geraet fehlt");return 1;}
  if(v.xres!=SW||v.yres!=SH){msg("DESK: Aufloesung nicht 1024x768");return 3;}
  LL=f.ll/4;
  scr=mmap(0,f.len,PROT_READ|PROT_WRITE,MAP_SHARED,fd,0);
  if(scr==MAP_FAILED){msg("DESK: mmap fehlt");return 2;}
  fcntl(fd,F_SETFD,FD_CLOEXEC);fcntl(in,F_SETFD,FD_CLOEXEC);
  keyinit();spawn(T_TERM);
  for(;;){
    pump();
    if(dirty){redraw();flip();dirty=0;}
    struct timespec ts={0,20000000};nanosleep(&ts,0);
  }
}
