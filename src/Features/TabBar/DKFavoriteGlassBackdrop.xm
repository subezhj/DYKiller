//
//  DKFavoriteGlassBackdrop.xm
//  收藏页的嵌套 Tab 内容只到 605pt，喜欢页列表则铺满 874pt。
//  悬浮玻璃底栏开启时把收藏内容多延伸一个底栏高度，让胶囊后方显示列表而不是白底。
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
