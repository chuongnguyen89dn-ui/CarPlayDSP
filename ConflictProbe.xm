#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <fcntl.h>
#import <unistd.h>
#import <stdarg.h>
#import <stdio.h>
#import <string.h>
#import <time.h>
#import <signal.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>

static int gFD=-1;
static unsigned long long gSeq=0;
static volatile sig_atomic_t gTerminating=0;
static const char *gPath=NULL;
static const char *paths[]={
  "/var/mobile/Documents/DuoDash-Airaw-Logs/Conflict.log"
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
static bool shouldTraceView(UIView *v){
  if(!v) return false;
  NSString *cn=NSStringFromClass([v class]);
  NSString *desc=[v description];
  NSString *x=[NSString stringWithFormat:@"%@ %@",cn?:@"",desc?:@""];
  NSArray *keys=@[@"CarPlay",@"Dashboard",@"Dock",@"Sidebar",@"Status",@"Navigation",@"DuoDash",@"Airaw",@"Template",@"NowPlaying",@"Root"];
  for(NSString *k in keys) if([x rangeOfString:k options:NSCaseInsensitiveSearch].location!=NSNotFound) return true;
  UIWindow *w=v.window;
  if(w && (v==w || v.superview==w)) return true;
  return false;
}
static void callerInfo(char *out,size_t n){
  void *ra=__builtin_return_address(0); Dl_info di={0};
  if(dladdr(ra,&di) && di.dli_fname) snprintf(out,n,"%s:%s",di.dli_fname,di.dli_sname?di.dli_sname:"?");
  else snprintf(out,n,"?");
}
static void traceGeom(UIView *v,const char *event){
  if(!shouldTraceView(v)) return;
  char caller[512]; callerInfo(caller,sizeof(caller));
  CGRect f=v.frame,b=v.bounds; UIEdgeInsets e=UIEdgeInsetsZero;
  if(@available(iOS 11.0,*)) e=v.safeAreaInsets;
  logLine("UI_%s class=%s ptr=%p hidden=%d alpha=%.3f frame={%.1f,%.1f,%.1f,%.1f} bounds={%.1f,%.1f,%.1f,%.1f} safe={%.1f,%.1f,%.1f,%.1f} caller=%s",
    event,class_getName([v class]),v,v.hidden,v.alpha,f.origin.x,f.origin.y,f.size.width,f.size.height,
    b.origin.x,b.origin.y,b.size.width,b.size.height,e.top,e.left,e.bottom,e.right,caller);
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
static void terminationSignal(int sig){
  if(!gTerminating){ gTerminating=1; logLine("PROCESS_SIGNAL signal=%d",sig); }
  signal(sig,SIG_DFL); raise(sig);
}

__attribute__((destructor))
static void ConflictProbeFini(void){ logLine("PROCESS_UNLOAD normal=1"); if(gFD>=0) fsync(gFD); }

__attribute__((constructor))
static void ConflictProbeInit(void){
  openLog();
  signal(SIGTERM,terminationSignal);
  signal(SIGABRT,terminationSignal);
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

%hook UIView
- (void)setHidden:(BOOL)hidden {
  BOOL old=self.hidden;
  %orig;
  if(old!=hidden) traceGeom(self,hidden?"HIDDEN_YES":"HIDDEN_NO");
}
- (void)setAlpha:(CGFloat)alpha {
  CGFloat old=self.alpha;
  %orig;
  if(fabs(old-alpha)>0.001) traceGeom(self,"ALPHA");
}
- (void)setFrame:(CGRect)frame {
  CGRect old=self.frame;
  %orig;
  if(!CGRectEqualToRect(old,frame)) traceGeom(self,"FRAME");
}
- (void)setBounds:(CGRect)bounds {
  CGRect old=self.bounds;
  %orig;
  if(!CGRectEqualToRect(old,bounds)) traceGeom(self,"BOUNDS");
}
- (void)didMoveToWindow {
  %orig;
  traceGeom(self,"MOVE_WINDOW");
}
- (void)safeAreaInsetsDidChange {
  %orig;
  traceGeom(self,"SAFEAREA");
}
%end

%hook UIApplication
- (void)sendEvent:(UIEvent *)event {
  if(event.type==UIEventTypeTouches){
    NSSet *touches=[event allTouches];
    for(UITouch *t in touches){
      if(t.phase!=UITouchPhaseBegan && t.phase!=UITouchPhaseEnded) continue;
      UIWindow *w=t.window;
      CGPoint p=[t locationInView:w];
      UIView *hit=[w hitTest:p withEvent:event];
      CGRect hf=hit?hit.frame:CGRectZero;
      logLine("TOUCH phase=%s x=%.1f y=%.1f window=%s hitClass=%s hit=%p hidden=%d alpha=%.3f frame={%.1f,%.1f,%.1f,%.1f}",
        t.phase==UITouchPhaseBegan?"BEGAN":"ENDED",p.x,p.y,
        w?class_getName([w class]):"nil",hit?class_getName([hit class]):"nil",hit,
        hit?hit.hidden:0,hit?hit.alpha:0.0,hf.origin.x,hf.origin.y,hf.size.width,hf.size.height);
    }
  }
  %orig;
}
%end

%hook UIControl
- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event {
  logLine("ACTION controlClass=%s control=%p selector=%s targetClass=%s target=%p",
    class_getName([self class]),self,action?sel_getName(action):"?",
    target?class_getName([target class]):"nil",target);
  %orig;
}
%end
