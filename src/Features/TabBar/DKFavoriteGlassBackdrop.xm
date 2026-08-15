//
//  DKFavoriteGlassBackdrop.xm
//  收藏页的嵌套 Tab 内容只到 605pt，喜欢页列表则铺满 874pt；团购列表底边也停在 799pt。
//  悬浮玻璃底栏开启时只对这两条已验证结构补一个底栏高度。
//  精选内容本身已是 874pt，不改 frame，只由 DKGlassTabBar 隐藏外层 SkinView。
//

#import "DKGlassTabBar.h"
#import <objc/runtime.h>
#import <math.h>

static char kDKFavoriteFrameKey;

static void DKSetFavoriteExtendedFrame(UIView *view, CGRect frame) {
    if (!objc_getAssociatedObject(view, &kDKFavoriteFrameKey)) {
        objc_setAssociatedObject(view, &kDKFavoriteFrameKey,
                                 [NSValue valueWithCGRect:view.frame],
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (!CGRectEqualToRect(view.frame, frame)) view.frame = frame;
}

static void DKRestoreFavoriteFrames(UIView *root) {
    NSMutableArray<UIView *> *pending = [NSMutableArray arrayWithObject:root];
    while (pending.count) {
        UIView *view = pending.lastObject;
        [pending removeLastObject];
        NSValue *stored = objc_getAssociatedObject(view, &kDKFavoriteFrameKey);
        if (stored) {
            view.frame = stored.CGRectValue;
            objc_setAssociatedObject(view, &kDKFavoriteFrameKey, nil,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        [pending addObjectsFromArray:view.subviews];
    }
}

static void DKExtendFavoriteContent(UIView *root) {
    if (!root) return;
    UITabBar *glass = DKGlassTabBarCurrent();
    if (!glass) {
        DKRestoreFavoriteFrames(root);
        return;
    }

    Class sectionClass = NSClassFromString(@"AWETabContainerSectionCell");
    if (!sectionClass) return;
    NSMutableArray<UIView *> *pending = [NSMutableArray arrayWithObject:root];
    while (pending.count) {
        UIView *view = pending.lastObject;
        [pending removeLastObject];
        if (![view isKindOfClass:sectionClass]) {
            [pending addObjectsFromArray:view.subviews];
            continue;
        }

        CGFloat extension = CGRectGetHeight(glass.bounds);
        if (extension <= 0.0) return;
        NSValue *sectionOriginal = objc_getAssociatedObject(view, &kDKFavoriteFrameKey);
        CGFloat baseHeight = sectionOriginal
            ? CGRectGetHeight(sectionOriginal.CGRectValue)
            : CGRectGetHeight(view.bounds);
        CGFloat targetHeight = baseHeight + extension;
        CGFloat baseWidth = CGRectGetWidth(view.bounds);
        NSMutableArray<UIView *> *nodes = [NSMutableArray arrayWithObject:view];
        while (nodes.count) {
            UIView *node = nodes.lastObject;
            [nodes removeLastObject];
            CGRect frame = node.frame;
            if (fabs(CGRectGetHeight(frame) - baseHeight) <= 1.0
                && CGRectGetWidth(frame) >= baseWidth - 1.0) {
                frame.size.height = targetHeight;
                DKSetFavoriteExtendedFrame(node, frame);
            }
            [nodes addObjectsFromArray:node.subviews];
        }
        break;
    }
}

%hook AWEFavoriteV2ViewController_New

- (void)viewWillLayoutSubviews {
    %orig;
    DKExtendFavoriteContent([(UIViewController *)self viewIfLoaded]);
}

%end

static char kDKGrouponFrameKey;

static void DKExtendGrouponContent(UIView *root) {
    UITabBar *glass = DKGlassTabBarCurrent();
    Class collectionClass = NSClassFromString(@"AWEGrouponC2CollectionView");
    if (!root || !collectionClass) return;

    NSMutableArray<UIView *> *pending = [NSMutableArray arrayWithObject:root];
    while (pending.count) {
        UIView *view = pending.lastObject;
        [pending removeLastObject];
        if (![view isKindOfClass:collectionClass]) {
            [pending addObjectsFromArray:view.subviews];
            continue;
        }

        NSValue *stored = objc_getAssociatedObject(view, &kDKGrouponFrameKey);
        if (!glass) {
            if (stored) view.frame = stored.CGRectValue;
            objc_setAssociatedObject(view, &kDKGrouponFrameKey, nil,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }
        if (!stored) {
            stored = [NSValue valueWithCGRect:view.frame];
            objc_setAssociatedObject(view, &kDKGrouponFrameKey, stored,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        CGRect frame = stored.CGRectValue;
        CGFloat rootHeight = CGRectGetHeight(root.bounds);
        CGFloat barHeight = CGRectGetHeight(glass.bounds);
        if (fabs(CGRectGetMaxY(frame) - (rootHeight - barHeight)) <= 1.0) {
            frame.size.height += barHeight;
            if (!CGRectEqualToRect(view.frame, frame)) view.frame = frame;
        }
        return;
    }
}

%hook AWEGrouponC2ContainerViewController

- (void)viewWillLayoutSubviews {
    %orig;
    DKExtendGrouponContent([(UIViewController *)self viewIfLoaded]);
}

%end

static char kDKHangoutFrameKey;

static void DKExtendHangoutContent(UIView *root) {
    UITabBar *glass = DKGlassTabBarCurrent();
    if (!root) return;

    Class collectionClass = [UICollectionView class];
    NSMutableArray<UIView *> *pending = [NSMutableArray arrayWithObject:root];
    while (pending.count) {
        UIView *view = pending.lastObject;
        [pending removeLastObject];
        if ([view isKindOfClass:collectionClass]) {
            NSValue *stored = objc_getAssociatedObject(view, &kDKHangoutFrameKey);
            if (!glass) {
                if (stored) view.frame = stored.CGRectValue;
                objc_setAssociatedObject(view, &kDKHangoutFrameKey, nil,
                                         OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                return;
            }
            if (!stored) {
                stored = [NSValue valueWithCGRect:view.frame];
                objc_setAssociatedObject(view, &kDKHangoutFrameKey, stored,
                                         OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            CGRect frame = stored.CGRectValue;
            CGFloat rootHeight = CGRectGetHeight(root.bounds);
            CGFloat barHeight = CGRectGetHeight(glass.bounds);
            if (fabs(CGRectGetMaxY(frame) - (rootHeight - barHeight)) <= 1.0) {
                frame.size.height += barHeight;
                if (!CGRectEqualToRect(view.frame, frame)) view.frame = frame;
            }
            return;
        }
        [pending addObjectsFromArray:view.subviews];
    }
}

%hook AWEDCFeedListViewController

- (void)viewWillLayoutSubviews {
    %orig;
    DKExtendHangoutContent([(UIViewController *)self viewIfLoaded]);
}

%end
