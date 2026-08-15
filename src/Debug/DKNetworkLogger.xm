//
//  DKNetworkLogger.xm
//  类似 FLEX++ URLCapture / URLIntercept，实时抓取与记录网络请求 API 日志。
//

#import "DouyinHeaders.h"
#import "DKKeys.h"
#import "DKSettings.h"
#import "DKUtils.h"
#import <Foundation/Foundation.h>

@interface DKNetworkRequestLog : NSObject
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *method;
@property (nonatomic, copy) NSString *dateString;
@property (nonatomic, assign) NSInteger statusCode;
@end

@implementation DKNetworkRequestLog
@end

static NSMutableArray<DKNetworkRequestLog *> *DKGetNetworkLogs(void) {
    static NSMutableArray *logs;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        logs = [NSMutableArray array];
    });
    return logs;
}

static void DKAddNetworkLog(NSString *url, NSString *method, NSInteger statusCode) {
    if (!url || url.length == 0) return;
    DKNetworkRequestLog *log = [[DKNetworkRequestLog alloc] init];
    log.url = url;
    log.method = method ?: @"GET";
    log.statusCode = statusCode;
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm:ss";
    log.dateString = [formatter stringFromDate:[NSDate date]];
    
    NSMutableArray *logs = DKGetNetworkLogs();
    @synchronized (logs) {
        if (logs.count >= 100) {
            [logs removeObjectAtIndex:0];
        }
        [logs addObject:log];
    }
}

%group DKNetworkLoggerGroup

%hook TTNetworkManager

- (id)requestForURL:(NSString *)urlPath
             method:(NSString *)method
             params:(NSDictionary *)params
       headerFields:(NSDictionary *)headerFields
  requestSerializer:(Class)requestSerializer
 responseSerializer:(Class)responseSerializer
         autoResume:(BOOL)autoResume
           callback:(id)callback {
    if (DKPrefBool(DKKeyNetworkLoggerEnabled)) {
        DKAddNetworkLog(urlPath, method, 200);
    }
    return %orig;
}

- (id)requestForJSONWithURL:(NSString *)urlPath
                     method:(NSString *)method
                     params:(NSDictionary *)params
               headerFields:(NSDictionary *)headerFields
                   callback:(id)callback {
    if (DKPrefBool(DKKeyNetworkLoggerEnabled)) {
        DKAddNetworkLog(urlPath, method, 200);
    }
    return %orig;
}

%end

%end

NSString *DKNetworkLoggerReport(void) {
    NSMutableArray *logs = DKGetNetworkLogs();
    NSMutableString *outStr = [NSMutableString string];
    [outStr appendString:@"=== DYKiller API Network Logger Report ===\n"];
    @synchronized (logs) {
        if (logs.count == 0) {
            [outStr appendString:@"(No network requests captured yet)\n"];
        } else {
            for (DKNetworkRequestLog *log in logs) {
                [outStr appendFormat:@"[%@] %@ %ld %@\n", log.dateString, log.method, (long)log.statusCode, log.url];
            }
        }
    }
    return [outStr copy];
}

%ctor {
    %init(DKNetworkLoggerGroup);
    DKSettingsRegisterItem(@"调试", ^AWESettingItemModel *{
        return DKMakeSwitch(
            DKKeyNetworkLoggerEnabled,
            @"API 网络请求抓包日志",
            @"参考 FLEX++ URLIntercept，开启后实时记录 App 所有 API 联网请求"
        );
    });
}
