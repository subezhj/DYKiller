//
//  DKFluidGestures.xm
//  DYKiller
//
//  非侵入式流体手势系统（0 悬浮图标，0 视觉侵入）
//  - 双指捏合 (Pinch)：快速切换纯净清屏模式 / 恢复 HUD 浮层
//  - 双指轻击 (Two-Finger Tap)：循环切换播放倍速 (1.0x -> 1.5x -> 2.0x -> 3.0x)
//

#import "DouyinHeaders.h"
#import "DKKeys.h"
#import "DKUtils.h"
#import "DKSettings.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char kDKFluidGesturesInstalledKey;
static char kDKCleanScreenActiveKey;

static BOOL DKFluidGesturesEnabled(void) {
    return DKPrefBool(DKKeyFluidGesturesEnabled);
}

static void DKShowToastHUD(UIView *parentView, NSString *message) {
    if (!parentView || !message) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        static UIView *sToastView = nil;
        static UILabel *sToastLabel = nil;
        if (sToastView) [sToastView removeFromSuperview];

        sToastView = [[UIView alloc] init];
        sToastView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.75];
        sToastView.layer.cornerRadius = 16.0;
        sToastView.clipsToBounds = YES;

        sToastLabel = [[UILabel alloc] init];
        sToastLabel.text = message;
        sToastLabel.textColor = [UIColor whiteColor];
        sToastLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
        sToastLabel.textAlignment = NSTextAlignmentCenter;
        [sToastView addSubview:sToastLabel];

        CGSize textSize = [message sizeWithAttributes:@{NSFontAttributeName: sToastLabel.font}];
        CGFloat w = textSize.width + 32.0;
        CGFloat h = 36.0;
        CGFloat x = (parentView.bounds.size.width - w) / 2.0;
        CGFloat y = parentView.bounds.size.height - parentView.safeAreaInsets.bottom - 100.0;
        sToastView.frame = CGRectMake(x, y, w, h);
        sToastLabel.frame = CGRectMake(16.0, 0, textSize.width, h);

        [parentView addSubview:sToastView];

        sToastView.alpha = 0.0;
        [UIView animateWithDuration:0.2 animations:^{
            sToastView.alpha = 1.0;
        } completion:^(BOOL finished) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.3 animations:^{
                    sToastView.alpha = 0.0;
                } completion:^(BOOL finished2) {
                    [sToastView removeFromSuperview];
                }];
            });
        }];
    });
}

%hook AWEPlayVideoViewController

- (void)viewDidLayoutSubviews {
    %orig;
    if (!DKFluidGesturesEnabled()) return;

    UIView *view = self.viewIfLoaded;
    if (!view) return;

    if (!objc_getAssociatedObject(view, &kDKFluidGesturesInstalledKey)) {
        objc_setAssociatedObject(view, &kDKFluidGesturesInstalledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        // 双指捏合手势 (Pinch to Clean Screen)
        UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(dk_handleFluidPinch:)];
        [view addGestureRecognizer:pinch];

        // 双指轻击手势 (Two Finger Tap to Cycle Speed)
        UITapGestureRecognizer *twoFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dk_handleFluidTwoFingerTap:)];
        twoFingerTap.numberOfTouchesRequired = 2;
        twoFingerTap.numberOfTapsRequired = 1;
        [view addGestureRecognizer:twoFingerTap];
    }
}

static BOOL DKIsProgressRelatedView(UIView *sub) {
    if (!sub) return NO;
    NSString *cls = NSStringFromClass(sub.class);
    if ([cls containsString:@"Progress"] ||
        [cls containsString:@"Slider"] ||
        [cls containsString:@"Underline"] ||
        [cls containsString:@"Seek"]) {
        return YES;
    }
    return NO;
}

