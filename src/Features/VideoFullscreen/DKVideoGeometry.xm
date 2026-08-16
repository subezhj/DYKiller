//
//  DKVideoGeometry.xm
//  视频几何的唯一拦截点，以及「视频全屏」这一个开关的注册处。
//
//  全项目**只剩这一个**全局 UIView 钩子（`setFrame:`）。分派按写入方的归属控制器，
//  不按视图在哪棵树里——归属是写入方自己的身份，不会串台：
//    · AWEDPlayerViewController_Merge  → 视频容器，一套规则通吃首页/朋友页/好友聊天/搜索/作品页；
//    · AWEPlayInteractionViewController → HUD，只有撑高过的表需要钉位，其余一律放行。
//
//  为什么这一处必须是写入时拦截、不能改成事后纠正：九份导出实测
//  `HUD setFrame=128~148` 对 `布局后兜底=4~11`，写入时拦截承担 95% 以上。
//  改成事后纠正等于把一百多次修正压给布局回合，必然可见跳动。
//
//  图文不在这里：它的缩放入口是 RichContentContainerViewController 的 updateShrinkState:，
//  一个精准钩子覆盖全部图文类型，见 DKVideoPageChrome.xm。
//

#import "DouyinHeaders.h"
#import "DKVideoFullscreen.h"
#import "DKGlassGuard.h"
#import "DKKeys.h"
#import "DKSettings.h"
#import "DKUtils.h"
#import <math.h>
#import <mach-o/dyld.h>
#import <string.h>

// 高/宽达到此阈值才算「比例达标」，可以拉满整屏；低比例竖屏与横屏保持容器自然尺寸。
static const CGFloat kDKFullscreenMinAspect = 1.70;
static const long long kDKAwemeTypeImage = 68;
// 覆盖 @3x 像素对齐带来的亚像素漂移。
static const CGFloat kDKGeometryTolerance = 0.5;
// 关闭开关时要立刻还原的分支回调；分支不多，固定容量即可。
static void (*gRestoreHooks[4])(void);
static NSUInteger gRestoreCount = 0;

NSInteger DKVideoFullscreenModeValue(void) {
    NSNumber *stored = [NSUserDefaults.standardUserDefaults objectForKey:DKKeyVideoFullscreenMode];
    if (stored) {
        return MAX(0, MIN(stored.integerValue, 2));
    }
    return DKPrefBool(DKKeyVideoFullscreen) ? 1 : 0;
}

BOOL DKVideoFullscreenOn(void) {
    return DKVideoFullscreenModeValue() > 0;
}

static BOOL DKDYYYImageLoaded(void) {
    static int state = -1;
    if (state >= 0) return state == 1;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        const char *leaf = name ? strrchr(name, '/') : NULL;
        leaf = leaf ? leaf + 1 : name;
        if (leaf && strcasestr(leaf, "DYYY")) {
            state = 1;
            return YES;
        }
    }
    state = 0;
    return NO;
}

BOOL DKVideoGeometryOwnedByDYYY(void) {
    return DKDYYYImageLoaded()
        && [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableFullScreen"];
}


BOOL DKIsSearchDetailView(UIView *view) {
    if (!view) return NO;
    BOOL inDetail = NO;
    for (UIView *ancestor = view; ancestor; ancestor = ancestor.superview) {
        if ([ancestor.nextResponder isKindOfClass:NSClassFromString(@"AWEAwemeDetailTableViewController")]) {
            inDetail = YES;
            break;
        }
    }
    if (!inDetail) return NO;
    Class searchClass = NSClassFromString(@"AWESearchViewController");
    for (UIResponder *responder = view.nextResponder; responder; responder = responder.nextResponder) {
        if (![responder isKindOfClass:UIViewController.class]) continue;
        UIViewController *controller = (UIViewController *)responder;
        for (UIViewController *entry in controller.navigationController.viewControllers) {
            if ([entry isKindOfClass:searchClass]) return YES;
        }
    }
    return NO;
}

BOOL DKVideoGeometryOn(void) {
    return DKVideoFullscreenOn();
}

BOOL DKCommentFreezeOn(void) {
    return DKGlassOSAvailable() && DKPrefBool(DKKeyCommentGlass);
}

void DKVideoFullscreenRegisterRestore(void (*restore)(void)) {
    if (!restore || gRestoreCount >= sizeof(gRestoreHooks) / sizeof(gRestoreHooks[0])) return;
    gRestoreHooks[gRestoreCount++] = restore;
}

#pragma mark - 类缓存

static Class DKMergeClass(void) {
    static Class cls;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cls = NSClassFromString(@"AWEDPlayerViewController_Merge"); });
    return cls;
}

static Class DKPlayInteractionClass(void) {
    static Class cls;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cls = NSClassFromString(@"AWEPlayInteractionViewController"); });
    return cls;
}

#pragma mark - 视频容器的钉位目标

