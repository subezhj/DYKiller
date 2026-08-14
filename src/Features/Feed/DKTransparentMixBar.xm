//
//  DKTransparentMixBar.xm
//  39.8 的合集入口复用 AWEAntiAddictedNoticeBarView，现场签名为 HUD 底部满宽 40pt。
//  只清背景，保留图标、标题、箭头、点击和布局；关闭开关恢复原色。
//

#import "DKKeys.h"
#import "DKSettings.h"
#import "DKUtils.h"
#import <objc/runtime.h>
#import <math.h>

static char kDKMixBarColorKey;
static char kDKMixBarOpaqueKey;

static BOOL DKIsMixBar(UIView *view) {
    UIView *parent = view.superview;
    UIView *stack = parent.superview;
    UILabel *title = nil;
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:UILabel.class]
            && [subview.accessibilityLabel hasSuffix:@"按钮"]
            && subview.accessibilityLabel.length > 2) {
            title = (UILabel *)subview;
            break;
        }
    }
    if (!parent || !stack || !title) return NO;
    return fabs(CGRectGetHeight(view.bounds) - 40.0) <= 0.5
        && fabs(CGRectGetWidth(view.bounds) - CGRectGetWidth(stack.bounds)) <= 0.5
        && [stack.accessibilityLabel isEqualToString:@"bottom"];
}

static void DKSyncMixBar(UIView *view) {
    BOOL active = DKPrefBool(DKKeyTransparentMixBar) && DKIsMixBar(view);
    UIColor *original = objc_getAssociatedObject(view, &kDKMixBarColorKey);
    if (active) {
        if (!original) {
            objc_setAssociatedObject(view, &kDKMixBarColorKey,
                                     view.backgroundColor ?: UIColor.clearColor,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(view, &kDKMixBarOpaqueKey, @(view.opaque),
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if (view.backgroundColor != UIColor.clearColor) view.backgroundColor = UIColor.clearColor;
        view.opaque = NO;
        return;
    }
    if (!original) return;
    view.backgroundColor = original;
    view.opaque = [objc_getAssociatedObject(view, &kDKMixBarOpaqueKey) boolValue];
    objc_setAssociatedObject(view, &kDKMixBarColorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, &kDKMixBarOpaqueKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%hook AWEAntiAddictedNoticeBarView

- (void)layoutSubviews {
    %orig;
    DKSyncMixBar(self);
}

%end

%ctor {
    DKSettingsRegisterItem(@"播放体验", ^AWESettingItemModel *{
        return DKMakeSwitch(
            DKKeyTransparentMixBar,
            @"合集条透明",
            @"清除视频底部合集入口背景，保留图标、文字、箭头与点击"
        );
    });
}