%new
- (void)dk_handleFluidPinch:(UIPinchGestureRecognizer *)pinch {
    if (pinch.state == UIGestureRecognizerStateEnded) {
        UIViewController *interactionVC = nil;
        if ([self respondsToSelector:@selector(interactionViewController)]) {
            interactionVC = [self performSelector:@selector(interactionViewController)];
        }
        if (!interactionVC) return;

        UIView *hudView = interactionVC.viewIfLoaded;
        if (!hudView) return;

        BOOL isClean = [objc_getAssociatedObject(hudView, &kDKCleanScreenActiveKey) boolValue];
        BOOL targetClean = !isClean;
        BOOL keepProgress = DKPrefBool(DKKeyKeepProgressInCleanMode);

        [UIView animateWithDuration:0.25 animations:^{
            if (targetClean && keepProgress) {
                for (UIView *sub in hudView.subviews) {
                    if (DKIsProgressRelatedView(sub)) {
                        sub.alpha = 1.0;
                        sub.hidden = NO;
                    } else {
                        sub.alpha = 0.0;
                    }
                }
            } else {
                for (UIView *sub in hudView.subviews) {
                    sub.alpha = targetClean ? 0.0 : 1.0;
                }
                hudView.alpha = targetClean ? 0.0 : 1.0;
            }
        }];

        objc_setAssociatedObject(hudView, &kDKCleanScreenActiveKey, @(targetClean), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        DKShowToastHUD(self.view, (targetClean && keepProgress) ? @"✨ 纯净清屏 (保留进度条)" : (targetClean ? @"✨ 纯净清屏模式" : @"📺 恢复界面浮层"));
    }
}

%new
- (void)dk_handleFluidTwoFingerTap:(UITapGestureRecognizer *)tap {
    if (tap.state == UIGestureRecognizerStateEnded) {
        static CGFloat sSpeedRates[] = {1.0, 1.25, 1.5, 2.0, 3.0};
        static NSInteger sCurrentIndex = 0;
        sCurrentIndex = (sCurrentIndex + 1) % 5;
        CGFloat targetSpeed = sSpeedRates[sCurrentIndex];

        SEL selRate = NSSelectorFromString(@"setPlaybackRate:");
        if ([self respondsToSelector:selRate]) {
            typedef void (*DKSetRateIMP)(id, SEL, CGFloat);
            DKSetRateIMP impFunc = (DKSetRateIMP)[self methodForSelector:selRate];
            if (impFunc) impFunc(self, selRate, targetSpeed);
        }

        NSString *msg = [NSString stringWithFormat:@"🚀 播放倍速切换至: %.2fx", targetSpeed];
        if (targetSpeed == 1.0) msg = @"▶️ 恢复正常 1.0x 速度";
        DKShowToastHUD(self.view, msg);
    }
}

%end

%hook AWEFeedProgressSlider

- (void)setAlpha:(CGFloat)alpha {
    if (DKPrefBool(DKKeyKeepProgressInCleanMode) && alpha < 0.1) {
        %orig(1.0);
        return;
    }
    %orig(alpha);
}

- (void)setHidden:(BOOL)hidden {
    if (DKPrefBool(DKKeyKeepProgressInCleanMode) && hidden) {
        %orig(NO);
        return;
    }
    %orig(hidden);
}

%end

%hook AWEDPlayerProgressContainerView

- (void)setAlpha:(CGFloat)alpha {
    if (DKPrefBool(DKKeyKeepProgressInCleanMode) && alpha < 0.1) {
        %orig(1.0);
        return;
    }
    %orig(alpha);
}

- (void)setHidden:(BOOL)hidden {
    if (DKPrefBool(DKKeyKeepProgressInCleanMode) && hidden) {
        %orig(NO);
        return;
    }
    %orig(hidden);
}

%end

%ctor {
    DKSettingsRegisterItem(@"视频全屏", ^AWESettingItemModel *{
        return DKMakeSwitch(DKKeyFluidGesturesEnabled, @"非侵入式流体手势", @"两指捏合任意位置切清屏，两指轻击循环切倍速（0 悬浮图标）");
    });
}
