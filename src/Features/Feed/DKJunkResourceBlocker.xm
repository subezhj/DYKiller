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
    if (DKPrefBool(DKKeyBlockJunkResources) || DKPrefBool(DKKeyBlockMarketingLayers)) {
        if (!self.hidden) self.hidden = YES;
        if (self.alpha != 0.0) self.alpha = 0.0;
    }
}

%end

%hook AWEAwemePlayletWaterMarkView

- (void)layoutSubviews {
    %orig;
    if (DKPrefBool(DKKeyBlockMarketingLayers)) {
        self.hidden = YES;
        self.frame = CGRectZero;
    }
}

%end

// 1. 主页/全屏营销活动悬浮球与挂件屏蔽
%hook AWECommercePendantView

- (void)layoutSubviews {
    %orig;
    if (DKPrefBool(DKKeyBlockHomePagePendants) || DKPrefBool(DKKeyBlockMarketingLayers)) {
        self.hidden = YES;
        self.frame = CGRectZero;
    }
}

%end

// 2. 电商带货小黄车与广告落地页卡片屏蔽
%hook AWECommerceAnchorView

- (void)layoutSubviews {
    %orig;
    if (DKPrefBool(DKKeyBlockEcommerceMarketing) || DKPrefBool(DKKeyBlockMarketingLayers)) {
        self.hidden = YES;
    }
}

%end

%hook AWEPOITradeEntryAnchorView

- (void)layoutSubviews {
    %orig;
    if (DKPrefBool(DKKeyBlockEcommerceMarketing) || DKPrefBool(DKKeyBlockMarketingLayers)) {
        self.hidden = YES;
    }
}

%end

// 3. 图文同城生活卡片与团购推荐条屏蔽 (Rich Aweme Life Card)
%hook AWERichAwemeLifeCardImageDescView

- (void)layoutSubviews {
    %orig;
    if (DKPrefBool(DKKeyBlockEcommerceMarketing) || DKPrefBool(DKKeyBlockMarketingLayers)) {
        self.hidden = YES;
        self.frame = CGRectZero;
    }
}

%end

// 4. 冗余 Lynx 动态前端卡片与多图文团购卡片拦截
%hook UILynxView

- (void)layoutSubviews {
    %orig;
    if (DKPrefBool(DKKeyBlockLynxComponents) || DKPrefBool(DKKeyBlockEcommerceMarketing) || DKPrefBool(DKKeyBlockMarketingLayers)) {
        // 针对 Feed 流及图文内的营销/广告/团购/非核心 Lynx 卡片做安全隐藏
        UIView *parent = self.superview;
        if (parent && ([NSStringFromClass(parent.class) containsString:@"Ad"] ||
                       [NSStringFromClass(parent.class) containsString:@"Banner"] ||
                       [NSStringFromClass(parent.class) containsString:@"Commerce"] ||
                       [NSStringFromClass(parent.class) containsString:@"Life"] ||
                       [NSStringFromClass(parent.class) containsString:@"LynxContent"] ||
                       [NSStringFromClass(parent.class) containsString:@"Sticker"])) {
            if (!self.hidden) self.hidden = YES;
        }
    }
}

%end

%hook AWEAwemeModel

- (BOOL)isAd {
    if (DKPrefBool(DKKeyBlockEcommerceMarketing) || DKPrefBool(DKKeyBlockMarketingLayers) || DKPrefBool(DKKeyBlockJunkResources)) {
        return NO;
    }
    return %orig;
}

- (BOOL)isCommerce {
    if (DKPrefBool(DKKeyBlockEcommerceMarketing) || DKPrefBool(DKKeyBlockMarketingLayers) || DKPrefBool(DKKeyBlockJunkResources)) {
        return NO;
    }
    return %orig;
}

- (NSInteger)adLinkType {
    if (DKPrefBool(DKKeyBlockEcommerceMarketing) || DKPrefBool(DKKeyBlockMarketingLayers) || DKPrefBool(DKKeyBlockJunkResources)) {
        return 0;
    }
    return %orig;
}

%end

%hook AWEFeedCellViewController

- (void)setModel:(id)model {
    %orig;
    if (DKPrefBool(DKKeyBlockEcommerceMarketing) || DKPrefBool(DKKeyBlockMarketingLayers) || DKPrefBool(DKKeyBlockJunkResources)) {
        if ([model respondsToSelector:@selector(isAd)] && [(id)model isAd]) {
            self.view.hidden = YES;
        }
        if ([model respondsToSelector:@selector(isCommerce)] && [(id)model isCommerce]) {
            self.view.hidden = YES;
        }
    }
}

%end

%end

%ctor {
    %init(DKJunkResourceBlockerGroup);
    DKSettingsRegisterItem(@"净化与拦截", ^AWESettingItemModel *{
        return DKMakeSwitch(
            DKKeyBlockJunkResources,
            @"网络垃圾与埋点拦截",
            @"拦截广告推送、监控埋点及离线垃圾资源联网请求，降低数据流量与后台耗电"
        );
    });
    DKSettingsRegisterItem(@"净化与拦截", ^AWESettingItemModel *{
        return DKMakeSwitch(
            DKKeyBlockHomePagePendants,
            @"屏蔽活动营销挂件",
            @"屏蔽主页及视频画面上的节日活动悬浮球、红包任务挂件与集卡浮窗"
        );
    });
    DKSettingsRegisterItem(@"净化与拦截", ^AWESettingItemModel *{
        return DKMakeSwitch(
            DKKeyBlockEcommerceMarketing,
            @"屏蔽电商带货与广告",
            @"隐藏视频左下角带货小黄车、团购推荐锚点与广告导流卡片"
        );
    });
    DKSettingsRegisterItem(@"净化与拦截", ^AWESettingItemModel *{
        return DKMakeSwitch(
            DKKeyBlockLynxComponents,
            @"拦截冗余 Lynx 动态卡片",
            @"阻止 Feed 流与活动容器加载非必要的 Lynx 动态前端广告与营销模版"
        );
    });
    DKSettingsRegisterItem(@"净化与拦截", ^AWESettingItemModel *{
        return DKMakeSwitch(
            DKKeyBlockMarketingLayers,
            @"拦截短剧引流与水印图层",
            @"屏蔽短剧水文引流、全屏推广图层与营销背景遮罩（不影响正常视频预加载）"
        );
    });
}
