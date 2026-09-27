#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <substrate.h>
#import <dlfcn.h>
#import <os/log.h>
#import <stdatomic.h>
#include "DSP/Biquad.hpp"

static CPBiquad leftFilter,rightFilter;
static bool enabled=true;
static os_log_t logHandle;
static NSString * const CPDomain=@"com.anhchuong.carplaydsp";
static atomic_ullong renderCalls=0, processedCalls=0, processedFrames=0, skippedDisabled=0, skippedNoData=0, renderErrors=0;
static atomic_ullong lastReportCall=0;

static void CPLogState(const char *reason){
    os_log(logHandle,"STATE %{public}s enabled=%{public}d renderCalls=%{public}llu processedCalls=%{public}llu processedFrames=%{public}llu disabledSkips=%{public}llu noDataSkips=%{public}llu errors=%{public}llu",
        reason,enabled,(unsigned long long)atomic_load(&renderCalls),(unsigned long long)atomic_load(&processedCalls),
        (unsigned long long)atomic_load(&processedFrames),(unsigned long long)atomic_load(&skippedDisabled),
        (unsigned long long)atomic_load(&skippedNoData),(unsigned long long)atomic_load(&renderErrors));
}

static void loadPrefs(){
    NSDictionary *p=[[NSUserDefaults standardUserDefaults] persistentDomainForName:CPDomain];
    bool old=enabled;
    enabled=p[@"enabled"] ? [p[@"enabled"] boolValue] : true;
    if(logHandle && old!=enabled) {
        os_log(logHandle,"TOGGLE -> %{public}s",enabled?"ON":"OFF");
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
        os_log(logHandle,"RENDER heartbeat enabled=ON call=%{public}llu frames=%{public}u buffers=%{public}u touched=%{public}u processedCalls=%{public}llu",
            call,(unsigned)frames,(unsigned)ioData->mNumberBuffers,(unsigned)touched,(unsigned long long)atomic_load(&processedCalls));
    }
    return status;
}

__attribute__((constructor))
static void CarPlayDSPInit(){
    logHandle=os_log_create("com.anhchuong.carplaydsp","diagnostic");
    os_log(logHandle,"INIT process=%{public}s pid=%{public}d",getprogname(),getpid());
    loadPrefs();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),NULL,prefsChanged,CFSTR("com.anhchuong.carplaydsp/preferences.changed"),NULL,CFNotificationSuspensionBehaviorDeliverImmediately);
    leftFilter.setPeaking(48000.0,1000.0,1.0,-15.0);
    rightFilter.setPeaking(48000.0,1000.0,1.0,-15.0);
    void *symbol=dlsym(RTLD_DEFAULT,"AudioUnitRender");
    os_log(logHandle,"SYMBOL AudioUnitRender=%{public}p",symbol);
    if(symbol){
        MSHookFunction(symbol,(void*)&hookedAudioUnitRender,(void**)&originalAudioUnitRender);
        os_log(logHandle,"HOOK installed original=%{public}p enabled=%{public}d",(void*)originalAudioUnitRender,enabled);
    } else os_log_error(logHandle,"HOOK FAILED: AudioUnitRender symbol unavailable");
}
