//
//  DKHookLogger.mm
//  DYKiller
//

#import "DKHookLogger.h"
#import "DKKeys.h"
#import "DKUtils.h"
#import <UIKit/UIKit.h>
#import <mach/mach.h>
#import <objc/runtime.h>

static NSMutableArray<NSString *> *gHookLogBuffer;
static dispatch_queue_t gHookLogQueue;

static BOOL gDKIsCapturingLogs = NO;
static NSDate *gDKCaptureStartTime = nil;

static void DKInitHookLoggerIfNeeded(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gHookLogBuffer = [NSMutableArray array];
        gHookLogQueue = dispatch_queue_create("com.dykiller.hooklogger", DISPATCH_QUEUE_SERIAL);
    });
}

void DKStartLogCapture(void) {
    DKInitHookLoggerIfNeeded();
    dispatch_async(gHookLogQueue, ^{
        [gHookLogBuffer removeAllObjects];
        gDKIsCapturingLogs = YES;
        gDKCaptureStartTime = [NSDate date];
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
        [gHookLogBuffer addObject:[NSString stringWithFormat:@"=== 调试日志抓取已开启 (%@) ===", [formatter stringFromDate:gDKCaptureStartTime]]];
    });
}

void DKStopLogCapture(void) {
    DKInitHookLoggerIfNeeded();
    dispatch_async(gHookLogQueue, ^{
        if (!gDKIsCapturingLogs) return;
        gDKIsCapturingLogs = NO;
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
        NSTimeInterval duration = gDKCaptureStartTime ? [[NSDate date] timeIntervalSinceDate:gDKCaptureStartTime] : 0.0;
        [gHookLogBuffer addObject:[NSString stringWithFormat:@"=== 调试日志抓取已停止 (%@, 累计时长: %.1f 秒) ===", [formatter stringFromDate:[NSDate date]], duration]];
    });
}

BOOL DKIsLogCapturing(void) {
    return gDKIsCapturingLogs;
}

void DKClearHookLogsBuffer(void) {
    DKInitHookLoggerIfNeeded();
    dispatch_async(gHookLogQueue, ^{
        [gHookLogBuffer removeAllObjects];
    });
}

void DKLogHookEvent(NSString *feature, NSString *hookName, NSString *details) {
    DKInitHookLoggerIfNeeded();
    dispatch_async(gHookLogQueue, ^{
        if (!gDKIsCapturingLogs) return;
        if (gHookLogBuffer.count > 1000) {
            [gHookLogBuffer removeObjectsInRange:NSMakeRange(0, 200)];
        }
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"HH:mm:ss.SSS";
        NSString *timeStr = [formatter stringFromDate:[NSDate date]];

        NSString *entry = [NSString stringWithFormat:@"[%@] [%@] %@ -> %@",
                           timeStr,
                           feature ?: @"General",
                           hookName ?: @"UnknownHook",
                           details ?: @""];
        [gHookLogBuffer addObject:entry];
    });
}

NSString *DKGetHookLogsText(void) {
    DKInitHookLoggerIfNeeded();
    __block NSString *result = nil;
    dispatch_sync(gHookLogQueue, ^{
        result = [gHookLogBuffer componentsJoinedByString:@"\n"];
    });
    return result.length ? result : @"=== No Hook Events Recorded ===";
}

static float DKGetCPUUsage(void) {
    kern_return_t kr;
    task_info_data_t tinfo;
    mach_msg_type_number_t task_info_count = TASK_INFO_MAX;
    kr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)tinfo, &task_info_count);
    if (kr != KERN_SUCCESS) return 0.0f;

    thread_array_t thread_list;
    mach_msg_type_number_t thread_count;
    thread_basic_info_t basic_info_th;
    mach_msg_type_number_t thread_info_count;

    kr = task_threads(mach_task_self(), &thread_list, &thread_count);
    if (kr != KERN_SUCCESS) return 0.0f;

    float total_cpu = 0.0f;
    for (mach_msg_type_number_t j = 0; j < thread_count; j++) {
        thread_info_count = THREAD_INFO_MAX;
        basic_info_th = (thread_basic_info_t)malloc(sizeof(thread_basic_info_data_t));
        kr = thread_info(thread_list[j], THREAD_BASIC_INFO, (thread_info_t)basic_info_th, &thread_info_count);
        if (kr == KERN_SUCCESS) {
            if (!(basic_info_th->flags & TH_FLAGS_IDLE)) {
                total_cpu += basic_info_th->cpu_usage / (float)TH_USAGE_SCALE * 100.0f;
            }
        }
        free(basic_info_th);
    }
    vm_deallocate(mach_task_self(), (vm_offset_t)thread_list, thread_count * sizeof(thread_act_t));
    return total_cpu;
}

static double DKGetMemoryFootprintMB(void) {
    task_vm_info_data_t vmInfo;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    kern_return_t result = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&vmInfo, &count);
    if (result == KERN_SUCCESS) {
        return (double)vmInfo.phys_footprint / (1024.0 * 1024.0);
    }
    return 0.0;
}

NSString *DKGetPerformanceMetricsReport(void) {
    NSMutableString *report = [NSMutableString string];
    [report appendString:@"=== DYKiller Diagnostic & Performance Report ===\n"];

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    [report appendFormat:@"Report Time: %@\n", [formatter stringFromDate:[NSDate date]]];

    float cpu = DKGetCPUUsage();
    double ram = DKGetMemoryFootprintMB();
    [report appendFormat:@"CPU Usage: %.2f%%\n", cpu];
    [report appendFormat:@"RAM Memory Footprint: %.2f MB\n", ram];

    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    float batteryLevel = [UIDevice currentDevice].batteryLevel;
    UIDeviceBatteryState batteryState = [UIDevice currentDevice].batteryState;
    NSString *stateStr = @"Unknown";
    if (batteryState == UIDeviceBatteryStateUnplugged) stateStr = @"Unplugged (Discharging)";
    else if (batteryState == UIDeviceBatteryStateCharging) stateStr = @"Charging";
    else if (batteryState == UIDeviceBatteryStateFull) stateStr = @"Full";
    [report appendFormat:@"Battery Level: %.0f%%\n", batteryLevel * 100.0f];
    [report appendFormat:@"Battery State: %@\n\n", stateStr];

    [report appendString:@"=== Active DYKiller Feature Configuration ===\n"];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [report appendFormat:@"DYKillerVideoFullscreen: %d\n", [defaults boolForKey:DKKeyVideoFullscreen]];
    [report appendFormat:@"DYKillerGlassTabBar: %d\n", [defaults boolForKey:DKKeyGlassTabBar]];
    [report appendFormat:@"DYKillerCommentGlass: %d\n", [defaults boolForKey:DKKeyCommentGlass]];
    [report appendFormat:@"DYKillerMediaIslandEnabled: %d\n", [defaults boolForKey:DKKeyMediaIslandEnabled]];
    [report appendFormat:@"DYKillerLiveActivityIslandEnabled: %d\n", [defaults boolForKey:DKKeyLiveActivityIslandEnabled]];
    [report appendFormat:@"DYKillerPiPQuickLaunchEnabled: %d\n", [defaults boolForKey:DKKeyPiPQuickLaunchEnabled]];
    [report appendFormat:@"DYKillerBlockJunkResources: %d\n", [defaults boolForKey:DKKeyBlockJunkResources]];

    BOOL dyyyFS = [defaults boolForKey:@"DYYYEnableFullScreen"];
    [report appendFormat:@"\nDYYY Coexistence Status (DYYYEnableFullScreen): %d\n", dyyyFS];

    return report;
}
