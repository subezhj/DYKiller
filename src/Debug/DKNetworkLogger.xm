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
@property (nonatomic, copy) NSString *paramsSummary;
@property (nonatomic, copy) NSString *componentTag;
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

static void DKAddNetworkLogDetailed(NSString *url, NSString *method, id params, NSInteger statusCode) {
    if (!url || url.length == 0) return;
    DKNetworkRequestLog *log = [[DKNetworkRequestLog alloc] init];
    log.url = url;
    log.method = method ?: @"GET";
    log.statusCode = statusCode;
    
    // 智能标记组件与业务类型（如 feed, sticker, gecko, lynx, ad, live）
    NSMutableString *tag = [NSMutableString string];
    if ([url containsString:@"/feed/"]) [tag appendString:@"[FEED_STREAM] "];
    if ([url containsString:@"gecko"] || [url containsString:@"lynx"]) [tag appendString:@"[LYNX_GECKO] "];
    if ([url containsString:@"sticker"] || [url containsString:@"widget"]) [tag appendString:@"[STICKER_WIDGET] "];
    if ([url containsString:@"live"]) [tag appendString:@"[LIVE_ROOM] "];
    if ([url containsString:@"commerce"] || [url containsString:@"ecom"] || [url containsString:@"ad/"]) [tag appendString:@"[ECOM_AD] "];
    log.componentTag = tag.length > 0 ? [tag copy] : @"";

    if (params) {
        if ([params isKindOfClass:[NSDictionary class]]) {
            NSError *err = nil;
            NSData *data = [NSJSONSerialization dataWithJSONObject:params options:0 error:&err];
            if (data) {
                log.paramsSummary = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                if (log.paramsSummary.length > 200) {
                    log.paramsSummary = [[log.paramsSummary substringToIndex:200] stringByAppendingString:@"..."];
                }
            }
        } else if ([params isKindOfClass:[NSString class]]) {
            log.paramsSummary = (NSString *)params;
        }
    }
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm:ss.SSS";
    log.dateString = [formatter stringFromDate:[NSDate date]];
    
    NSMutableArray *logs = DKGetNetworkLogs();
    @synchronized (logs) {
        if (logs.count >= 1000) {
            [logs removeObjectAtIndex:0];
        }
        [logs addObject:log];
    }
}

static void DKAddNetworkLog(NSString *url, NSString *method, NSInteger statusCode) {
    DKAddNetworkLogDetailed(url, method, nil, statusCode);
}

static BOOL DKNetworkLoggerActive(void) {
    id val = [[NSUserDefaults standardUserDefaults] objectForKey:DKKeyNetworkLoggerEnabled];
    return val ? [val boolValue] : YES;
}

%group DKNetworkLoggerGroup

%hook TTNetworkManager

- (id)requestForJSONWithURL:(NSString *)url
                     params:(id)params
                     method:(NSString *)method
           needCommonParams:(BOOL)needCommonParams
                headerField:(id)headerField
          requestSerializer:(Class)requestSerializerClass
         responseSerializer:(Class)responseSerializerClass
                 autoResume:(BOOL)autoResume
                   callback:(id)callback {
    if (DKNetworkLoggerActive()) {
        DKAddNetworkLogDetailed(url, method, params, 200);
    }
    return %orig;
}

- (id)requestForJSONWithResponse:(NSString *)url
                          params:(id)params
                          method:(NSString *)method
                needCommonParams:(BOOL)needCommonParams
                     headerField:(id)headerField
               requestSerializer:(Class)requestSerializerClass
              responseSerializer:(Class)responseSerializerClass
                      autoResume:(BOOL)autoResume
                        callback:(id)callback {
    if (DKNetworkLoggerActive()) {
        DKAddNetworkLogDetailed(url, method, params, 200);
    }
    return %orig;
}

- (id)requestForBinaryWithResponse:(NSString *)url
                            params:(id)params
                            method:(NSString *)method
                  needCommonParams:(BOOL)needCommonParams
                       headerField:(id)headerField
                          callback:(id)callback {
    if (DKNetworkLoggerActive()) {
        DKAddNetworkLogDetailed(url, method, params, 200);
    }
    return %orig;
}

%end

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(id)completionHandler {
    if (DKNetworkLoggerActive() && request.URL.absoluteString) {
        DKAddNetworkLog(request.URL.absoluteString, request.HTTPMethod ?: @"GET", 200);
    }
    return %orig;
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    if (DKNetworkLoggerActive() && request.URL.absoluteString) {
        DKAddNetworkLog(request.URL.absoluteString, request.HTTPMethod ?: @"GET", 200);
    }
    return %orig;
}

%end

%end

#ifdef __cplusplus
extern "C" {
#endif

NSString *DKNetworkLoggerReport(void) {
    NSMutableArray *logs = DKGetNetworkLogs();
    NSMutableString *outStr = [NSMutableString string];
    [outStr appendString:@"=== DYKiller API Network Logger Report (Detailed WiFi & Component Capture) ===\n\n"];
    @synchronized (logs) {
        if (logs.count == 0) {
            [outStr appendString:@"(No network requests captured yet)\n"];
        } else {
            for (DKNetworkRequestLog *log in logs) {
                [outStr appendFormat:@"[%@] %@ %ld %@%@\n", log.dateString, log.method, (long)log.statusCode, log.componentTag ?: @"", log.url];
                if (log.paramsSummary.length > 0) {
                    [outStr appendFormat:@"    Payload/Params: %@\n", log.paramsSummary];
                }
            }
        }
    }
    return [outStr copy];
}

#ifdef __cplusplus
}
#endif


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
