//
//  DKSearchTrendingBlocker.xm
//  AWESearchFramework 按需加载，静态 Logos hook 在 ctor 时找不到目标类。
//  监听 dyld image 后到主线程安装 runtime hook，在榜单 UI 创建前短路。
//

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

static UIView *DKRecommendSectionForLabel(UILabel *label) {
    UIView *candidate = label;
    UIView *root = label.superview;
    for (NSUInteger i = 0; root && i < 6; i++, root = root.superview) {
        CGFloat width = CGRectGetWidth(root.bounds);
        CGFloat height = CGRectGetHeight(root.bounds);
        if (width >= 300.0 && height >= 45.0 && height <= 320.0) {
            candidate = root;
            break;
        }
    }
    return candidate == label ? label.superview : candidate;
}

static void DKSyncSearchRecommend(UIView *root) {
    if (!root) return;
    NSMutableArray<UIView *> *sections = [NSMutableArray array];
    NSMutableArray<UIView *> *pending = [NSMutableArray arrayWithObject:root];
    while (pending.count) {
        UIView *view = pending.lastObject;
        [pending removeLastObject];
        if ([view isKindOfClass:UILabel.class]
            && [((UILabel *)view).text isEqualToString:@"猜你想搜"]) {
            UIView *section = DKRecommendSectionForLabel((UILabel *)view);
            if (section && section != root) [sections addObject:section];
        }
        [pending addObjectsFromArray:view.subviews];
    }
    for (UIView *section in sections) {
        if (DKHideSearchRecommendOn()) {
            if (!objc_getAssociatedObject(section, &kDKRecommendHiddenKey)) {
                objc_setAssociatedObject(section, &kDKRecommendHiddenKey, @(section.hidden),
                                         OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            section.hidden = YES;
        } else if (objc_getAssociatedObject(section, &kDKRecommendHiddenKey)) {
            section.hidden = [objc_getAssociatedObject(section, &kDKRecommendHiddenKey) boolValue];
            objc_setAssociatedObject(section, &kDKRecommendHiddenKey, nil,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
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

%hook AWESearchMiddleFeedViewController

- (void)viewDidLayoutSubviews {
    %orig;
    DKSyncSearchRecommend([(UIViewController *)self viewIfLoaded]);
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
}
