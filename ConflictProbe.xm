#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <fcntl.h>
#import <unistd.h>
#import <stdarg.h>
#import <stdio.h>
#import <string.h>
#import <time.h>

static int gFD=-1;
static unsigned long long gSeq=0;
static const char *gPath=NULL;
static const char *paths[]={
  "/var/mobile/DuoDash-Airaw-Conflict.log",
  "/var/mobile/Library/Logs/DuoDash-Airaw-Conflict.log",
  "/var/tmp/DuoDash-Airaw-Conflict.log",
  "/tmp/DuoDash-Airaw-Conflict.log"
};

static void openLog(void){
  if(gFD>=0) return;
  for(unsigned i=0;i<sizeof(paths)/sizeof(paths[0]);i++){
    int fd=open(paths[i],O_WRONLY|O_CREAT|O_APPEND,0666);
    if(fd>=0){ gFD=fd; gPath=paths[i]; return; }
  }
}
static void logLine(const char *fmt,...){
  openLog(); if(gFD<0) return;
  char body[1800]; va_list ap; va_start(ap,fmt); vsnprintf(body,sizeof(body),fmt,ap); va_end(ap);
  time_t now=time(NULL); struct tm tmv; localtime_r(&now,&tmv);
  char line[2200];
  int n=snprintf(line,sizeof(line),"%04d-%02d-%02d %02d:%02d:%02d | seq=%llu pid=%d process=%s | %s\n",
    tmv.tm_year+1900,tmv.tm_mon+1,tmv.tm_mday,tmv.tm_hour,tmv.tm_min,tmv.tm_sec,
    ++gSeq,getpid(),getprogname(),body);
  if(n>0){ write(gFD,line,(size_t)n); fsync(gFD); }
}
static bool interesting(const char *p){
  if(!p) return false;
  return strstr(p,"DuoDash")||strstr(p,"Airaw")||strstr(p,"CarWebView")||
         strstr(p,"CarPlayApp")||strstr(p,"SpringBoard")||strstr(p,"CarPlay.framework");
}
static void imageAdded(const struct mach_header *mh, intptr_t slide){
  uint32_t n=_dyld_image_count();
  for(uint32_t i=0;i<n;i++){
    if(_dyld_get_image_header(i)==mh){
      const char *p=_dyld_get_image_name(i);
      if(interesting(p)) logLine("IMAGE_ADD slide=0x%llx path=%s",(unsigned long long)slide,p?p:"?");
      return;
    }
  }
}
__attribute__((constructor))
static void ConflictProbeInit(void){
  openLog();
  logLine("SESSION_START logger=%s",gPath?gPath:"unavailable");
  uint32_t n=_dyld_image_count();
  bool duo=false,full=false,air=false,web=false;
  for(uint32_t i=0;i<n;i++){
    const char *p=_dyld_get_image_name(i);
    if(!p) continue;
    if(strstr(p,"DuoDash.dylib")) duo=true;
    if(strstr(p,"DuoDashUnifiedFullscreen.dylib")) full=true;
    if(strstr(p,"Airaw.dylib")) air=true;
    if(strstr(p,"CarWebView.dylib")) web=true;
    if(interesting(p)) logLine("IMAGE_EXISTING index=%u path=%s",i,p);
  }
  logLine("LOAD_STATE DuoDash=%d DuoDashFullscreen=%d Airaw=%d CarWebView=%d imageCount=%u",duo,full,air,web,n);
  if(duo&&air) logLine("OVERLAP_ACTIVE DuoDash+Airaw loaded in same process; inspect UI/layout symptoms after this timestamp");
  _dyld_register_func_for_add_image(imageAdded);
}
