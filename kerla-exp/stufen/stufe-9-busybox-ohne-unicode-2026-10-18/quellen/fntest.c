#include <fnmatch.h>
#include <stdio.h>
int main(void){
 struct{const char*p,*s;int r;}t[]={{"*.txt","a.txt",0},{"*.txt","a.tx",1},{"a?c","abc",0},{"[a-c]x","bx",0},{"[!a-c]x","bx",1},{"[[:digit:]]*","7up",0},{"*","",0},{"a*b*c","aXXbYYc",0},{"a*b*c","aXXbYY",1},{"\x5c*","*",0},{"[]]","]",0},{"x*","y",1},{"*.apk","foo-1.2.apk",0},{"a","a",0},{"a","ab",1}};
 int bad=0; for(unsigned i=0;i<sizeof t/sizeof*t;i++){int r=!!fnmatch(t[i].p,t[i].s,0); if(r!=t[i].r){bad++;printf("FALSCH %s %s\n",t[i].p,t[i].s);}}
 printf("fnmatch-Fehler: %d\n",bad); return bad;}
