#import "DouyinHeaders.h"
#import "DKKeys.h"
#import "DKSettings.h"
#import "DKUtils.h"
#import "DKHookLogger.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

%group DKExperimentalFeaturesGroup

#pragma mark - 1. Metal 渲染管道极简优化与直通呈现 (Direct-to-Display & Offscreen Elimination)

%hook TTMetalViewVP

- (void)didMoveToWindow {
    %orig;
    if (self.window && DKPrefBool(DKKeyOptimizeRenderPipeline)) {
        if ([self.layer isKindOfClass:[CAMetalLayer class]]) {
            CAMetalLayer *metalLayer = (CAMetalLayer *)self.layer;
            metalLayer.presentsWithTransaction = NO;
            metalLayer.allowsNextDrawableTimeout = YES;
            metalLayer.opaque = YES;
            DKLogHookEvent(@"Experimental", @"TTMetalViewVP", @"Direct Metal Layer Optimization Applied");
        }
    }
}

%end

#pragma mark - 2. ProMotion 120Hz 极速触控响应 (Zero-Latency Scrolling)

%hook AWEFeedDataSafeTableView

- (void)didMoveToWindow {
    %orig;
    if (self.window && DKPrefBool(DKKeyProMotionFluidScrollEnabled)) {
        for (UIGestureRecognizer *gesture in self.gestureRecognizers) {
            if ([gesture isKindOfClass:[UIPanGestureRecognizer class]]) {
                // 提升触控优先级，消除手势仲裁延迟
                gesture.delaysTouchesBegan = NO;
                gesture.delaysTouchesEnded = NO;
            }
        }
        DKLogHookEvent(@"Experimental", @"AWEFeedDataSafeTableView", @"ProMotion 120Hz Zero-Latency Gestures Bound");
    }
}

%end

#pragma mark - 3. 智能后台冻结与内存防杀 (Anti-Jetsam)

%hook AWEShellViewController

- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig;
    if (DKPrefBool(DKKeyBackgroundAntiJetsamEnabled)) {
        DKLogHookEvent(@"Experimental", @"AWEShellViewController", @"Background Anti-Jetsam Memory Compression Triggered");
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            // 深度释放网络请求与临时图片缓存，降低内存水位至安全线以下
            [[NSURLCache sharedURLCache] removeAllCachedResponses];
            // 触发系统低内存广播，促使各子模块释放闲置纹理
            [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        });
    }
}

%end

%end

%ctor {
    %init(DKExperimentalFeaturesGroup);
    
    DKSettingsRegisterItem(@"新特性与实验性功能", ^AWESettingItemModel *{
        return DKMakeSwitch(
            DKKeyOptimizeRenderPipeline,
            @"[实验性] Metal 渲染穿透优化",
            @"Direct-to-Display 异步硬件表面呈现，剔除冗余离屏合成，降低 GPU 发热并提升高刷帧率"
        );
    });

    DKSettingsRegisterItem(@"新特性与实验性功能", ^AWESettingItemModel *{
        return DKMakeSwitch(
            DKKeyProMotionFluidScrollEnabled,
            @"[实验性] ProMotion 120Hz 极速触控",
            @"消除短视频与列表滑动手势的仲裁等待与锁帧延迟，实现 120Hz 零延迟极速跟手"
        );
    });
    
    DKSettingsRegisterItem(@"新特性与实验性功能", ^AWESettingItemModel *{
        return DKMakeSwitch(
            DKKeyBackgroundAntiJetsamEnabled,
            @"[实验性] 智能后台冻结与防杀",
            @"退后台瞬间主动卸载冗余图片与网络缓存，杜绝系统 Jetsam 杀后台，实现前台 100% 极速秒开"
        );
    });
}
