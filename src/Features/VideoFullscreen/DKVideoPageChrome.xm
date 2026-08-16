//
//  DKVideoPageChrome.xm
//  视频页、图文页与直播预览的页面级修饰：背景色延伸至底栏、评论态顶部黑遮罩、底部压暗渐变拉伸、
//  图文缩放抑制、直播预览 HUD 抬升，以及视频容器几何的两处重钉。
//  进度条底边的黑垫层见 DKProgressUnderline。
//
//  几何本身（容器该多大）统一由 DKVideoGeometry.xm 定义与拦截，本文件只负责在写入被放行
//  之后把它按回去，并处理钉住之后暴露出来的那些页面元素。
//

#import "DouyinHeaders.h"
#import "DKVideoFullscreen.h"
#import "DKVideoFeedTable.h"
#import "DKKeys.h"
#import "DKUtils.h"
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <math.h>

// 结构签名的统一容差：覆盖 @3x 像素对齐与进度条收放时的亚像素漂移。
static const CGFloat kDKSignatureTolerance = 0.5;

static Class DKMergeClass(void) {
    static Class cls;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cls = NSClassFromString(@"AWEDPlayerViewController_Merge");
    });
    return cls;
}

#pragma mark - 全屏目标判定

static AWEDPlayerViewController_Merge *DKMergeForView(UIView *view) {
    Class mergeCls = DKMergeClass();
    if (!mergeCls) return nil;

    UIResponder *responder = view.nextResponder;
    for (NSUInteger i = 0; responder && i < 40; i++) {
        if ([responder isKindOfClass:mergeCls]) {
            return (AWEDPlayerViewController_Merge *)responder;
        }
        responder = responder.nextResponder;
    }
    return nil;
}

// 底部渐变要不要拉伸，取决于这条视频的容器有没有被钉得比自然高度更高——只有详情页那几页
// 会出现这种情况（首页/朋友页靠撑高 feed 表，渐变本来就在满高容器里）。
static BOOL DKMergeIsStretchedTarget(AWEDPlayerViewController_Merge *merge) {
    if (!merge || !merge.isViewLoaded) return NO;

    UIView *view = merge.view;
    CGRect target = DKVideoContainerTargetFrame(view);
    if (CGRectIsNull(target) || !view.superview) return NO;
    return CGRectGetHeight(target)
        > CGRectGetHeight(view.superview.bounds) + kDKSignatureTolerance;
}

#pragma mark - 视频容器重钉

// 两条重钉路径各补一个缺口，都不是冗余：
//   · willDisplay —— 钉位目标里「要不要拉满」是 model 的函数（图文/横屏/宽高比）。抖音复用 cell 时
//     可能先写 frame 后绑 model，写入那一刻算出的目标偏小；写完之后 frame 已等于抖音想要的值、
//     不会再写第二次，而预备 cell 是 hidden 的、不脏也不再布局，滑过去就是不全屏。
//     willDisplay 是 model 与视图层级都已就位、且一定早于用户看见的那一刻。
//   · viewDidLayoutSubviews —— 容器还没进 Cell 时算不出满高，那几次写入只能放行。
//     好友聊天页实测同一页两条 cell，一条 926 一条留在 843，就是这个缺口补上的。
// 补正后 frame 与目标一致，下一轮不再写，不会成环。
static NSUInteger gPinWillDisplay = 0;
static NSUInteger gPinLayout = 0;

NSString *DKVideoContainerPinStats(void) {
    return [NSString stringWithFormat:@"willDisplay 重钉=%lu  布局后兜底=%lu",
            (unsigned long)gPinWillDisplay, (unsigned long)gPinLayout];
}

static BOOL DKPinMergeToTarget(UIViewController *merge) {
    UIView *view = merge.viewIfLoaded;
    if (!view) return NO;

    CGRect target = DKVideoContainerTargetFrame(view);
    if (CGRectIsNull(target) || DKRectsClose(view.frame, target)) return NO;

    view.frame = target;
    return YES;
}

%hook AWEDPlayerViewController_Merge

- (void)willDisplay {
    %orig;
    if (DKPinMergeToTarget(self)) gPinWillDisplay++;
}

- (void)viewDidLayoutSubviews {
    %orig;
    if (DKPinMergeToTarget(self)) gPinLayout++;
    if (DKVideoFullscreenOn()) {
        UIView *contentView = [self respondsToSelector:@selector(contentView)] ? (UIView *)[self performSelector:@selector(contentView)] : self.viewIfLoaded;
        if (contentView && contentView.superview) {
            CGFloat parentHeight = contentView.superview.frame.size.height;
            if (parentHeight > 0 && fabs(contentView.frame.size.height - parentHeight) > 0.5) {
                CGRect frame = contentView.frame;
                frame.size.height = parentHeight;
                contentView.frame = frame;
            }
        }
    }
}


// 抖音展开评论区时靠这里把视频缩成小窗。两个开关任一开着，容器都由我们钉着，
// 缩放只会让玻璃背后只剩黑底、并留下顶部那条黑遮罩，一律压掉。
- (void)videoDidShrink {
    if (!DKVideoFullscreenOn() && !DKCommentFreezeOn()) {
        %orig;
        return;
    }

    UIView *gradient = self.gradientBackgroundView;
    if (gradient && gradient.alpha < 1.0) {
        gradient.alpha = 1.0;
    }
}

%end

#pragma mark - 背景延伸至底栏

static char kDKBackdropAppliedKey;    // 挂内容控制器：是否接管过
static char kDKCellBackdropKey;       // 挂承载视图：原背景色

// 内容下方那块空区由哪一层兜住，各页不同（好友页是 Cell contentView，搜索页是铺满且不透明的
// CellVC.view）。故动态求：从内容根往上，第一个高度超过它底边的祖先才是会露出来的那层。
static UIView *DKBackdropCanvas(UIView *anchor) {
    UIView *contentView = DKCellContentView(anchor);
    if (!contentView) return nil;

    for (UIView *ancestor = anchor.superview; ancestor; ancestor = ancestor.superview) {
        CGRect rect = [anchor convertRect:anchor.bounds toView:ancestor];
        if (CGRectGetHeight(ancestor.bounds)
            > CGRectGetMaxY(rect) + kDKSignatureTolerance) {
            return ancestor;
        }
        if (ancestor == contentView) break;
    }
    return nil;
}

