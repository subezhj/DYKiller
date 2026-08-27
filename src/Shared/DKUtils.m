//
//  DKUtils.m
//  作为普通 .m 编译一次、被各功能文件链接复用。
//

#import "DKUtils.h"
#import "DKGlassGuard.h"
#import "DKKeys.h"
#import "DouyinHeaders.h"

#include <stdatomic.h>

BOOL DKPrefBool(NSString *key) {
    if (DKGlassIsGatedKey(key) && !DKGlassOSAvailable()) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

NSInteger DKPrefInteger(NSString *key) {
    if (DKGlassIsGatedKey(key) && !DKGlassOSAvailable()) return 0;
    return [[NSUserDefaults standardUserDefaults] integerForKey:key];
}

#pragma mark - 控制器查找

static UIViewController *DKSearchChildController(UIViewController *controller, NSString *className, NSUInteger depth) {
    if (!controller || depth > 12) return nil;
    for (UIViewController *child in controller.childViewControllers) {
        if ([NSStringFromClass(child.class) isEqualToString:className]) return child;
        UIViewController *match = DKSearchChildController(child, className, depth + 1);
        if (match) return match;
    }
    return nil;
}

UIViewController *DKChildControllerNamed(UIViewController *controller, NSString *className) {
    return DKSearchChildController(controller, className, 0);
}

#pragma mark - 颜色

BOOL DKColorIsOpaqueBlack(UIColor *color) {
    if (!color) return NO;

    CGFloat red = 0.0;
    CGFloat green = 0.0;
    CGFloat blue = 0.0;
    CGFloat alpha = 0.0;
    if ([color getRed:&red green:&green blue:&blue alpha:&alpha]) {
        return red <= 0.02 && green <= 0.02 && blue <= 0.02 && alpha >= 0.98;
    }

    CGFloat white = 0.0;
    if ([color getWhite:&white alpha:&alpha]) {
        return white <= 0.02 && alpha >= 0.98;
    }
    return NO;
}

#pragma mark - 液态玻璃染色

// 深色档的黑色染色强度：实测评论面板亮度比 0.90、底栏 platter 中位亮度 136.6 → 99.8，
// 两处都明确是深色玻璃且背后细节完整。
static const CGFloat kDKGlassDarkTintAlpha = 0.30;

UIColor *DKGlassTintForStyle(UIUserInterfaceStyle style) {
    if (style != UIUserInterfaceStyleDark) return nil;
    return [UIColor colorWithWhite:0.0 alpha:kDKGlassDarkTintAlpha];
}

#pragma mark - Cell 几何

UIView *DKCellContentView(UIView *view) {
    static Class contentCls;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ contentCls = NSClassFromString(@"UITableViewCellContentView"); });
    if (!contentCls) return nil;

    for (NSUInteger i = 0; view && i < 12; i++) {
        if ([view isKindOfClass:contentCls]) return view;
        view = view.superview;
    }
    return nil;
}

CGFloat DKFullCellHeight(UIView *view) {
    UIView *contentView = DKCellContentView(view.superview);
    return contentView ? CGRectGetHeight(contentView.bounds) : 0.0;
}

#pragma mark - defaults 变更纪元

// 任意键写入（含抖音/DYYY 自己写的）都会触发通知，纪元 +1。
// 读方各自把“重算开关合成值”的成本摊到变更之后的第一帧，热路径上只做整数比较。
static atomic_uint gDKDefaultsEpoch;
static id gDKDefaultsObserver;

__attribute__((constructor))
static void DKUtilsBoot(void) {
    gDKDefaultsObserver = [[NSNotificationCenter defaultCenter]
        addObserverForName:NSUserDefaultsDidChangeNotification
                    object:nil
                     queue:nil
                usingBlock:^(__unused NSNotification *note) {
        atomic_fetch_add_explicit(&gDKDefaultsEpoch, 1, memory_order_relaxed);
    }];
}

uint32_t DKDefaultsEpoch(void) {
    return atomic_load_explicit(&gDKDefaultsEpoch, memory_order_relaxed);
}

#pragma mark - 全局 setFrame 守卫（纪元缓存）

// 语义与原逐帧判定完全一致：DKVideoFullscreenOn || DKCommentFreezeOn || 自定义背景 > 0。
// 与 DKVideoGeometry.xm 的全局 UIView setFrame: 钩子配套。
BOOL DKHotVideoGeometryActive(void) {
    static uint32_t cachedEpoch = UINT32_MAX;
    static BOOL cachedValue = NO;
    uint32_t epoch = DKDefaultsEpoch();
    if (epoch == cachedEpoch) return cachedValue;
    cachedEpoch = epoch;

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSNumber *mode = [defaults objectForKey:DKKeyVideoFullscreenMode];
    BOOL fullscreen = mode ? mode.integerValue > 0
                           : [defaults boolForKey:DKKeyVideoFullscreen];
    BOOL freeze = DKGlassOSAvailable() && [defaults boolForKey:DKKeyCommentGlass];
    BOOL backdrop = [defaults integerForKey:DKKeyCustomBackdropColorStyle] > 0;

    cachedValue = fullscreen || freeze || backdrop;
    return cachedValue;
}
