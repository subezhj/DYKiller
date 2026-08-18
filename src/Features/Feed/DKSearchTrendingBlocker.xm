//
//  DKSearchTrendingBlocker.xm
//  AWESearchFramework 按需加载，静态 Logos hook 在 ctor 时找不到目标类。
//  监听 dyld image 后到主线程安装 runtime hook，在榜单 UI 创建前短路。
//

#import "DouyinHeaders.h"
#import "DKKeys.h"
#import "DKSettings.h"
#import "DKUtils.h"
#import <mach-o/dyld.h>
#import <objc/runtime.h>
#import <stdatomic.h>
#import <string.h>

static BOOL (*gOrigShouldShowTab)(id, SEL);
static CGSize (*gOrigSizeWithModel)(id, SEL, id, double);
static void (*gOrigConfigUI)(id, SEL);
static void (*gOrigWillDisplay)(id, SEL);
static atomic_bool gInstallScheduled = false;
static BOOL gHooksInstalled = NO;
static NSUInteger gInstallAttempts = 0;

static BOOL DKHideSearchTrendingBoardOn(void) {
    return DKPrefBool(DKKeyHideSearchTrendingBoard);
}

static BOOL DKHideSearchRecommendOn(void) {
    return DKPrefBool(DKKeyHideSearchRecommend);
}

static char kDKRecommendHiddenKey;
static char kDKRecommendInteractionKey;
static char kDKRecommendFrameKey;
static char kDKRecommendRetainedHeightKey;

static UIView *DKRecommendLynxRoot(UIView *root, UIView **history, UIView **recommend) {
    NSString *lynxClass = @"UILynxView";
    NSMutableArray<UIView *> *pending = [NSMutableArray arrayWithObject:root];
    while (pending.count) {
        UIView *view = pending.lastObject;
        [pending removeLastObject];
        NSMutableArray<UIView *> *fullWidth = [NSMutableArray array];
        CGFloat width = CGRectGetWidth(view.bounds);
        for (UIView *child in view.subviews) {
            if ([NSStringFromClass(child.class) isEqualToString:lynxClass]
                && fabs(CGRectGetMinX(child.frame)) <= 1.0
                && fabs(CGRectGetWidth(child.frame) - width) <= 1.0
                && CGRectGetHeight(child.bounds) > 40.0) {
                [fullWidth addObject:child];
            }
        }
        if (fullWidth.count == 2) {
            [fullWidth sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
                return CGRectGetMinY(a.frame) < CGRectGetMinY(b.frame)
                    ? NSOrderedAscending : NSOrderedDescending;
            }];
            UIView *first = fullWidth[0];
            UIView *second = fullWidth[1];
            if (fabs(CGRectGetMinY(first.frame)) <= 1.0
                && fabs(CGRectGetMinY(second.frame) - CGRectGetMaxY(first.frame)) <= 1.0) {
                if (history) *history = first;
                if (recommend) *recommend = second;
                return view;
            }
        }
        [pending addObjectsFromArray:view.subviews];
    }
    return nil;
}

