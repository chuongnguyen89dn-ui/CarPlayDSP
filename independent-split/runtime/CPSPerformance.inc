// Opt-in baseline recorder. CPU/memory are SpringBoard process-wide, not Split-only.
static dispatch_queue_t CPSPerfQueue;
static NSTimer *CPSPerfTimer;
static NSMutableDictionary<NSString *,NSNumber *> *CPSPerfCounters;
static task_thread_times_info_data_t CPSPerfLastCPU;
static CFTimeInterval CPSPerfLastWall;
static NSString *const CPSPerfPath=@"/var/mobile/Library/Logs/CarPlaySplit-performance.jsonl";
static void CPSPerfWrite(NSDictionary *row) {
    if(!CPSPerfQueue)return;
    NSMutableDictionary *record=[row mutableCopy];
    record[@"timestamp"]=[NSDate date].description;
    record[@"schema"]=@1;
    dispatch_async(CPSPerfQueue,^{
        @autoreleasepool {
            NSError *error=nil;
            NSData *data=[NSJSONSerialization dataWithJSONObject:record options:0 error:&error];
            if(!data)return;
            NSMutableData *line=[data mutableCopy];[line appendBytes:"\n" length:1];
            NSFileManager *fm=NSFileManager.defaultManager;
            NSString *dir=[CPSPerfPath stringByDeletingLastPathComponent];
            [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
            if([[fm attributesOfItemAtPath:CPSPerfPath error:nil] fileSize] > 4*1024*1024) {
                NSString *previous=[CPSPerfPath stringByAppendingString:@".previous"];
                [fm removeItemAtPath:previous error:nil];
                [fm moveItemAtPath:CPSPerfPath toPath:previous error:nil];
            }
            if(![fm fileExistsAtPath:CPSPerfPath])[fm createFileAtPath:CPSPerfPath contents:nil attributes:@{NSFilePosixPermissions:@0644}];
            NSFileHandle *file=[NSFileHandle fileHandleForWritingAtPath:CPSPerfPath];
            [file seekToEndOfFile];[file writeData:line];[file closeFile];
        }
    });
}
static void CPSPerfCount(NSString *key) {
    if(!CPSPerfTimer)return;
    CPSPerfCounters[key]=@([CPSPerfCounters[key] unsignedLongLongValue]+1);
}
static void CPSPerfMark(NSString *event,NSDictionary *extra) {
    if(!CPSPerfTimer)return;
    NSMutableDictionary *row=[@{@"type":@"event",@"name":event} mutableCopy];
    if(extra)[row addEntriesFromDictionary:extra];
    CPSPerfWrite(row);
}
static void CPSPerfSample(void) {
    if(!CPSPerfTimer)return;
    task_thread_times_info_data_t cpu={0};
    mach_msg_type_number_t count=TASK_THREAD_TIMES_INFO_COUNT;
    kern_return_t status=task_info(mach_task_self(),TASK_THREAD_TIMES_INFO,(task_info_t)&cpu,&count);
    mach_task_basic_info_data_t memory={0};
    count=MACH_TASK_BASIC_INFO_COUNT;
    kern_return_t memStatus=task_info(mach_task_self(),MACH_TASK_BASIC_INFO,(task_info_t)&memory,&count);
    CFTimeInterval now=CACurrentMediaTime();
    NSMutableDictionary *row=[@{@"type":@"sample",@"thermal_state":@(NSProcessInfo.processInfo.thermalState),
        @"layout_passes":CPSPerfCounters[@"layout_passes"]?:@0,
        @"resize_applied":CPSPerfCounters[@"resize_applied"]?:@0,
        @"resize_skipped":CPSPerfCounters[@"resize_skipped"]?:@0,
        @"scene_updates":CPSPerfCounters[@"scene_updates"]?:@0} mutableCopy];
    if(status==KERN_SUCCESS) {
        double seconds=(cpu.user_time.seconds-CPSPerfLastCPU.user_time.seconds)+(cpu.user_time.microseconds-CPSPerfLastCPU.user_time.microseconds)/1e6+
           (cpu.system_time.seconds-CPSPerfLastCPU.system_time.seconds)+(cpu.system_time.microseconds-CPSPerfLastCPU.system_time.microseconds)/1e6;
        if(CPSPerfLastWall>0&&now>CPSPerfLastWall)row[@"springboard_cpu_percent"]=@(MAX(0,100*seconds/(now-CPSPerfLastWall)));
        CPSPerfLastCPU=cpu;CPSPerfLastWall=now;
    } else row[@"cpu_error"]=@(status);
    if(memStatus==KERN_SUCCESS)row[@"springboard_resident_bytes"]=@(memory.resident_size);
    else row[@"memory_error"]=@(memStatus);
    CPSPerfWrite(row);
}
static void CPSPerfStop(void) {
    if(!CPSPerfTimer)return;
    CPSPerfMark(@"recording_stop",nil);
    [CPSPerfTimer invalidate];CPSPerfTimer=nil;
}
static void CPSPerfStart(void) {
    if(CPSPerfTimer||![CPSPref(@"perfEnabled") boolValue])return;
    static dispatch_once_t once;
    dispatch_once(&once,^{CPSPerfQueue=dispatch_queue_create("com.chuong.carplaysplit.performance",DISPATCH_QUEUE_SERIAL);});
    CPSPerfCounters=[NSMutableDictionary dictionary];
    CPSPerfLastCPU=(task_thread_times_info_data_t){0};CPSPerfLastWall=0;
    CPSPerfTimer=[NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer){CPSPerfSample();}];
    CPSPerfMark(@"recording_start",@{@"scope":@"SpringBoard process-wide; not Split-only",@"ios":UIDevice.currentDevice.systemVersion});
}
