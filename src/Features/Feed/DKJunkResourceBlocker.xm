//
//  DKJunkResourceBlocker.xm
//  拦截广告推送、监控埋点、离线营销包、活动挂件及垃圾资源联网请求。
//

#import "DouyinHeaders.h"
#import "DKKeys.h"
#import "DKSettings.h"
#import "DKUtils.h"
#import <Foundation/Foundation.h>

@interface TTNetworkManager : NSObject
+ (instancetype)shareEngine;
+ (instancetype)sharedInstance;
@end

static BOOL DKIsJunkURL(NSString *urlString) {
    if (!urlString || urlString.length == 0) return NO;
    static NSArray<NSString *> *junkPatterns;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        junkPatterns = @[
            @"ad.douyin.com",
            @"analytics.snssdk.com",
            @"log.snssdk.com",
            @"mon.snssdk.com",
            @"toblog.ctobsnssdk.com",
            @"applog.douyin.com",
            @"/v1/ad/",
            @"/ad/v",
            @"/advert/",
            @"/splash/",
            @"/service/2/app_log/",
            @"/event/upload",
            @"/slardar/",
            @"/mon/",
            @"/pendant/",
            @"/incentive/",
            @"/luckycat/",
            @"pangolin",
            @"bdturing"
        ];
    });

    for (NSString *pattern in junkPatterns) {
        if ([urlString containsString:pattern]) {
            return YES;
        }
    }
    return NO;
}

%group DKJunkResourceBlockerGroup

%hook TTNetworkManager

- (id)requestForJSONWithURL:(NSString *)urlPath
                     params:(id)params
                     method:(id)method
           needCommonParams:(BOOL)needCommonParams
                headerField:(id)headerField
          requestSerializer:(id)requestSerializer
         responseSerializer:(id)responseSerializer
                 autoResume:(BOOL)autoResume
                   callback:(id)callback {
    if (DKPrefBool(DKKeyBlockJunkResources) && DKIsJunkURL(urlPath)) {
        return nil;
    }
    return %orig;
}

- (id)requestForJSONWithResponse:(NSString *)urlPath
                          params:(id)params
                          method:(id)method
                needCommonParams:(BOOL)needCommonParams
                     headerField:(id)headerField
               requestSerializer:(id)requestSerializer
              responseSerializer:(id)responseSerializer
                      autoResume:(BOOL)autoResume
                        callback:(id)callback {
    if (DKPrefBool(DKKeyBlockJunkResources) && DKIsJunkURL(urlPath)) {
        return nil;
    }
    return %orig;
}

- (id)requestForBinaryWithResponse:(NSString *)urlPath
                            params:(id)params
                            method:(id)method
                  needCommonParams:(BOOL)needCommonParams
                       headerField:(id)headerField
                          callback:(id)callback {
    if (DKPrefBool(DKKeyBlockJunkResources) && DKIsJunkURL(urlPath)) {
        return nil;
    }
    return %orig;
}

%end

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(id)completionHandler {
    if (DKPrefBool(DKKeyBlockJunkResources) && DKIsJunkURL(request.URL.absoluteString)) {
        NSURLRequest *blankRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:@"about:blank"]];
        return %orig(blankRequest, completionHandler);
    }
    return %orig;
}

%end

%hook AWELuckyCatBannerView

- (void)layoutSubviews {
    %orig;
    if (DKPrefBool(DKKeyBlockJunkResources)) {
        if (!self.hidden) self.hidden = YES;
        if (self.alpha != 0.0) self.alpha = 0.0;
    }
}

%end

%hook _TtC21AWEIncentiveSwiftImpl29IncentivePendantContainerView

- (void)layoutSubviews {
    %orig;
    if (DKPrefBool(DKKeyBlockJunkResources)) {
        if (!self.hidden) self.hidden = YES;
        if (self.alpha != 0.0) self.alpha = 0.0;
    }
}

%end

%end

%ctor {
    %init(DKJunkResourceBlockerGroup);
    DKSettingsRegisterItem(@"净化", ^AWESettingItemModel *{
        return DKMakeSwitch(
            DKKeyBlockJunkResources,
            @"垃圾资源与网络拦截",
            @"拦截广告推送、监控埋点、活动挂件及垃圾资源联网请求，降低数据流量与后台耗电"
        );
    });
}