static void DKSetRecommendFrame(UIView *view, CGRect frame) {
    if (!objc_getAssociatedObject(view, &kDKRecommendFrameKey)) {
        objc_setAssociatedObject(view, &kDKRecommendFrameKey,
                                 [NSValue valueWithCGRect:view.frame],
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (!CGRectEqualToRect(view.frame, frame)) view.frame = frame;
}

static void DKSyncSearchRecommendCell(UIView *cell) {
    UIView *history = nil;
    UIView *recommend = nil;
    UIView *lynxRoot = DKRecommendLynxRoot(cell, &history, &recommend);
    if (!lynxRoot || !history || !recommend) return;

    if (!DKHideSearchRecommendOn()) {
        objc_setAssociatedObject(cell, &kDKRecommendRetainedHeightKey, nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        NSNumber *hidden = objc_getAssociatedObject(recommend, &kDKRecommendHiddenKey);
        NSNumber *interaction = objc_getAssociatedObject(recommend, &kDKRecommendInteractionKey);
        if (hidden) recommend.hidden = hidden.boolValue;
        if (interaction) recommend.userInteractionEnabled = interaction.boolValue;
        objc_setAssociatedObject(recommend, &kDKRecommendHiddenKey, nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(recommend, &kDKRecommendInteractionKey, nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        for (UIView *view = lynxRoot; view; view = view.superview) {
            NSValue *stored = objc_getAssociatedObject(view, &kDKRecommendFrameKey);
            if (stored) view.frame = stored.CGRectValue;
            objc_setAssociatedObject(view, &kDKRecommendFrameKey, nil,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (view == cell) break;
        }
        return;
    }

    if (!objc_getAssociatedObject(recommend, &kDKRecommendHiddenKey)) {
        objc_setAssociatedObject(recommend, &kDKRecommendHiddenKey, @(recommend.hidden),
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(recommend, &kDKRecommendInteractionKey,
                                 @(recommend.userInteractionEnabled),
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    recommend.hidden = YES;
    recommend.userInteractionEnabled = NO;

    CGFloat retainedHeight = CGRectGetMaxY(history.frame);
    objc_setAssociatedObject(cell, &kDKRecommendRetainedHeightKey, @(retainedHeight),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    for (UIView *view = lynxRoot; view && view != cell; view = view.superview) {
        CGRect frame = view.frame;
        frame.size.height = retainedHeight;
        DKSetRecommendFrame(view, frame);
    }
    CGRect cellFrame = cell.frame;
    cellFrame.size.height = retainedHeight;
    DKSetRecommendFrame(cell, cellFrame);
}

static BOOL DKShouldShowTab(id self, SEL cmd) {
    return DKHideSearchTrendingBoardOn() ? NO : gOrigShouldShowTab(self, cmd);
}

static CGSize DKSizeWithModel(id self, SEL cmd, id model, double width) {
    return DKHideSearchTrendingBoardOn() ? CGSizeZero
                                         : gOrigSizeWithModel(self, cmd, model, width);
}

static void DKConfigUI(id self, SEL cmd) {
    if (DKHideSearchTrendingBoardOn()) {
        UIView *view = (UIView *)self;
        view.hidden = YES;
        view.userInteractionEnabled = NO;
        return;
    }
    gOrigConfigUI(self, cmd);
}

static void DKWillDisplay(id self, SEL cmd) {
    if (!DKHideSearchTrendingBoardOn()) gOrigWillDisplay(self, cmd);
}

static void DKInstallSearchTrendingHooks(void) {
    if (gHooksInstalled) return;
    Class cls = objc_getClass("AWESearchMiddleNATabViewComponent");
    if (!cls) return;

    Class meta = object_getClass(cls);
    Method should = class_getInstanceMethod(meta, @selector(shouldShowTab));
    Method size = class_getInstanceMethod(meta, @selector(sizeWithViewModel:width:));
    Method config = class_getInstanceMethod(cls, @selector(configUI));
    Method display = class_getInstanceMethod(cls, @selector(componentWillDisplay));
    if (!should || !size || !config || !display) return;

    gOrigShouldShowTab = (BOOL (*)(id, SEL))method_setImplementation(should, (IMP)DKShouldShowTab);
    gOrigSizeWithModel = (CGSize (*)(id, SEL, id, double))method_setImplementation(size, (IMP)DKSizeWithModel);
    gOrigConfigUI = (void (*)(id, SEL))method_setImplementation(config, (IMP)DKConfigUI);
    gOrigWillDisplay = (void (*)(id, SEL))method_setImplementation(display, (IMP)DKWillDisplay);
    gHooksInstalled = gOrigShouldShowTab && gOrigSizeWithModel && gOrigConfigUI && gOrigWillDisplay;
}

static void DKTryInstallSearchHooks(void) {
    DKInstallSearchTrendingHooks();
    if (gHooksInstalled || ++gInstallAttempts >= 10) {
        gInstallAttempts = 0;
        atomic_store(&gInstallScheduled, false);
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC),
                   dispatch_get_main_queue(), ^{ DKTryInstallSearchHooks(); });
}

static void DKSearchImageAdded(const struct mach_header *header, intptr_t slide) {
    const char *imageName = NULL;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        if (_dyld_get_image_header(i) == header) {
            imageName = _dyld_get_image_name(i);
            break;
        }
    }
    if (!imageName || !strstr(imageName, "AWESearchFramework")) return;

    bool expected = false;
    if (!atomic_compare_exchange_strong(&gInstallScheduled, &expected, true)) return;
    dispatch_async(dispatch_get_main_queue(), ^{ DKTryInstallSearchHooks(); });
}

%hook CachalotCommonCollectionViewCell

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)attributes {
    NSNumber *height = objc_getAssociatedObject(self, &kDKRecommendRetainedHeightKey);
    if (!height || !DKHideSearchRecommendOn()) {
        %orig;
        return;
    }
    UICollectionViewLayoutAttributes *adjusted = [attributes copy];
    CGRect frame = adjusted.frame;
    frame.size.height = height.doubleValue;
    adjusted.frame = frame;
    %orig(adjusted);
}

- (void)layoutSubviews {
    %orig;
    DKSyncSearchRecommendCell((UIView *)self);
}

%end

// 屏蔽视频挂件与拍同款/电商/投票贴纸（不影响正常视频与文案）
static BOOL DKHideFeedStickersAndWidgetsOn(void) {
    return DKPrefBool(DKKeyHideFeedStickersAndWidgets);
}

%hook AWEFeedStickerContainerView

- (void)layoutSubviews {
    %orig;
    if (DKHideFeedStickersAndWidgetsOn()) {
        for (UIView *subview in self.subviews) {
            NSString *cls = NSStringFromClass([subview class]);
            // 过滤营销挂件、拍同款气泡、电商卡片、投票组件
            if ([cls containsString:@"Sticker"] || [cls containsString:@"Interact"] || [cls containsString:@"Widget"]) {
                if (!subview.hidden) subview.hidden = YES;
            }
        }
    }
}

%end

%hook AWEAwemePlayletWaterMarkView

- (void)layoutSubviews {
    %orig;
    if (DKHideFeedStickersAndWidgetsOn()) {
        if (!self.hidden) self.hidden = YES;
    }
}

%end

%ctor {
    _dyld_register_func_for_add_image(DKSearchImageAdded);
    dispatch_async(dispatch_get_main_queue(), ^{ DKInstallSearchTrendingHooks(); });

    DKSettingsRegisterItem(@"搜索", ^AWESettingItemModel *{
        return DKMakeSwitch(
            DKKeyHideSearchTrendingBoard,
            @"屏蔽搜索榜单",
            @"阻止抖音热榜、城市榜、直播榜等 Tab 及其 Lynx 资源加载；开启后重启抖音生效"
        );
    });
    DKSettingsRegisterItem(@"搜索", ^AWESettingItemModel *{
        return DKMakeSwitch(
            DKKeyHideSearchRecommend,
            @"屏蔽猜你想搜",
            @"隐藏搜索中间页推荐词区域，不影响搜索输入联想和历史记录"
        );
    });
    DKSettingsRegisterItem(@"净化", ^AWESettingItemModel *{
        return DKMakeSwitch(
            DKKeyHideFeedStickersAndWidgets,
            @"屏蔽视频挂件与拍同款贴纸",
            @"隐藏视频画面上的营销浮层、拍同款气泡、短剧水印、电商及互动挂件"
        );
    });
}