// 拉满整屏只对比例达标的竖屏视频做：图文、横屏、低比例竖屏拉满会 aspect-fill 过裁。
// 它们只需保持容器自然满幅，背景延伸到底栏交给 DKVideoPageChrome.xm 的 DKSyncBackdrop。
static BOOL DKMergeCanCoverScreen(AWEDPlayerViewController_Merge *merge) {
    if (![merge isKindOfClass:DKMergeClass()]) return NO;

    AWEAwemeModel *model = merge.model;
    if (model.awemeType == kDKAwemeTypeImage) return NO;
    if (merge.hasInlandscape) return NO;
    if ([merge respondsToSelector:@selector(isInLandscapeFeedStatus)]
        && [merge isInLandscapeFeedStatus]) {
        return NO;
    }

    AWEVideoModel *video = model.video;
    double width = video.width.doubleValue;
    double height = video.height.doubleValue;
    return width <= 0.0
        || height <= 0.0
        || (height / width) >= kDKFullscreenMinAspect;
}

// 视频容器的唯一几何规则：
//   · 视频全屏 + 比例达标 → 钉到 Cell 满高，画面覆盖物理屏幕（好友聊天页比容器还高一个底栏）；
//   · 其余情况           → 钉到容器自然满幅，也就是「不许被评论区缩放平移」。
//
// 第二条对横屏同样成立：抖音展开评论区时直接改 frame 把横屏缩小上移（实测
// {{47.79,−128.07},{332.43,654.76}}，bounds 与 frame 同尺寸、不是 transform），
// 智能背景色的承载层会跟着漂移。拉满与冻结是两件事，只有拉满需要看比例。
//
// 「要不要拉满」是 model 的函数，而 model 可能晚于 frame 写入才绑定；
// 补算在 DKVideoPageChrome.xm 的 willDisplay 里。
CGRect DKVideoContainerTargetFrame(UIView *view) {
    if (!DKVideoGeometryOn() && !DKCommentFreezeOn()) return CGRectNull;

    // 作用域只到主窗口：浮层窗口（画中画、横屏播放器）自带一整套 Merge / PlayVideo 层级，
    // 与 feed 里那套长得一样，钉成满幅会把小窗撑成盖住整页的全屏播放器。
    // 取不到 window（布局早期还没入树）时按在作用域内处理，与其余判据一致。
    //
    // 这条守卫**挡不住入窗前的那一次写入**：抖音在把播放器加进 PiP 窗口之前就写好 frame，
    // 那一刻 window 为 nil，写完之后也不会再写第二次（beta13 实测两份导出一对一错）。
    // 评论面板那条画中画因此改为直接关掉功能本身，见 Comment/DKCommentFullBackdrop.xm。
    UIWindow *window = view.window;
    if (window && window.windowLevel != UIWindowLevelNormal) return CGRectNull;

    UIView *parent = view.superview;
    CGFloat width = CGRectGetWidth(parent.bounds);
    CGFloat height = CGRectGetHeight(parent.bounds);
    if (width <= 0.0 || height <= 0.0) return CGRectNull;

    if (DKVideoFullscreenOn() && DKIsSearchDetailView(view)) {
        CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
        if (screenHeight > height) height = screenHeight;
        return CGRectMake(0.0, 0.0, width, height);
    }

    if (DKVideoGeometryOn()
        && DKMergeCanCoverScreen((AWEDPlayerViewController_Merge *)view.nextResponder)) {
        CGFloat full = DKFullCellHeight(view);
        if (full > height) height = full;
    }

    return CGRectMake(0.0, 0.0, width, height);
}

BOOL DKRectsClose(CGRect lhs, CGRect rhs) {
    return fabs(CGRectGetMinX(lhs) - CGRectGetMinX(rhs)) <= kDKGeometryTolerance
        && fabs(CGRectGetMinY(lhs) - CGRectGetMinY(rhs)) <= kDKGeometryTolerance
        && fabs(CGRectGetWidth(lhs) - CGRectGetWidth(rhs)) <= kDKGeometryTolerance
        && fabs(CGRectGetHeight(lhs) - CGRectGetHeight(rhs)) <= kDKGeometryTolerance;
}

// 钉位目标恒在原点，所以来意的 origin 不在原点就是有人要把视频整体挪走——评论区缩放是唯一来源。
// 与「容器还没铺满」那种写入区分开：评论面板开合、拖拽、缩放进出全屏时视频不动，就是这一条在扛，
// 39.8.0 实测每页 27~36 次。
static NSUInteger gMoveWrites = 0;

NSString *DKVideoContainerMoveStats(void) {
    return [NSString stringWithFormat:@"挪动写入被拦=%lu", (unsigned long)gMoveWrites];
}

