#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <substrate.h>
#import <dlfcn.h>
#import <os/log.h>
#include "DSP/Biquad.hpp"

static CPBiquad leftFilter,rightFilter;
static bool enabled=true;
static os_log_t logHandle;
static NSString * const CPDomain=@"com.anhchuong.carplaydsp";

static void loadPrefs(){
    NSDictionary *p=[[NSUserDefaults standardUserDefaults] persistentDomainForName:CPDomain];
    enabled = p[@"enabled"] ? [p[@"enabled"] boolValue] : true;
}
static void prefsChanged(CFNotificationCenterRef c,void *o,CFStringRef n,const void *obj,CFDictionaryRef u){
    loadPrefs();
}

typedef OSStatus (*AudioUnitRenderFn)(AudioUnit,AudioUnitRenderActionFlags*,const AudioTimeStamp*,UInt32,UInt32,AudioBufferList*);
static AudioUnitRenderFn originalAudioUnitRender=nullptr;

static OSStatus hookedAudioUnitRender(AudioUnit unit,AudioUnitRenderActionFlags *flags,const AudioTimeStamp *ts,UInt32 bus,UInt32 frames,AudioBufferList *ioData){
    OSStatus status=originalAudioUnitRender(unit,flags,ts,bus,frames,ioData);
    if(status!=noErr || !enabled || !ioData) return status;
    for(UInt32 b=0;b<ioData->mNumberBuffers;b++){
        AudioBuffer &buf=ioData->mBuffers[b];
        if(!buf.mData || buf.mDataByteSize < frames*sizeof(float)) continue;
        float *samples=(float*)buf.mData;
        CPBiquad &filter=(b&1)?rightFilter:leftFilter;
        for(UInt32 i=0;i<frames;i++) samples[i]=filter.process(samples[i]);
    }
    return status;
}

__attribute__((constructor))
static void CarPlayDSPInit(){
    logHandle=os_log_create("com.anhchuong.carplaydsp","poc");
    loadPrefs();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),NULL,prefsChanged,CFSTR("com.anhchuong.carplaydsp/preferences.changed"),NULL,CFNotificationSuspensionBehaviorDeliverImmediately);
    leftFilter.setPeaking(48000.0,1000.0,1.0,-15.0);
    rightFilter.setPeaking(48000.0,1000.0,1.0,-15.0);
    void *symbol=dlsym(RTLD_DEFAULT,"AudioUnitRender");
    if(symbol){
        MSHookFunction(symbol,(void*)&hookedAudioUnitRender,(void**)&originalAudioUnitRender);
        os_log(logHandle,"CarPlayDSP loaded; enabled=%{public}d",enabled);
    } else os_log_error(logHandle,"CarPlayDSP: AudioUnitRender symbol unavailable");
}
