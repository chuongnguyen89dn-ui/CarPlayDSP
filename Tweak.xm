#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <substrate.h>
#import <dlfcn.h>
#import <os/log.h>
#import <stdatomic.h>
#import <fcntl.h>
#import <unistd.h>
#import <sys/stat.h>
#import <stdarg.h>
#import <stdio.h>
#include "DSP/Biquad.hpp"

static CPBiquad leftFilter,rightFilter;
static bool enabled=true;
static os_log_t logHandle;
static NSString * const CPDomain=@"com.anhchuong.carplaydsp";
static atomic_ullong renderCalls=0, processedCalls=0, processedFrames=0, skippedDisabled=0, skippedNoData=0, renderErrors=0;
static atomic_ullong lastReportCall=0;
static const char *CPLogPath="/var/mobile/Documents/CarPlayDSP-Diagnostic.txt";

static void CPFileLog(const char *fmt,...){
    int fd=open(CPLogPath,O_WRONLY|O_CREAT|O_APPEND,0644);
    if(fd<0) return;
    char body[1024]; va_list ap; va_start(ap,fmt); vsnprintf(body,sizeof(body),fmt,ap); va_end(ap);
    char line[1280]; time_t now=time(NULL); struct tm tmv; localtime_r(&now,&tmv);
    int n=snprintf(line,sizeof(line),"%04d-%02d-%02d %02d:%02d:%02d | %s\n",tmv.tm_year+1900,tmv.tm_mon+1,tmv.tm_mday,tmv.tm_hour,tmv.tm_min,tmv.tm_sec,body);
    if(n>0) write(fd,line,(size_t)n); close(fd);
}


static void CPLogState(const char *reason){
    unsigned long long rc=atomic_load(&renderCalls),pc=atomic_load(&processedCalls),pf=atomic_load(&processedFrames),ds=atomic_load(&skippedDisabled),nd=atomic_load(&skippedNoData),er=atomic_load(&renderErrors);
    os_log(logHandle,"STATE %{public}s enabled=%{public}d renderCalls=%{public}llu processedCalls=%{public}llu processedFrames=%{public}llu disabledSkips=%{public}llu noDataSkips=%{public}llu errors=%{public}llu",reason,enabled,rc,pc,pf,ds,nd,er);
    CPFileLog("STATE %s enabled=%d renderCalls=%llu processedCalls=%llu processedFrames=%llu disabledSkips=%llu noDataSkips=%llu errors=%llu",reason,enabled,rc,pc,pf,ds,nd,er);
}

static void loadPrefs(){
    NSDictionary *p=[[NSUserDefaults standardUserDefaults] persistentDomainForName:CPDomain];
    bool old=enabled;
    enabled=p[@"enabled"] ? [p[@"enabled"] boolValue] : true;
    if(logHandle && old!=enabled) {
        os_log(logHandle,"TOGGLE -> %{public}s",enabled?"ON":"OFF");
        CPFileLog("TOGGLE -> %s",enabled?"ON":"OFF");
        CPLogState(enabled?"after-ON":"after-OFF");
    }
}
static void prefsChanged(CFNotificationCenterRef,void*,CFStringRef,const void*,CFDictionaryRef){ loadPrefs(); }

typedef OSStatus (*AudioUnitRenderFn)(AudioUnit,AudioUnitRenderActionFlags*,const AudioTimeStamp*,UInt32,UInt32,AudioBufferList*);
static AudioUnitRenderFn originalAudioUnitRender=nullptr;

static OSStatus hookedAudioUnitRender(AudioUnit unit,AudioUnitRenderActionFlags *flags,const AudioTimeStamp *ts,UInt32 bus,UInt32 frames,AudioBufferList *ioData){
    unsigned long long call=atomic_fetch_add(&renderCalls,1)+1;
    OSStatus status=originalAudioUnitRender(unit,flags,ts,bus,frames,ioData);
    if(status!=noErr){ atomic_fetch_add(&renderErrors,1); return status; }
    if(!enabled){ atomic_fetch_add(&skippedDisabled,1); return status; }
    if(!ioData){ atomic_fetch_add(&skippedNoData,1); return status; }

    UInt32 touched=0;
    for(UInt32 b=0;b<ioData->mNumberBuffers;b++){
        AudioBuffer &buf=ioData->mBuffers[b];
        if(!buf.mData || buf.mDataByteSize < frames*sizeof(float)) continue;
        float *samples=(float*)buf.mData;
        CPBiquad &filter=(b&1)?rightFilter:leftFilter;
        for(UInt32 i=0;i<frames;i++) samples[i]=filter.process(samples[i]);
        touched++;
    }
    if(touched){
        atomic_fetch_add(&processedCalls,1);
        atomic_fetch_add(&processedFrames,frames);
    } else atomic_fetch_add(&skippedNoData,1);

    unsigned long long last=atomic_load(&lastReportCall);
    if(call>=last+5000 && atomic_compare_exchange_strong(&lastReportCall,&last,call)){
        unsigned long long pc=atomic_load(&processedCalls);
        os_log(logHandle,"RENDER heartbeat enabled=ON call=%{public}llu frames=%{public}u buffers=%{public}u touched=%{public}u processedCalls=%{public}llu",call,(unsigned)frames,(unsigned)ioData->mNumberBuffers,(unsigned)touched,pc);
        CPFileLog("RENDER heartbeat enabled=ON call=%llu frames=%u buffers=%u touched=%u processedCalls=%llu",call,(unsigned)frames,(unsigned)ioData->mNumberBuffers,(unsigned)touched,pc);
    }
    return status;
}

__attribute__((constructor))
static void CarPlayDSPInit(){
    logHandle=os_log_create("com.anhchuong.carplaydsp","diagnostic");
    unlink(CPLogPath);
    CPFileLog("=== CarPlayDSP diagnostic session start ===");
    CPFileLog("INIT process=%s pid=%d",getprogname(),getpid());
    os_log(logHandle,"INIT process=%{public}s pid=%{public}d",getprogname(),getpid());
    loadPrefs();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),NULL,prefsChanged,CFSTR("com.anhchuong.carplaydsp/preferences.changed"),NULL,CFNotificationSuspensionBehaviorDeliverImmediately);
    leftFilter.setPeaking(48000.0,1000.0,1.0,-15.0);
    rightFilter.setPeaking(48000.0,1000.0,1.0,-15.0);
    void *symbol=dlsym(RTLD_DEFAULT,"AudioUnitRender");
    os_log(logHandle,"SYMBOL AudioUnitRender=%{public}p",symbol);
    CPFileLog("SYMBOL AudioUnitRender=%p",symbol);
    if(symbol){
        MSHookFunction(symbol,(void*)&hookedAudioUnitRender,(void**)&originalAudioUnitRender);
        os_log(logHandle,"HOOK installed original=%{public}p enabled=%{public}d",(void*)originalAudioUnitRender,enabled);
        CPFileLog("HOOK installed original=%p enabled=%d",(void*)originalAudioUnitRender,enabled);
        CPFileLog("LOG FILE: %s",CPLogPath);
    } else { os_log_error(logHandle,"HOOK FAILED: AudioUnitRender symbol unavailable"); CPFileLog("HOOK FAILED: AudioUnitRender symbol unavailable"); }
}