// 这条钩子挂在全局 UIView 上，抖音每一次 frame 写入都会经过，守卫必须极便宜：
// 只取一次 nextResponder、最多两次类型判断，不是目标立刻放行。
// 视频表自己的撑高不走这里：它有类可挂，直接在 DKVideoFeedTable.xm 里拦。
static CGRect DKAdjustFrame(UIView *view, CGRect frame) {
    UIResponder *owner = view.nextResponder;
    if (!owner) return CGRectNull;

    if ([owner isKindOfClass:DKMergeClass()]) {
        CGRect target = DKVideoContainerTargetFrame(view);
        if (CGRectIsNull(target) || DKRectsClose(frame, target)) return CGRectNull;
        if (fabs(CGRectGetMinX(frame)) > kDKGeometryTolerance
            || fabs(CGRectGetMinY(frame)) > kDKGeometryTolerance) {
            gMoveWrites++;
        }
        return target;
    }
    if ([owner isKindOfClass:DKPlayInteractionClass()]) {
        return DKFeedHUDAdjustFrame(view, frame);
    }
    return CGRectNull;
}

#pragma mark - 全局 UIView 钩子

%hook UIView

- (void)setFrame:(CGRect)frame {
    // 两个几何功能都关闭时，这是全 App 最热的 UIKit 路径；直接放行，
    // 不取 nextResponder、不做 runtime 类判断。
    if (!DKVideoFullscreenOn() && !DKCommentFreezeOn()) {
        %orig;
        return;
    }
    CGRect adjusted = DKAdjustFrame(self, frame);
    if (CGRectIsNull(adjusted)) {
        %orig;
        return;
    }
    %orig(adjusted);
}

%end

#pragma mark - 设置项注册

%ctor {
    DKSettingsRegisterItem(@"视频", ^AWESettingItemModel *{
        if (![NSUserDefaults.standardUserDefaults objectForKey:DKKeyVideoFullscreenMode]) {
            NSInteger legacy = DKPrefBool(DKKeyVideoFullscreen) ? 1 : 1;
            [NSUserDefaults.standardUserDefaults setInteger:legacy forKey:DKKeyVideoFullscreenMode];
        }
        return DKMakeChoice(
            DKKeyVideoFullscreenMode,
            @"视频全屏模式",
            @[ @"关闭全屏 (原版默认)", @"全屏模式 1：满屏填充 (画面无黑边)", @"全屏模式 2：原比例无损 (画面零裁切)" ]
        );
    });
    DKSettingsRegisterItem(@"视频", ^AWESettingItemModel *{
        if (![NSUserDefaults.standardUserDefaults objectForKey:DKKeyReadabilityTarget]) {
            [NSUserDefaults.standardUserDefaults setInteger:2 forKey:DKKeyReadabilityTarget];
        }
        return DKMakeChoice(
            DKKeyReadabilityTarget,
            @"可读性增强对象",
            @[ @"仅视频描述文案", @"仅作者用户名(@)", @"全量增强(文案+用户名)" ]
        );
    });
    DKSettingsRegisterItem(@"视频", ^AWESettingItemModel *{
        if (![NSUserDefaults.standardUserDefaults objectForKey:DKKeyVideoCaptionContrast]) {
            [NSUserDefaults.standardUserDefaults setInteger:2 forKey:DKKeyVideoCaptionContrast];
        }
        return DKMakeChoice(
            DKKeyVideoCaptionContrast,
            @"文字对比度强度",
            @[ @"关闭", @"轻", @"标准", @"强" ]
        );
    });
    DKSettingsRegisterItem(@"视频", ^AWESettingItemModel *{
        return DKMakeSwitch(DKKeyMetalSharpeningEnabled, @"Metal 画面边缘锐化", @"开启 GPU 边缘动态锐化，显著提升低清/压缩视频清晰度");
    });
    DKSettingsRegisterItem(@"视频", ^AWESettingItemModel *{
        return DKMakeSwitch(DKKeyMetalVibrantColorEnabled, @"Metal 画面色彩增强", @"开启智能画质对比度与饱和度调谐，让视频呈现 HDR 通透感");
    });
    DKSettingsRegisterItem(@"视频", ^AWESettingItemModel *{
        return DKMakeSwitch(DKKeyZenFeedUIEnabled, @"极简控件模式 (极简清爽 UI)", @"隐去视频播放界面冗余挂件与无用浮层，仅保留核心要素，大幅提升画质清爽度");
    });
    DKSettingsRegisterItem(@"视频", ^AWESettingItemModel *{
        return DKMakeSwitch(DKKeyKeepProgressInCleanMode, @"清屏模式保留视频进度条", @"两指捏合切清屏或全屏放大时，保留底栏完整/可拖拽视频进度条，清爽看剧两不误");
    });
    DKSettingsRegisterItem(@"高级与播放器", ^AWESettingItemModel *{
        return DKMakeSwitch(DKKeyForceNativeAVPlayer, @"iOS 原生 AVPlayer 引擎", @"(实验性) 强切 Apple 原生 AVPlayer 解码，极低功耗，原生锁屏/画中画咬合");
    });
    DKSettingsRegisterItem(@"高级与播放器", ^AWESettingItemModel *{
        return DKMakeSwitch(DKKeyOptimizeRenderPipeline, @"Metal 渲染管道极简优化", @"剥离 Metal 视口重叠的 22 层冗余渐变遮罩，大幅降低 GPU 混合渲染开销");
    });
}