// 承载层会随页面/布局变化，按标记回收，不假设它是哪一个。
static void DKRestoreBackdrop(UIView *anchor, UIView *except) {
    UIView *ancestor = anchor.superview;
    for (NSUInteger i = 0; ancestor && i < 12; i++, ancestor = ancestor.superview) {
        if (ancestor == except) continue;

        id baseline = objc_getAssociatedObject(ancestor, &kDKCellBackdropKey);
        if (!baseline) continue;

        ancestor.backgroundColor =
            baseline == [NSNull null] ? nil : (UIColor *)baseline;
        objc_setAssociatedObject(
            ancestor,
            &kDKCellBackdropKey,
            nil,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );
    }
}

// 其他比例视频：把 playerBackgroundView 的色涂到 anchor 下方会露出来的祖先上。
// owner 记「接管过没有」；color 为 nil 表示本条不需要延伸。图文不走这里——它钉的是
// AWEKnowledgeGradientView 自身高度（见下方），不取样另涂。
static void DKSyncBackdrop(id owner, UIView *anchor, UIColor *color) {
    BOOL applied = objc_getAssociatedObject(owner, &kDKBackdropAppliedKey) != nil;
    // 绝大多数内容没有原生背景，这里直接退出，不做任何链式遍历。
    if (!anchor || (!color && !applied)) return;

    UIView *canvas = (color && DKVideoFullscreenOn()) ? DKBackdropCanvas(anchor) : nil;

    DKRestoreBackdrop(anchor, canvas);
    if (!canvas) {
        objc_setAssociatedObject(owner, &kDKBackdropAppliedKey, nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    if (!objc_getAssociatedObject(canvas, &kDKCellBackdropKey)) {
        objc_setAssociatedObject(canvas, &kDKCellBackdropKey,
                                 canvas.backgroundColor ?: (id)[NSNull null],
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (![canvas.backgroundColor isEqual:color]) {
        canvas.backgroundColor = color;
    }
    objc_setAssociatedObject(owner, &kDKBackdropAppliedKey, @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// 抖音把横屏智能背景色画在 playerBackgroundView 上；该色在首帧渲染出图后才算出来，
// 因此同步点必须是抖音自己落色的时刻，而不是 setModel:/setFrame: 这类首帧之前的入口。
// 仅当背景层确实挂在视图树上并可见时才算「抖音画了背景」，避免跟随已摘除的残留层。
static UIColor *DKPlayerBackdropColor(AWEPlayVideoViewController *controller) {
    UIView *backdrop = controller.playerBackgroundView;
    return (backdrop.superview && !backdrop.hidden) ? backdrop.backgroundColor : nil;
}

static Class DKRichContentContainerClass(void) {
    static Class cls;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cls = NSClassFromString(@"RichContentContainerViewController");
    });
    return cls;
}

// 图文 cell 内仍嵌着一套 Merge/PlayVideo（alpha=0）。它与 RichContent 共用祖先链；
// 若让嵌套播放器继续 DKSyncBackdrop，会用黑底或 restore 把图文渐变末色清掉，
// 表现就是「偶发」底栏与图文背景不统一（beta5 导出：同页 contentView 有时透明有时已涂色）。
static BOOL DKIsUnderRichContent(UIViewController *controller) {
    Class richCls = DKRichContentContainerClass();
    if (!richCls) return NO;
    for (NSUInteger i = 0; controller && i < 12; i++) {
        if ([controller isKindOfClass:richCls]) return YES;
        controller = controller.parentViewController;
    }
    return NO;
}

%hook AWEPlayVideoViewController

- (void)setPlayerBackgroundView:(UIView *)backgroundView {
    %orig;
    if (DKIsUnderRichContent(self)) return;
    DKSyncBackdrop(self, self.viewIfLoaded, DKPlayerBackdropColor(self));
}

- (void)viewDidLayoutSubviews {
    %orig;
    if (DKIsUnderRichContent(self)) return;
    DKSyncBackdrop(self, self.viewIfLoaded, DKPlayerBackdropColor(self));

    if (DKVideoFullscreenModeValue() == 2) {
        UIView *playerView = [self respondsToSelector:@selector(playerView)] ? (UIView *)[self performSelector:@selector(playerView)] : nil;
        if (playerView) {
            if ([playerView.layer respondsToSelector:@selector(setVideoGravity:)]) {
                [(id)playerView.layer setVideoGravity:AVLayerVideoGravityResizeAspect];
            }
            for (CALayer *sub in playerView.layer.sublayers) {
                if ([sub respondsToSelector:@selector(setVideoGravity:)]) {
                    [(id)sub setVideoGravity:AVLayerVideoGravityResizeAspect];
                }
            }
        }
    }
}

%end

static BOOL DKViewIsInsideClass(UIView *view, NSString *className) {
    Class cls = NSClassFromString(className);
    if (!cls) return NO;
    for (UIView *ancestor = view; ancestor; ancestor = ancestor.superview) {
        if ([ancestor isKindOfClass:cls]) return YES;
    }
    return NO;
}

#pragma mark - 图文

static NSHashTable<UIView *> *gDKManagedVisualViews;
static char kDKRichClipKey;
static char kDKKnowledgeTransformKey;
static char kDKRichGradientTransformKey;
static char kDKVideoGradientTransformKey;
static char kDKCaptionGradientColorsKey;
static char kDKCaptionGradientLocationsKey;
static char kDKCaptionGradientLevelKey;
static char kDKCaptionShadowOpacityKey;
static char kDKCaptionShadowRadiusKey;
static char kDKCaptionShadowOffsetKey;
static char kDKCaptionShadowColorKey;
static char kDKSearchChromeFrameKey;
static char kDKSearchChromeAppliedFrameKey;
static char kDKLiveChromeTransformKey;

// center/bounds/anchorPoint 不受 transform 影响，可据此还原应用 transform 前的几何。
static CGRect DKIdentityFrameInSuperview(UIView *view) {
    CGFloat width = CGRectGetWidth(view.bounds);
    CGFloat height = CGRectGetHeight(view.bounds);
    CGFloat minX = view.center.x - width * view.layer.anchorPoint.x;
    CGFloat minY = view.center.y - height * view.layer.anchorPoint.y;
    return CGRectMake(minX, minY, width, height);
}

// 只接管原本没有 transform 的目标；首次修改时保存原值，恢复时不影响其他功能的状态。
static BOOL DKApplyVerticalStretch(
    UIView *view,
    const void *baselineKey,
    CGFloat top,
    CGFloat targetBottom
) {
    if (!view) return NO;

    CGFloat height = CGRectGetHeight(view.bounds);
    if (height <= 0.0 || targetBottom <= top + height + kDKSignatureTolerance) {
        return NO;
    }

    CGFloat scaleY = (targetBottom - top) / height;
    if (scaleY <= 1.0 + 1e-4) return NO;

    NSValue *baseline = objc_getAssociatedObject(view, baselineKey);
    if (!baseline) {
        if (!CGAffineTransformIsIdentity(view.transform)) return NO;
        baseline = [NSValue valueWithCGAffineTransform:view.transform];
        objc_setAssociatedObject(view, baselineKey, baseline,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    CGAffineTransform transform = CGAffineTransformMake(
        1.0, 0.0, 0.0, scaleY, 0.0, (height / 2.0) * (scaleY - 1.0));
    if (!CGAffineTransformEqualToTransform(view.transform, transform)) {
        view.transform = transform;
    }
    return YES;
}

// 纵向平移，用于把被撑高顶下去的 chrome 抬回原位。与上面的拉伸同一套接管规则：
// 只接管原本没有 transform 的目标（抖音自己在动它就让开），首次接管时存下原值。
static BOOL DKApplyVerticalLift(UIView *view, const void *baselineKey, CGFloat lift) {
    if (!view || lift <= kDKSignatureTolerance) return NO;

    NSValue *baseline = objc_getAssociatedObject(view, baselineKey);
    if (!baseline) {
        if (!CGAffineTransformIsIdentity(view.transform)) return NO;
        baseline = [NSValue valueWithCGAffineTransform:view.transform];
        objc_setAssociatedObject(view, baselineKey, baseline,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    CGAffineTransform transform = CGAffineTransformMakeTranslation(0.0, -lift);
    if (!CGAffineTransformEqualToTransform(view.transform, transform)) {
        view.transform = transform;
    }
    return YES;
}

static void DKRestoreTransformBaseline(UIView *view, const void *baselineKey) {
    NSValue *baseline = objc_getAssociatedObject(view, baselineKey);
    if (!baseline) return;

    view.transform = baseline.CGAffineTransformValue;
    objc_setAssociatedObject(view, baselineKey, nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// 图文向 Cell 底部溢出时，只解除真实阻挡它的裁剪层；原本不裁剪的视图不接管。
static void DKAllowRichOverflow(UIView *view) {
    if (!view) return;

    if (!objc_getAssociatedObject(view, &kDKRichClipKey)) {
        if (!view.clipsToBounds) return;
        objc_setAssociatedObject(view, &kDKRichClipKey, @YES,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [gDKManagedVisualViews addObject:view];
    }
    if (view.clipsToBounds) view.clipsToBounds = NO;
}

static void DKRestoreRichOverflow(UIView *view) {
    if (!objc_getAssociatedObject(view, &kDKRichClipKey)) return;

    view.clipsToBounds = YES;
    objc_setAssociatedObject(view, &kDKRichClipKey, nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static Class DKKnowledgeGradientClass(void) {
    static Class cls;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cls = NSClassFromString(@"AWEKnowledgeGradientView");
    });
    return cls;
}

// 图文的可见背景是列表控制器下的这一层渐变，与图片 / LivePhoto 等内容类型无关（它是整页的
// 背景层，不是单个 cell 的）。容器自己的 richBackgroundColor 实测恒为不透明黑——那正是被渐变
// 盖住的那块黑底，拿它去延伸等于把黑涂到黑上，所以这里不留那条回退。
// CAGradientLayer.colors 恒为 CGColorRef，末色即容器底边处的颜色。供探针读取。
UIColor *DKRichBackdropColor(UIViewController *container) {
    Class gradientCls = DKKnowledgeGradientClass();
    UIView *listView =
        ((RichContentContainerViewController *)container).contentListViewController.viewIfLoaded;
    if (!gradientCls || !listView) return nil;

    for (UIView *subview in listView.subviews) {
        if (subview.hidden || ![subview isKindOfClass:gradientCls]) continue;

        CALayer *layer = subview.layer;
        if (![layer isKindOfClass:CAGradientLayer.class]) return nil;

        id last = ((CAGradientLayer *)layer).colors.lastObject;
        return last ? [UIColor colorWithCGColor:(__bridge CGColorRef)last] : nil;
    }
    return nil;
}

// 图文底色层是 AWEKnowledgeGradientView。不能改它的 frame：父布局每轮写回 843，
// 我们在 setFrame:/layoutSubviews 里撑到 926 会与父互相追赶，主线程卡死 →
// 看门狗 0x8BADF00D（beta6 崩溃：EXC_CRASH SIGKILL / FRONTBOARD 8BADF00D，
// 栈在 layoutSublayers / layoutBelowIfNeeded / UITableView 建 cell）。
//
// 与同文件 AWEGradientView 压暗拉伸同一手段：只叠 transform，不触发布局环；
// 容器 clipsToBounds 放开后，渐变视觉上铺进 Cell 满高（好友页 843→926）。
static void DKSyncRichClips(UIView *view) {
    if (!view) return;

    CGFloat full = DKVideoFullscreenOn() ? DKFullCellHeight(view) : 0.0;
    if (full > CGRectGetHeight(view.bounds) + kDKSignatureTolerance) {
        DKAllowRichOverflow(view);
        return;
    }

    DKRestoreRichOverflow(view);
}

static void DKSyncKnowledgeGradientStretch(UIView *gradient) {
    if (!gradient) return;

    CGFloat height = CGRectGetHeight(gradient.bounds);
    CGFloat full = DKVideoFullscreenOn() ? DKFullCellHeight(gradient) : 0.0;

    if (height > 0.0 && full > height + kDKSignatureTolerance
        && DKApplyVerticalStretch(
            gradient,
            &kDKKnowledgeTransformKey,
            0.0,
            full
        )) {
        [gDKManagedVisualViews addObject:gradient];
        return;
    }

    DKRestoreTransformBaseline(gradient, &kDKKnowledgeTransformKey);
}

// 图文的顶层容器，三种图文列表实现都挂在它下面。
//
// · 缩放：updateShrinkState: 是图文版的 videoDidShrink。
// · 背景：放开 clips，渐变用 transform 视觉延伸（见 AWEKnowledgeGradientView）。
%hook RichContentContainerViewController

- (void)updateShrinkState:(BOOL)shrink insets:(UIEdgeInsets)insets animated:(BOOL)animated {
    // 抑制时一律不调 %orig：class-dump 把 insets 折叠成 (struct)，真实类型只能按参数名推断，
    // 不重新编组它就不依赖这个推断；放行走裸 %orig，Logos 原样透传实参。
    if (shrink && (DKVideoFullscreenOn() || DKCommentFreezeOn())
        && !DKIsSearchDetailView(self.viewIfLoaded)) return;
    %orig;
}

- (void)updateShrinkState:(BOOL)shrink
                   insets:(UIEdgeInsets)insets
                 animated:(BOOL)animated
        animationDuration:(double)duration {
    if (shrink && (DKVideoFullscreenOn() || DKCommentFreezeOn())
        && !DKIsSearchDetailView(self.viewIfLoaded)) return;
    %orig;
}

- (void)viewDidLayoutSubviews {
    %orig;
    // 不改 RichContent 根视图 frame：搜索详情滑动复用时宿主会持续写回 799pt，
    // 与强制 874pt 形成布局风暴。底部黑条仅由渐变 overflow 延伸覆盖。
    DKSyncRichClips(self.viewIfLoaded);
}

%end

%hook AWEKnowledgeGradientView

- (void)layoutSubviews {
    %orig;
    DKSyncKnowledgeGradientStretch(self);
}

%end

#pragma mark - 评论态 HUD 顶部遮罩

// 评论展开时抖音会在 HUD 顶部现场插入一条「安全区高 × 满宽」的纯黑遮罩，
// 它是「视频缩小」态的产物，被强钉满屏的视频顶上去就成了黑边。
static char kDKStatusBarCoverHiddenKey;

// 遮罩的高度是**窗口**安全区高，尺子也必须取窗口的：HUD 根视图在 table cell 里，它自己的安全区
// 随 cell 在滚动视图中的位置变化，滑到不覆盖窗口顶部安全区的位置就是 0，签名会整条失配。
CGFloat DKHUDStatusBarCoverHeight(UIView *hudView) {
    UIWindow *window = hudView.window;
    return window ? window.safeAreaInsets.top : hudView.safeAreaInsets.top;
}

static UIView *DKFindHUDStatusBarCover(UIView *hudView) {
    CGFloat safeTop = DKHUDStatusBarCoverHeight(hudView);
    CGFloat width = CGRectGetWidth(hudView.bounds);
    if (safeTop <= 1.0 || width <= 0.0) return nil;

    for (UIView *view in hudView.subviews) {
        if (object_getClass(view) != [UIView class]) continue;
        if (!view.opaque || view.hidden) continue;

        CGRect frame = view.frame;
        if (fabs(CGRectGetMinX(frame)) > 1.0
            || fabs(CGRectGetMinY(frame)) > 1.0
            || fabs(CGRectGetWidth(frame) - width) > 1.0
            || fabs(CGRectGetHeight(frame) - safeTop) > 2.0) {
            continue;
        }
        if (DKColorIsOpaqueBlack(view.backgroundColor)) return view;
    }
    return nil;
}

// 判据就是两个开关本身：这条遮罩只在评论展开时出现，而那一刻视频容器必被其中一个钉住，
// 遮罩就成了纯粹的黑边。额外要求「找得到 Merge 且比例达标」会让横屏永远留着黑边。
void DKHUDStatusBarCoverSync(UIViewController *interaction) {
    UIView *hudView = interaction.viewIfLoaded;
    if (!hudView) return;

    if (DKVideoFullscreenOn() || DKCommentFreezeOn()) {
        UIView *cover = DKFindHUDStatusBarCover(hudView);
        if (cover) {
            cover.hidden = YES;
            objc_setAssociatedObject(
                cover,
                &kDKStatusBarCoverHiddenKey,
                @YES,
                OBJC_ASSOCIATION_RETAIN_NONATOMIC
            );
        }
        return;
    }

    for (UIView *view in hudView.subviews) {
        if (!objc_getAssociatedObject(view, &kDKStatusBarCoverHiddenKey)) continue;
        view.hidden = NO;
        objc_setAssociatedObject(
            view,
            &kDKStatusBarCoverHiddenKey,
            nil,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );
    }
}

static BOOL DKNavigationCameFromSearch(UIViewController *controller) {
    Class searchClass = NSClassFromString(@"AWESearchViewController");
    for (UIViewController *entry in controller.navigationController.viewControllers) {
        if ([entry isKindOfClass:searchClass]) return YES;
    }
    return NO;
}

static BOOL DKIsAuthorDescriptionStack(UIView *view) {
    if (![view isKindOfClass:NSClassFromString(@"AWEElementStackView")]) return NO;
    for (UIView *sub in view.subviews) {
        NSString *clsName = NSStringFromClass([sub class]);
        if ([clsName containsString:@"Notice"] || [clsName containsString:@"Mix"] || [clsName containsString:@"Banner"]) {
            return NO;
        }
    }
    return YES;
}

static void DKSyncSearchDetailChrome(UIViewController *interaction) {
    UIView *hud = interaction.viewIfLoaded;
    Class stackClass = NSClassFromString(@"AWEElementStackView");
    if (!hud || !stackClass) return;

    BOOL active = DKVideoFullscreenOn()
        && DKViewIsInsideClass(hud, @"AWEAwemeDetailTableViewCell")
        && DKNavigationCameFromSearch(interaction);

    CGFloat safeBottom = hud.window ? hud.window.safeAreaInsets.bottom : 0.0;
    CGFloat targetBottom = CGRectGetHeight(hud.bounds) - safeBottom;

    for (UIView *view in hud.subviews) {
        if (!DKIsAuthorDescriptionStack(view)) continue;
        CGFloat width = CGRectGetWidth(view.bounds);
        CGFloat height = CGRectGetHeight(view.bounds);
        if (height < 40.0 || (width < 200.0 && width > 100.0)) continue;

        NSValue *stored = objc_getAssociatedObject(view, &kDKSearchChromeFrameKey);
        NSValue *lastApplied = objc_getAssociatedObject(view, &kDKSearchChromeAppliedFrameKey);
        if (!active) {
            if (stored) {
                view.frame = stored.CGRectValue;
                objc_setAssociatedObject(view, &kDKSearchChromeFrameKey, nil,
                                         OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                objc_setAssociatedObject(view, &kDKSearchChromeAppliedFrameKey, nil,
                                         OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            continue;
        }
        CGRect nativeFrame = stored ? stored.CGRectValue : view.frame;
        if (!stored || (lastApplied && !CGRectEqualToRect(view.frame, lastApplied.CGRectValue))) {
            nativeFrame = view.frame;
            objc_setAssociatedObject(view, &kDKSearchChromeFrameKey,
                                     [NSValue valueWithCGRect:nativeFrame],
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        CGFloat delta = targetBottom - CGRectGetMaxY(nativeFrame);
        if (delta <= kDKSignatureTolerance) continue;
        CGRect adjusted = nativeFrame;
        adjusted.origin.y += delta;
        objc_setAssociatedObject(view, &kDKSearchChromeAppliedFrameKey,
                                 [NSValue valueWithCGRect:adjusted],
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (!CGRectEqualToRect(view.frame, adjusted)) view.frame = adjusted;
    }
}

%hook AWEDPlayerFeedPlayerViewController

- (void)viewDidLayoutSubviews {
    %orig;
    if (DKVideoFullscreenOn()) {
        UIView *contentView = [self respondsToSelector:@selector(contentView)] ? (UIView *)[self performSelector:@selector(contentView)] : self.viewIfLoaded;

        if (contentView && contentView.superview) {
            CGFloat parentHeight = contentView.superview.frame.size.height;
            if (parentHeight > 0 && fabs(contentView.frame.size.height - parentHeight) > 0.5) {
                CGRect frame = contentView.frame;
                frame.size.height = parentHeight;
                contentView.frame = frame;
            }
        }
    }
}

%end

%hook AFDViewedBottomView

- (void)layoutSubviews {
    %orig;
    if (DKVideoFullscreenOn()) {
        self.backgroundColor = [UIColor clearColor];
        if ([self respondsToSelector:@selector(effectView)]) {
            UIView *ev = [self performSelector:@selector(effectView)];
            if (ev) ev.hidden = YES;
        }
    }
}

%end

%hook AWEIMFeedBottomQuickEmojiInputBar

- (void)layoutSubviews {
    %orig;
    if (DKVideoFullscreenOn()) {
        UIView *parentView = self.superview;
        while (parentView) {
            if ([NSStringFromClass([parentView class]) isEqualToString:@"UIView"]) {
                parentView.backgroundColor = [UIColor clearColor];
                parentView.layer.backgroundColor = [UIColor clearColor].CGColor;
                parentView.opaque = NO;
                break;
            }
            parentView = parentView.superview;
        }
    }
}

%end

// 参考 DYYY 全屏机制：作品页/详情页保持原生 HUD 容器高度，背景视频单独拉满，
static BOOL DKInteractionUsesFullHeight(UIViewController *interaction) {
    NSString *refer = nil;
    if ([interaction respondsToSelector:@selector(referString)]) {
        refer = [interaction performSelector:@selector(referString)];
    }
    // 仅在用户个人作品页（personal_homepage / others_homepage / user_post）预留 75pt 空间，
    // 以防止合集栏与防沉迷栏重叠；
    // 其余所有场景（经验视频 homepage_fresh/fresh/experience、群聊 chat、搜索 general_search、首页推荐等）一律满高 (874pt)，彻底解决文案偏高。
    if (refer && (
        [refer isEqualToString:@"personal_homepage"] ||
        [refer isEqualToString:@"others_homepage"] ||
        [refer isEqualToString:@"user_post"]
    ) && !DKNavigationCameFromSearch(interaction)) {
        return NO;
    }
    return YES;
}

// 完全对齐 DYYY 全屏判定逻辑：
//   · 经验视频、群聊视频、搜索视频与首页推荐拉满 (874pt)；
//   · 仅在用户个人主页作品页 (personal_homepage/others_homepage) 预留 75pt 保持原生 Stack 自动排版。
%hook AWEPlayInteractionViewController

- (void)viewDidLayoutSubviews {
    %orig;
    if (!DKIsSearchDetailView(self.viewIfLoaded)) {
        DKHUDStatusBarCoverSync(self);
        DKSyncSearchDetailChrome(self);
    }

    if (DKVideoGeometryOn() && DKViewIsInsideClass(self.viewIfLoaded, @"AWEAwemeDetailTableViewCell")) {
        UIView *view = self.viewIfLoaded;
        if (view && view.superview) {
            CGFloat superviewHeight = CGRectGetHeight(view.superview.bounds);
            if (superviewHeight > 700.0) {
                BOOL useFull = DKInteractionUsesFullHeight(self);
                CGFloat targetHeight = useFull ? superviewHeight : (superviewHeight - 75.0);
                if (fabs(CGRectGetHeight(view.frame) - targetHeight) > 0.5) {
                    CGRect frame = view.frame;
                    frame.size.height = targetHeight;
                    view.frame = frame;
                }
            }
        }
    }
}

%end


static NSInteger DKReadabilityTarget(void) {
    NSNumber *stored = [NSUserDefaults.standardUserDefaults objectForKey:DKKeyReadabilityTarget];
    NSInteger target = stored ? stored.integerValue : 2;
    return MAX(0, MIN(target, 2));
}

static NSInteger DKCaptionContrastLevel(void) {
    NSNumber *stored = [NSUserDefaults.standardUserDefaults objectForKey:DKKeyVideoCaptionContrast];
    NSInteger level = stored ? stored.integerValue : 2;
    return MAX(0, MIN(level, 3));
}

static void DKSyncCaptionShadow(UIView *caption) {
    CALayer *layer = caption.layer;
    if (!objc_getAssociatedObject(caption, &kDKCaptionShadowOpacityKey)) {
        objc_setAssociatedObject(caption, &kDKCaptionShadowOpacityKey, @(layer.shadowOpacity), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(caption, &kDKCaptionShadowRadiusKey, @(layer.shadowRadius), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(caption, &kDKCaptionShadowOffsetKey, [NSValue valueWithCGSize:layer.shadowOffset], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        id color = layer.shadowColor ? (__bridge id)layer.shadowColor : NSNull.null;
        objc_setAssociatedObject(caption, &kDKCaptionShadowColorKey, color, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    NSInteger level = DKCaptionContrastLevel();
    if (level == 0) {
        layer.shadowOpacity = [objc_getAssociatedObject(caption, &kDKCaptionShadowOpacityKey) floatValue];
        layer.shadowRadius = [objc_getAssociatedObject(caption, &kDKCaptionShadowRadiusKey) doubleValue];
        layer.shadowOffset = [objc_getAssociatedObject(caption, &kDKCaptionShadowOffsetKey) CGSizeValue];
        id color = objc_getAssociatedObject(caption, &kDKCaptionShadowColorKey);
        layer.shadowColor = color == NSNull.null ? nil : (__bridge CGColorRef)color;
        return;
    }
    CGFloat opacity = 0.35 + 0.15 * level;
    CGFloat radius = 1.0 + 0.5 * level;
    if (layer.shadowColor != UIColor.blackColor.CGColor) layer.shadowColor = UIColor.blackColor.CGColor;
    if (fabs(layer.shadowOpacity - opacity) > 0.01) layer.shadowOpacity = opacity;
    if (fabs(layer.shadowRadius - radius) > 0.01) layer.shadowRadius = radius;
    if (!CGSizeEqualToSize(layer.shadowOffset, CGSizeMake(0.0, 1.0))) {
        layer.shadowOffset = CGSizeMake(0.0, 1.0);
    }
}

%hook AWEPlayInteractionDescriptionLabel

- (void)layoutSubviews {
    %orig;
    NSInteger target = DKReadabilityTarget();
    if (target == 0 || target == 2) {
        DKSyncCaptionShadow((UIView *)self);
    }
}

%end

%hook AWEPlayInteractionUserNameLabel

- (void)layoutSubviews {
    %orig;
    NSInteger target = DKReadabilityTarget();
    if (target == 1 || target == 2) {
        DKSyncCaptionShadow((UIView *)self);
    }
}

%end

%hook AWEAwemeAuthorContainerView

- (void)layoutSubviews {
    %orig;
    NSInteger target = DKReadabilityTarget();
    if (target == 1 || target == 2) {
        DKSyncCaptionShadow((UIView *)self);
    }
}

%end

static void DKEnhanceVideoBottomGradient(UIView *view) {
    if (![view.layer isKindOfClass:CAGradientLayer.class]) return;
    if (CGRectGetMinY(view.frame) <= 1.0 || CGRectGetHeight(view.bounds) < 150.0) return;
    CAGradientLayer *gradient = (CAGradientLayer *)view.layer;
    if (!objc_getAssociatedObject(view, &kDKCaptionGradientColorsKey)) {
        objc_setAssociatedObject(view, &kDKCaptionGradientColorsKey, gradient.colors ?: @[], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(view, &kDKCaptionGradientLocationsKey, gradient.locations ?: @[], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    NSInteger level = DKCaptionContrastLevel();
    NSNumber *applied = objc_getAssociatedObject(view, &kDKCaptionGradientLevelKey);
    if (applied && applied.integerValue == level) return;
    objc_setAssociatedObject(view, &kDKCaptionGradientLevelKey, @(level), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (level == 0) {
        gradient.colors = objc_getAssociatedObject(view, &kDKCaptionGradientColorsKey);
        gradient.locations = objc_getAssociatedObject(view, &kDKCaptionGradientLocationsKey);
        return;
    }
    CGFloat middle = 0.16 + 0.06 * level;
    CGFloat bottom = 0.48 + 0.10 * level;
    gradient.colors = @[
        (id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:middle].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:bottom].CGColor
    ];
    gradient.locations = @[ @0.0, @0.52, @1.0 ];
}

#pragma mark - 底部压暗渐变

// 只叠 transform，不改 frame（防布局环 / 0x8BADF00D）。
//
// 视频与图文的渐变同步点不同：视频在自身 layout 中层级已经完整；图文必须等横滑 collection
// 完成布局、可见 Cell 进入详情页 Cell 后再处理。两条路径分别持有自己的 transform 标记。

%hook AWEGradientView

- (void)layoutSubviews {
    %orig;

    AWEDPlayerViewController_Merge *merge = DKMergeForView(self);
    if (merge) DKEnhanceVideoBottomGradient(self);

    // ① 视频：Merge 被钉得比父视图高时，容器内非贴底的压暗跟着撑满（旧逻辑，保留）。
    if (DKMergeIsStretchedTarget(merge)) {
        UIView *container = self.superview;
        CGFloat height = CGRectGetHeight(self.bounds);
        if (container && height > 0.0) {
            CGFloat top = self.center.y - height / 2.0;
            CGFloat containerHeight = CGRectGetHeight(container.bounds);
            if (top > 1.0 && top + height < containerHeight - 1.0) {
                if (DKApplyVerticalStretch(
                    self,
                    &kDKVideoGradientTransformKey,
                    top,
                    containerHeight
                )) {
                    [gDKManagedVisualViews addObject:self];
                    return;
                }
            }
        }
    }

    DKRestoreTransformBaseline(self, &kDKVideoGradientTransformKey);
}

%end

static Class DKGradientClass(void) {
    static Class cls;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cls = NSClassFromString(@"AWEGradientView");
    });
    return cls;
}

// 图文贴底压暗的结构签名：全宽、贴父底、顶边不在父顶。尺寸随设备和内容布局动态变化。
static BOOL DKIsRichBottomGradient(UIView *view) {
    Class gradientCls = DKGradientClass();
    UIView *parent = view.superview;
    if (!gradientCls || !parent || view.hidden || view.alpha <= 0.01
        || ![view isKindOfClass:gradientCls]) {
        return NO;
    }

    CGFloat parentWidth = CGRectGetWidth(parent.bounds);
    CGFloat parentHeight = CGRectGetHeight(parent.bounds);
    if (parentWidth <= 0.0 || parentHeight <= 0.0) return NO;

    CGRect frame = DKIdentityFrameInSuperview(view);
    CGFloat tolerance = MAX(kDKSignatureTolerance, 1.0);
    return fabs(CGRectGetMinX(frame)) <= tolerance
        && fabs(CGRectGetWidth(frame) - parentWidth) <= tolerance
        && fabs(CGRectGetMaxY(frame) - parentHeight) <= tolerance
        && CGRectGetMinY(frame) > tolerance;
}

static void DKCollectRichBottomGradients(UIView *root, NSMutableArray<UIView *> *output) {
    for (UIView *subview in root.subviews) {
        if (subview.hidden || subview.alpha <= 0.01) continue;
        if (DKIsRichBottomGradient(subview)) {
            [output addObject:subview];
            continue;
        }
        DKCollectRichBottomGradients(subview, output);
    }
}

static NSArray<UIView *> *DKRichBottomGradients(
    AWEStoryContainerCollectionView *collection
) {
    NSMutableArray<UIView *> *gradients = [NSMutableArray array];
    for (UICollectionViewCell *cell in collection.visibleCells) {
        DKCollectRichBottomGradients(cell, gradients);
    }
    return gradients;
}

static BOOL DKViewIsInCollection(UIView *view, UIView *collection) {
    return view == collection || [view isDescendantOfView:collection];
}

static void DKRestoreUnusedRichCollectionState(
    AWEStoryContainerCollectionView *collection,
    NSSet<UIView *> *activeGradients,
    NSSet<UIView *> *activeClipViews
) {
    for (UIView *view in gDKManagedVisualViews.allObjects) {
        if (!DKViewIsInCollection(view, collection)) continue;

        if (objc_getAssociatedObject(view, &kDKRichGradientTransformKey)
            && ![activeGradients containsObject:view]) {
            DKRestoreTransformBaseline(view, &kDKRichGradientTransformKey);
        }
        if (objc_getAssociatedObject(view, &kDKRichClipKey)
            && ![activeClipViews containsObject:view]) {
            DKRestoreRichOverflow(view);
        }
    }
}

static void DKSyncRichCollection(AWEStoryContainerCollectionView *collection) {
    CGFloat contentHeight = CGRectGetHeight(collection.bounds);
    CGFloat fullHeight = DKVideoFullscreenOn() ? DKFullCellHeight(collection) : 0.0;
    if (contentHeight <= 0.0
        || fullHeight <= contentHeight + kDKSignatureTolerance) {
        DKRestoreUnusedRichCollectionState(collection, [NSSet set], [NSSet set]);
        return;
    }

    NSMutableSet<UIView *> *activeGradients = [NSMutableSet set];
    NSMutableSet<UIView *> *activeClipViews = [NSMutableSet set];
    for (UIView *gradient in DKRichBottomGradients(collection)) {
        UIView *contentView = DKCellContentView(gradient);
        UIView *parent = gradient.superview;
        if (!contentView || !parent || ![gradient isDescendantOfView:collection]) continue;

        CGRect identityFrame = DKIdentityFrameInSuperview(gradient);
        CGFloat top = [parent convertPoint:identityFrame.origin toView:contentView].y;
        if (!DKApplyVerticalStretch(
            gradient,
            &kDKRichGradientTransformKey,
            top,
            fullHeight
        )) {
            continue;
        }

        [gDKManagedVisualViews addObject:gradient];
        [activeGradients addObject:gradient];

        for (UIView *ancestor = parent; ancestor; ancestor = ancestor.superview) {
            if (ancestor.clipsToBounds
                || objc_getAssociatedObject(ancestor, &kDKRichClipKey)) {
                DKAllowRichOverflow(ancestor);
                [activeClipViews addObject:ancestor];
            }
            if (ancestor == collection) break;
        }
    }

    DKRestoreUnusedRichCollectionState(collection, activeGradients, activeClipViews);
}

NSString *DKRichBottomGradientStats(UIView *collectionView) {
    Class collectionClass = NSClassFromString(@"AWEStoryContainerCollectionView");
    if (!collectionClass || ![collectionView isKindOfClass:collectionClass]) {
        return @"贴底压暗 = (集合视图无效)";
    }

    AWEStoryContainerCollectionView *collection =
        (AWEStoryContainerCollectionView *)collectionView;
    NSArray<UIView *> *gradients = DKRichBottomGradients(collection);
    if (gradients.count == 0) return @"贴底压暗 = (未命中)";

    UIView *gradient = gradients.firstObject;
    UIView *contentView = DKCellContentView(gradient);
    UIView *parent = gradient.superview;
    CGFloat bottom = 0.0;
    if (contentView && parent) {
        bottom = [parent convertPoint:
            CGPointMake(0.0, CGRectGetMaxY(gradient.frame))
            toView:contentView
        ].y;
    }

    NSUInteger clipping = 0;
    for (UIView *ancestor = parent; ancestor; ancestor = ancestor.superview) {
        if (ancestor.clipsToBounds) clipping++;
        if (ancestor == collection) break;
    }

    return [NSString stringWithFormat:
        @"贴底压暗 × %lu  frame=%@  bounds=%@  transform=%@  "
         "底边=%.1f/%.1f  裁剪阻断=%lu",
        (unsigned long)gradients.count,
        NSStringFromCGRect(gradient.frame),
        NSStringFromCGRect(gradient.bounds),
        NSStringFromCGAffineTransform(gradient.transform),
        bottom,
        contentView ? CGRectGetHeight(contentView.bounds) : 0.0,
        (unsigned long)clipping
    ];
}

%hook AWEStoryContainerCollectionView

- (void)layoutSubviews {
    %orig;
    DKSyncRichCollection(self);
}

%end

#pragma mark - 直播预览 HUD

// 直播预览的画面与背景按窗口尺寸排（容器只有 843 时 TTPlayerView2 已经是 926），撑高表对它们
// 没有影响；chrome 却是挂在容器高度上的——表撑高一个底栏后，「直播中」角标 / 昵称 / 简介 /
// 静音键 /「点击进入直播间」整体跟着容器底边下移 83pt，钻进悬浮底栏后面。要把它们抬回原位。
//
// **只能叠 transform，不能钉 frame**：0.5.3-beta1 钉过 AWELiveNewPreStreamViewController 的根视图，
// IESLive 每轮布局都按 Cell 满高重算它，与钉位互相追赶，进直播频道即卡死、约 10s 被看门狗杀掉。
// 位移量只由「Cell 满高 − 表撑高前的高度」决定，与被移动视图自己的 frame 无关，IESLive 怎么重排
// 都算出同一个值，天然不成环；命中测试跟随 transform，按钮照常可点。

// 贴底信息块在容器子树里的深度：容器 → 事件转发层 → IESLiveStackView → 信息块，取 4 留余量。
static const NSUInteger kDKLiveChromeDepthLimit = 4;

static char kDKLiveChromeAppliedKey;   // 挂 4 层容器：接管过没有，用来省掉绝大多数页面的遍历

static Class DKLiveLayoutContainerClass(void) {
    static Class cls;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cls = NSClassFromString(@"IESLiveLayoutContainerView"); });
    return cls;
}

// 位移量 = Cell 满高 − 该表撑高前的高度；表没被撑高过（搜索页那种本就满高的）返回 0。
static CGFloat DKLiveChromeLift(UIView *container) {
    NSNumber *original = DKVideoFeedTableOriginalHeight(DKFeedTableForView(container));
    UIView *contentView = DKCellContentView(container);
    if (!original || !contentView) return 0.0;

    return CGRectGetHeight(contentView.bounds) - original.doubleValue;
}

static BOOL DKLiveChromeIsManaged(UIView *view) {
    return objc_getAssociatedObject(view, &kDKLiveChromeTransformKey) != nil;
}

// 目标底边在**容器**坐标里的位置。两点都很关键：
//   · 取 identity frame，免得自己叠上去的位移污染判定；
//   · 尺子是容器不是直接父层——贴底是相对的，IESLive 还停在撑高前那轮布局时，
//     信息块同样贴着（更矮的）父层底边，按父层量会把没下移的块也抬走。
static CGFloat DKLiveChromeBottom(UIView *view, UIView *container) {
    CGRect frame = DKIdentityFrameInSuperview(view);
    return [view.superview convertPoint:CGPointMake(0.0, CGRectGetMaxY(frame))
                                 toView:container].y;
}

// 贴底信息块的签名：IESLiveLayoutContainerView、贴容器底、顶边不在容器顶——与图文那条贴底压暗
// 同一把尺子。「顶边不在容器顶」挡的是铺满整屏的浮层容器：它同样贴底，抬起来会把整层拽走。
// 命中即止不再下钻——块内还有一层贴底子容器（简介行），它跟着块一起走。
// 已接管的目标恒在列，否则关开关那一刻还原不掉。
static void DKCollectLiveChrome(
    UIView *root,
    UIView *container,
    NSUInteger depth,
    NSMutableArray<UIView *> *output
) {
    Class containerCls = DKLiveLayoutContainerClass();
    if (!containerCls || depth >= kDKLiveChromeDepthLimit) return;

    CGFloat full = CGRectGetHeight(container.bounds);
    for (UIView *subview in root.subviews) {
        if (subview.hidden || subview.alpha <= 0.01) continue;

        CGFloat bottom = DKLiveChromeBottom(subview, container);
        CGFloat top = bottom - CGRectGetHeight(subview.bounds);
        if (DKLiveChromeIsManaged(subview)
            || ([subview isKindOfClass:containerCls]
                && top > kDKSignatureTolerance
                && fabs(bottom - full) <= kDKSignatureTolerance)) {
            [output addObject:subview];
            continue;
        }
        DKCollectLiveChrome(subview, container, depth + 1, output);
    }
}

static NSArray<UIView *> *DKLiveChromeTargets(
    AWELivePreStream4LayerContainerView *container,
    CGFloat lift
) {
    NSMutableArray<UIView *> *targets = [NSMutableArray array];
    DKCollectLiveChrome(container, container, 0, targets);

    // 暗水印贴底但留了 8pt 边距，贴底签名认不出它，按槽位取；只在它确实落进撑出来的那一段里才算。
    UIImageView *watermark = container.bottomDarkWatermark;
    if (watermark && !watermark.hidden
        && (DKLiveChromeIsManaged(watermark)
            || DKLiveChromeBottom(watermark, container)
                > CGRectGetHeight(container.bounds) - lift + kDKSignatureTolerance)) {
        [targets addObject:watermark];
    }
    return targets;
}

static void DKSyncLiveChrome(AWELivePreStream4LayerContainerView *container) {
    CGFloat lift = DKVideoFullscreenOn() ? DKLiveChromeLift(container) : 0.0;
    BOOL applied = objc_getAssociatedObject(container, &kDKLiveChromeAppliedKey) != nil;
    // 表没被撑高、也没接管过的直播预览在这里退出，不做任何遍历。
    if (lift <= kDKSignatureTolerance && !applied) return;

    for (UIView *target in DKLiveChromeTargets(container, lift)) {
        if (DKApplyVerticalLift(target, &kDKLiveChromeTransformKey, lift)) {
            [gDKManagedVisualViews addObject:target];
            continue;
        }
        DKRestoreTransformBaseline(target, &kDKLiveChromeTransformKey);
    }
    objc_setAssociatedObject(container, &kDKLiveChromeAppliedKey,
                             lift > kDKSignatureTolerance ? @YES : nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static NSString *DKLiveSlotDesc(UIView *slot) {
    if (!slot) return @"(nil)";
    return [NSString stringWithFormat:@"%@ %p %@",
            NSStringFromClass(slot.class), slot, NSStringFromCGRect(slot.frame)];
}

NSString *DKLiveChromeStats(UIView *view) {
    Class containerCls = NSClassFromString(@"AWELivePreStream4LayerContainerView");
    if (!containerCls || ![view isKindOfClass:containerCls]) return @"  (不是 4 层容器)\n";

    AWELivePreStream4LayerContainerView *container =
        (AWELivePreStream4LayerContainerView *)view;
    UIView *contentView = DKCellContentView(container);
    NSNumber *original = DKVideoFeedTableOriginalHeight(DKFeedTableForView(container));

    NSMutableString *out = [NSMutableString string];
    [out appendFormat:@"  容器高=%.1f  Cell 满高=%.1f  表原高=%@  位移=%.1f\n",
     CGRectGetHeight(container.bounds),
     contentView ? CGRectGetHeight(contentView.bounds) : 0.0,
     original ? [NSString stringWithFormat:@"%.1f", original.doubleValue] : @"(未撑高)",
     DKLiveChromeLift(container)];
    // 具名槽位只为采集：本页哪些 chrome 挂在哪一层，下次要补别的房型时照它认人。
    [out appendFormat:@"  left    = %@\n", DKLiveSlotDesc(container.leftContainer)];
    [out appendFormat:@"  center  = %@\n", DKLiveSlotDesc(container.centerContainer)];
    [out appendFormat:@"  bottom  = %@\n", DKLiveSlotDesc(container.bottomContainer)];
    [out appendFormat:@"  control = %@\n", DKLiveSlotDesc(container.controlContainer)];
    [out appendFormat:@"  渐变层  = %@\n", DKLiveSlotDesc(container.gradientContainerView)];
    [out appendFormat:@"  暗水印  = %@\n", DKLiveSlotDesc(container.bottomDarkWatermark)];

    NSArray<UIView *> *targets = DKLiveChromeTargets(container, DKLiveChromeLift(container));
    [out appendFormat:@"  抬升目标 × %lu\n", (unsigned long)targets.count];
    for (UIView *target in targets) {
        CGRect identity = DKIdentityFrameInSuperview(target);
        CGFloat bottom = contentView
            ? [target.superview convertPoint:CGPointMake(0.0, CGRectGetMaxY(target.frame))
                                      toView:contentView].y
            : 0.0;
        [out appendFormat:@"    %@ %p  identity=%@  ty=%.1f  实际底边=%.1f\n",
         NSStringFromClass(target.class), target, NSStringFromCGRect(identity),
         target.transform.ty, bottom];
    }
    return out;
}

%hook AWELivePreStream4LayerContainerView

- (void)layoutSubviews {
    %orig;
    DKSyncLiveChrome(self);
}

%end

static void DKPageChromeVisualRestore(void) {
    for (UIView *view in gDKManagedVisualViews.allObjects) {
        DKRestoreTransformBaseline(view, &kDKKnowledgeTransformKey);
        DKRestoreTransformBaseline(view, &kDKRichGradientTransformKey);
        DKRestoreTransformBaseline(view, &kDKVideoGradientTransformKey);
        DKRestoreTransformBaseline(view, &kDKLiveChromeTransformKey);
        DKRestoreRichOverflow(view);
    }
    [gDKManagedVisualViews removeAllObjects];
}

%ctor {
    gDKManagedVisualViews = [NSHashTable weakObjectsHashTable];
    DKVideoFullscreenRegisterRestore(DKPageChromeVisualRestore);
}

// 设置项统一注册在 DKVideoGeometry.xm，本文件只提供页面修饰这一套逻辑。
