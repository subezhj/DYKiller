//
//  DKSharePanelGlass.xm
//  分享面板液态玻璃：卡片底色、关闭键与第三行圆钮。第二行通讯录与文字不接管。
//

#import "DouyinHeaders.h"
#import "DKGlassFlexView.h"
#import "DKKeys.h"
#import "DKSettings.h"
#import "DKUtils.h"

#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import <objc/runtime.h>

static NSString *const kDKShareEffectClass = @"DUXVisualEffectView";
static const CGFloat kDKShareRadiusFloor = 20.0;
static const NSTimeInterval kDKShareGlassAnimation = 0.25;
static const float kDKSharePlateLuma = 0.76f;
static const float kDKSharePlateSat = 0.14f;

static char kSlotColorKey;
static char kSlotGlassKey;
static char kGlassClearKey;
static char kGlassStyleKey;
static char kGlassMaterializingKey;
static char kCloseOriginalConfigKey;
static char kCloseOriginalImageKey;
static char kCloseModeKey;
static char kCloseGlassKey;
static char kCellOriginalImageKey;
static char kCellOriginalColorKey;
static char kCellGlassKey;
static char kDestainedCacheKey;
static char kDestainedFlagKey;

static NSHashTable *gGlassCarriers;
static NSHashTable<AWESharePanelContainerViewController *> *gContainers;
static NSHashTable<AWESharePanelFunctionCell *> *gCells;
static BOOL gEverAttached = NO;
static __weak UIWindowScene *gObservedScene = nil;
static UIUserInterfaceStyle gGlassStyle = UIUserInterfaceStyleUnspecified;

typedef NS_ENUM(NSInteger, DKShareCloseMode) {
    DKShareCloseModeNone = 0,
    DKShareCloseModeOfficial,
    DKShareCloseModeOverlay,
};

#pragma mark - 开关与材质

static BOOL DKShareEnabled(void) {
    return DKPrefBool(DKKeySharePanelGlass);
}

static BOOL DKShareUsesClear(void) {
    return DKPrefBool(DKKeySharePanelGlassClear);
}

static BOOL DKShareColorOpaque(UIColor *color) {
    return color && CGColorGetAlpha(color.CGColor) >= 0.99;
}

static UIUserInterfaceStyle DKShareStyleForView(UIView *view) {
    UIUserInterfaceStyle style = view.window.windowScene.traitCollection.userInterfaceStyle;
    if (style == UIUserInterfaceStyleUnspecified) style = gGlassStyle;
    if (style == UIUserInterfaceStyleUnspecified) style = view.traitCollection.userInterfaceStyle;
    return style == UIUserInterfaceStyleUnspecified ? UIUserInterfaceStyleLight : style;
}

static UIUserInterfaceStyle DKShareOverrideStyle(BOOL clear, UIUserInterfaceStyle style) {
    return clear ? UIUserInterfaceStyleUnspecified : style;
}

static UIColor *DKShareTint(BOOL clear, UIUserInterfaceStyle style) {
    return clear ? DKGlassTintForStyle(style) : nil;
}

static UIGlassEffect *DKShareMakeEffect(BOOL clear, UIUserInterfaceStyle style)
    API_AVAILABLE(ios(26.0)) {
    UIGlassEffect *effect = [UIGlassEffect effectWithStyle:
        clear ? UIGlassEffectStyleClear : UIGlassEffectStyleRegular];
    effect.tintColor = DKShareTint(clear, style);
    effect.interactive = YES;
    return effect;
}

static void DKShareRunAnimation(UIViewController *controller, BOOL animated, void (^changes)(void)) {
    if (!changes) return;
    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        [UIView performWithoutAnimation:changes];
        return;
    }
    id<UIViewControllerTransitionCoordinator> coordinator = controller.transitionCoordinator;
    if (coordinator && coordinator.isAnimated) {
        BOOL accepted = [coordinator animateAlongsideTransition:
                         ^(__unused id<UIViewControllerTransitionCoordinatorContext> context) {
            changes();
        } completion:nil];
        if (accepted) return;
    }
    [UIView animateWithDuration:kDKShareGlassAnimation
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState
                              | UIViewAnimationOptionAllowUserInteraction
                              | UIViewAnimationOptionCurveEaseInOut
                     animations:changes
                     completion:nil];
}

static void DKShareInstallEffect(UIVisualEffectView *glass, BOOL clear, UIUserInterfaceStyle style)
    API_AVAILABLE(ios(26.0)) {
    glass.effect = DKShareMakeEffect(clear, style);
    objc_setAssociatedObject(glass, &kGlassClearKey, @(clear), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(glass, &kGlassStyleKey, @(style), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static BOOL DKShareGlassNeedsUpdate(UIVisualEffectView *glass, BOOL clear, UIUserInterfaceStyle style)
    API_AVAILABLE(ios(26.0)) {
    if (glass.overrideUserInterfaceStyle != DKShareOverrideStyle(clear, style)) return YES;
    UIGlassEffect *current = [glass.effect isKindOfClass:UIGlassEffect.class]
        ? (UIGlassEffect *)glass.effect : nil;
    if (!current) return glass.effect != nil;
    NSNumber *installedClear = objc_getAssociatedObject(glass, &kGlassClearKey);
    NSNumber *installedStyle = objc_getAssociatedObject(glass, &kGlassStyleKey);
    if (!installedClear || installedClear.boolValue != clear) return YES;
    if (!installedStyle || installedStyle.integerValue != style) return YES;
    if (!current.interactive) return YES;
    UIColor *want = DKShareTint(clear, style);
    return !((current.tintColor == want) || [current.tintColor isEqual:want]);
}

static void DKShareApplyStyle(UIUserInterfaceStyle style, BOOL animated) API_AVAILABLE(ios(26.0)) {
    if (style == UIUserInterfaceStyleUnspecified) return;
    gGlassStyle = style;
    BOOL clear = DKShareUsesClear();
    BOOL needs = NO;
    for (UIVisualEffectView *glass in gGlassCarriers.allObjects) {
        if (DKShareGlassNeedsUpdate(glass, clear, style)) {
            needs = YES;
            break;
        }
    }
    if (!needs) return;

    DKShareRunAnimation(nil, animated, ^{
        for (UIVisualEffectView *glass in gGlassCarriers.allObjects) {
            glass.overrideUserInterfaceStyle = DKShareOverrideStyle(clear, style);
            if (!glass.effect || !DKShareGlassNeedsUpdate(glass, clear, style)) continue;
            DKShareInstallEffect(glass, clear, style);
        }
    });
}

static void DKShareObserveStyle(UIView *host) API_AVAILABLE(ios(26.0)) {
    UIWindowScene *scene = host.window.windowScene;
    if (!scene || scene == gObservedScene) return;
    gObservedScene = scene;
    [scene registerForTraitChanges:@[ UITraitUserInterfaceStyle.class ]
                       withHandler:^(UIWindowScene *changed, __unused UITraitCollection *previous) {
        DKShareApplyStyle(changed.traitCollection.userInterfaceStyle, YES);
    }];
}

static UIVisualEffectView *DKShareMakeShell(void) API_AVAILABLE(ios(26.0)) {
    DKGlassFlexView *glass = [[DKGlassFlexView alloc] initWithEffect:nil];
    glass.userInteractionEnabled = NO;
    glass.alpha = 1.0;
    glass.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    return glass;
}

static void DKShareEnsureBackmost(UIView *slot, UIView *glass) {
    if (slot.subviews.firstObject == glass) return;
    [slot insertSubview:glass atIndex:0];
}

static BOOL DKShareRectUsable(CGRect rect) {
    return CGRectGetWidth(rect) >= 8.0 && CGRectGetHeight(rect) >= 8.0;
}

// 0 尺寸时写入 UIGlassEffect，系统不会建材质层；之后只改 frame 补不回来。
static void DKSharePlaceGlass(UIVisualEffectView *glass, CGRect frame, UIView *host, UIView *below) {
    if (!glass || !host) return;
    BOOL wasEmpty = !DKShareRectUsable(glass.bounds);
    if (!CGRectEqualToRect(glass.frame, frame)) glass.frame = frame;
    if (below.superview == host) {
        if (glass.superview != host) [host insertSubview:glass belowSubview:below];
    } else if (glass.superview != host) {
        [host insertSubview:glass atIndex:0];
    }
    if (wasEmpty && DKShareRectUsable(glass.bounds) && glass.effect) {
        glass.effect = nil;
        objc_setAssociatedObject(glass, &kGlassMaterializingKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void DKShareMaterialize(UIVisualEffectView *glass, UIViewController *controller)
    API_AVAILABLE(ios(26.0)) {
    if (!glass || !DKShareRectUsable(glass.bounds) || glass.effect
        || [objc_getAssociatedObject(glass, &kGlassMaterializingKey) boolValue]) {
        return;
    }
    objc_setAssociatedObject(glass, &kGlassMaterializingKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    DKShareRunAnimation(controller, YES, ^{
        if (!glass.superview || !DKShareEnabled()) {
            objc_setAssociatedObject(glass, &kGlassMaterializingKey,
                                     nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }
        UIUserInterfaceStyle style = gGlassStyle;
        if (style == UIUserInterfaceStyleUnspecified) style = DKShareStyleForView(glass);
        BOOL clear = DKShareUsesClear();
        glass.overrideUserInterfaceStyle = DKShareOverrideStyle(clear, style);
        DKShareInstallEffect(glass, clear, style);
        objc_setAssociatedObject(glass, &kGlassMaterializingKey,
                                 nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    });
}

#pragma mark - 去白底

static UIImage *DKShareDestainPlate(UIImage *image) {
    if (!image || [objc_getAssociatedObject(image, &kDestainedFlagKey) boolValue]) return image;
    UIImage *cached = objc_getAssociatedObject(image, &kDestainedCacheKey);
    if (cached) return cached;

    CGImageRef cgImage = image.CGImage;
    if (!cgImage) return image;
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    if (width == 0 || height == 0) return image;

    size_t stride = width * 4;
    uint8_t *pixels = (uint8_t *)calloc(height * stride, 1);
    if (!pixels) return image;
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(
        pixels, width, height, 8, stride, space,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    if (!context) {
        free(pixels);
        return image;
    }
    CGContextDrawImage(context, CGRectMake(0.0, 0.0, width, height), cgImage);

    NSUInteger kept = 0;
    size_t count = width * height;
    for (size_t i = 0; i < count; i++) {
        uint8_t *pixel = pixels + i * 4;
        float red = pixel[0] / 255.0f;
        float green = pixel[1] / 255.0f;
        float blue = pixel[2] / 255.0f;
        float alpha = pixel[3] / 255.0f;
        if (alpha < 0.02f) continue;
        float maximum = fmaxf(red, fmaxf(green, blue));
        float minimum = fminf(red, fminf(green, blue));
        float saturation = maximum > 0.001f ? (maximum - minimum) / maximum : 0.0f;
        if (maximum >= kDKSharePlateLuma && saturation <= kDKSharePlateSat) {
            pixel[0] = pixel[1] = pixel[2] = pixel[3] = 0;
        } else {
            kept += 1;
        }
    }

    UIImage *result = image;
    if (kept > 0) {
        CGImageRef output = CGBitmapContextCreateImage(context);
        if (output) {
            result = [UIImage imageWithCGImage:output
                                         scale:image.scale
                                   orientation:image.imageOrientation];
            CGImageRelease(output);
            objc_setAssociatedObject(result, &kDestainedFlagKey, @YES,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    CGContextRelease(context);
    free(pixels);
    objc_setAssociatedObject(image, &kDestainedCacheKey, result, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return result;
}

#pragma mark - 查找

static UIView *DKShareEffectView(AWESharePanelContainerViewController *controller) {
    Class cls = NSClassFromString(kDKShareEffectClass);
    if (!cls || !controller.isViewLoaded) return nil;
    for (UIView *subview in controller.view.subviews) {
        if ([subview isKindOfClass:cls]) return subview;
    }
    return nil;
}

static AWESharePanelViewController *DKShareContentController(UIViewController *controller) {
    if (!controller) return nil;
    if ([controller isKindOfClass:%c(AWESharePanelViewController)]) {
        return (AWESharePanelViewController *)controller;
    }
    if ([controller isKindOfClass:UINavigationController.class]) {
        return DKShareContentController(((UINavigationController *)controller).topViewController);
    }
    for (UIViewController *child in controller.childViewControllers) {
        AWESharePanelViewController *found = DKShareContentController(child);
        if (found) return found;
    }
    return nil;
}

static UIButton *DKShareCloseButton(AWESharePanelViewController *controller) {
    if (!controller.isViewLoaded) return nil;
    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:controller.view];
    while (stack.count > 0) {
        UIView *view = stack.lastObject;
        [stack removeLastObject];
        if ([view isKindOfClass:UIButton.class]
            && [((UIButton *)view).accessibilityLabel isEqualToString:@"关闭"]) {
            return (UIButton *)view;
        }
        for (UIView *subview in view.subviews) [stack addObject:subview];
    }
    return nil;
}

static UIViewController *DKShareControllerForView(UIView *view) {
    for (UIResponder *responder = view.nextResponder; responder; responder = responder.nextResponder) {
        if ([responder isKindOfClass:UIViewController.class]) return (UIViewController *)responder;
    }
    return nil;
}

// 圆底板：约 56×56、圆角裁成圆。图标可能画在这张图里，也可能只在 smallImageView 上。
static BOOL DKShareIsCirclePlate(UIImageView *imageView) {
    if (!imageView) return NO;
    CGFloat width = CGRectGetWidth(imageView.bounds);
    CGFloat height = CGRectGetHeight(imageView.bounds);
    if (width >= 40.0 && fabs(width - height) <= 1.0) return YES;
    return width < 1.0 && imageView.layer.cornerRadius >= 8.0;
}

static UIImageView *DKShareFindCircleImage(UIView *view, NSUInteger depth) {
    if (!view || depth > 8) return nil;
    if ([view isKindOfClass:UIImageView.class]
        && DKShareIsCirclePlate((UIImageView *)view)) {
        return (UIImageView *)view;
    }
    UIImageView *fallback = nil;
    for (UIView *subview in view.subviews) {
        UIImageView *found = DKShareFindCircleImage(subview, depth + 1);
        if (!found) continue;
        if (CGRectGetWidth(found.bounds) >= 40.0) return found;
        if (!fallback) fallback = found;
    }
    return fallback;
}

static UIImageView *DKShareCircleImageView(AWESharePanelFunctionCell *cell) {
    if ([cell respondsToSelector:@selector(imageView)] && cell.imageView
        && (DKShareIsCirclePlate(cell.imageView)
            || cell.imageView.image
            || DKShareColorOpaque(cell.imageView.backgroundColor))) {
        return cell.imageView;
    }
    return DKShareFindCircleImage(cell, 0);
}

#pragma mark - 面板

static BOOL DKShareClearSlot(UIView *slot) {
    UIColor *current = slot.backgroundColor;
    if (DKShareColorOpaque(current)) {
        if (!objc_getAssociatedObject(slot, &kSlotColorKey)) {
            objc_setAssociatedObject(slot, &kSlotColorKey, current, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        slot.backgroundColor = UIColor.clearColor;
        gEverAttached = YES;
        return YES;
    }
    return objc_getAssociatedObject(slot, &kSlotColorKey) != nil;
}

static UIVisualEffectView *DKShareAttachPanel(UIView *slot, UIView *shell)
    API_AVAILABLE(ios(26.0)) {
    if (!DKShareClearSlot(slot)) return nil;
    UIVisualEffectView *glass = objc_getAssociatedObject(slot, &kSlotGlassKey);
    if (!glass) {
        if ([slot.subviews.firstObject isKindOfClass:UIVisualEffectView.class]) return nil;
        glass = DKShareMakeShell();
        CGFloat radius = shell.layer.cornerRadius;
        if (radius <= 0.0) radius = kDKShareRadiusFloor;
        UICornerRadius *top = [UICornerRadius containerConcentricRadiusWithMinimum:radius];
        glass.cornerConfiguration =
            [UICornerConfiguration configurationWithUniformTopRadius:top
                                                    bottomLeftRadius:nil
                                                   bottomRightRadius:nil];
        ((DKGlassFlexView *)glass).flexSourceView = slot;
        objc_setAssociatedObject(slot, &kSlotGlassKey, glass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [gGlassCarriers addObject:glass];
        gEverAttached = YES;
    }
    if (!CGRectEqualToRect(glass.frame, slot.bounds)) glass.frame = slot.bounds;
    DKShareEnsureBackmost(slot, glass);
    return glass;
}

static void DKShareDetachPanel(UIView *slot) {
    UIColor *original = objc_getAssociatedObject(slot, &kSlotColorKey);
    if (!original) return;
    [(UIView *)objc_getAssociatedObject(slot, &kSlotGlassKey) removeFromSuperview];
    slot.backgroundColor = original;
    objc_setAssociatedObject(slot, &kSlotColorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(slot, &kSlotGlassKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - 关闭键

static void DKShareRememberClose(UIButton *button) {
    if (objc_getAssociatedObject(button, &kCloseOriginalImageKey)
        || objc_getAssociatedObject(button, &kCloseOriginalConfigKey)) {
        return;
    }
    if (button.configuration) {
        objc_setAssociatedObject(button, &kCloseOriginalConfigKey,
                                 button.configuration, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    UIImage *image = button.currentImage ?: button.imageView.image;
    if (image) {
        objc_setAssociatedObject(button, &kCloseOriginalImageKey,
                                 image, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void DKShareRemoveCloseOverlay(UIButton *button) {
    UIView *glass = objc_getAssociatedObject(button, &kCloseGlassKey);
    [glass removeFromSuperview];
    [gGlassCarriers removeObject:glass];
    objc_setAssociatedObject(button, &kCloseGlassKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void DKShareRestoreClose(UIButton *button) {
    if (!button) return;
    DKShareRemoveCloseOverlay(button);
    UIButtonConfiguration *config = objc_getAssociatedObject(button, &kCloseOriginalConfigKey);
    UIImage *image = objc_getAssociatedObject(button, &kCloseOriginalImageKey);
    if (config) {
        button.configuration = config;
    } else if (objc_getAssociatedObject(button, &kCloseModeKey)) {
        button.configuration = nil;
        if (image) [button setImage:image forState:UIControlStateNormal];
    }
    objc_setAssociatedObject(button, &kCloseOriginalConfigKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(button, &kCloseOriginalImageKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(button, &kCloseModeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void DKShareApplyCloseOverlay(UIButton *button, UIViewController *controller)
    API_AVAILABLE(ios(26.0)) {
    UIImage *original = objc_getAssociatedObject(button, &kCloseOriginalImageKey);
    if (original) {
        UIImage *icon = DKShareDestainPlate(original);
        if (button.configuration) button.configuration = nil;
        [button setImage:icon forState:UIControlStateNormal];
    }

    UIView *host = button.superview;
    if (!host) return;
    UIVisualEffectView *glass = objc_getAssociatedObject(button, &kCloseGlassKey);
    if (!glass) {
        glass = DKShareMakeShell();
        glass.cornerConfiguration = [UICornerConfiguration capsuleConfiguration];
        ((DKGlassFlexView *)glass).flexSourceView = button;
        objc_setAssociatedObject(button, &kCloseGlassKey, glass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [gGlassCarriers addObject:glass];
    }
    glass.autoresizingMask = UIViewAutoresizingNone;
    DKSharePlaceGlass(glass, button.frame, host, button);
    objc_setAssociatedObject(button, &kCloseModeKey,
                             @(DKShareCloseModeOverlay), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    DKShareMaterialize(glass, controller);
}

static BOOL DKShareApplyCloseOfficial(UIButton *button) API_AVAILABLE(ios(26.0)) {
    if (![UIButtonConfiguration respondsToSelector:@selector(glassButtonConfiguration)]) return NO;
    DKShareRemoveCloseOverlay(button);

    UIImage *original = objc_getAssociatedObject(button, &kCloseOriginalImageKey);
    UIButtonConfiguration *config = [UIButtonConfiguration glassButtonConfiguration];
    config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    config.contentInsets = NSDirectionalEdgeInsetsZero;
    if (original) config.image = DKShareDestainPlate(original);
    button.configuration = config;
    objc_setAssociatedObject(button, &kCloseModeKey,
                             @(DKShareCloseModeOfficial), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return YES;
}

static void DKShareApplyClose(UIButton *button, UIViewController *controller)
    API_AVAILABLE(ios(26.0)) {
    if (!button) return;
    DKShareRememberClose(button);
    if (DKShareUsesClear()) {
        DKShareApplyCloseOverlay(button, controller);
        return;
    }
    if (!DKShareApplyCloseOfficial(button)) DKShareApplyCloseOverlay(button, controller);
}

#pragma mark - 第三行圆钮

static void DKShareRestoreCell(AWESharePanelFunctionCell *cell) {
    UIImageView *imageView = DKShareCircleImageView(cell);
    UIImage *original = objc_getAssociatedObject(cell, &kCellOriginalImageKey);
    UIColor *color = objc_getAssociatedObject(cell, &kCellOriginalColorKey);
    if (imageView && original) imageView.image = original;
    if (imageView && color) imageView.backgroundColor = color;
    UIView *glass = objc_getAssociatedObject(cell, &kCellGlassKey);
    [glass removeFromSuperview];
    [gGlassCarriers removeObject:glass];
    objc_setAssociatedObject(cell, &kCellOriginalImageKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(cell, &kCellOriginalColorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(cell, &kCellGlassKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [gCells removeObject:cell];
}

static void DKShareApplyCell(AWESharePanelFunctionCell *cell, UIViewController *controller)
    API_AVAILABLE(ios(26.0)) {
    UIImageView *imageView = DKShareCircleImageView(cell);
    if (!imageView) return;

    // 底板两种画法：56×56 合成图，或白底 + smallImageView 图标。后一种没有 image。
    if (DKShareColorOpaque(imageView.backgroundColor)) {
        if (!objc_getAssociatedObject(cell, &kCellOriginalColorKey)) {
            objc_setAssociatedObject(cell, &kCellOriginalColorKey,
                                     imageView.backgroundColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        imageView.backgroundColor = UIColor.clearColor;
    }

    UIImage *current = imageView.image;
    if (current && ![objc_getAssociatedObject(current, &kDestainedFlagKey) boolValue]) {
        objc_setAssociatedObject(cell, &kCellOriginalImageKey,
                                 current, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        UIImage *icon = DKShareDestainPlate(current);
        if (icon != current) imageView.image = icon;
    }

    UIView *host = imageView.superview;
    if (!host) return;
    UIVisualEffectView *glass = objc_getAssociatedObject(cell, &kCellGlassKey);
    if (!glass) {
        glass = DKShareMakeShell();
        glass.autoresizingMask = UIViewAutoresizingNone;
        glass.cornerConfiguration = [UICornerConfiguration capsuleConfiguration];
        ((DKGlassFlexView *)glass).flexSourceView = cell;
        objc_setAssociatedObject(cell, &kCellGlassKey, glass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [gGlassCarriers addObject:glass];
        [gCells addObject:cell];
        gEverAttached = YES;
    }
    DKSharePlaceGlass(glass, imageView.frame, host, imageView);
    DKShareMaterialize(glass, controller);
}

static void DKShareCollectFunctionCells(UIView *view,
                                        NSMutableArray<AWESharePanelFunctionCell *> *output,
                                        NSUInteger depth) {
    if (!view || depth > 12) return;
    if ([view isKindOfClass:%c(AWESharePanelFunctionCell)]) {
        [output addObject:(AWESharePanelFunctionCell *)view];
        return;
    }
    for (UIView *subview in view.subviews) {
        DKShareCollectFunctionCells(subview, output, depth + 1);
    }
}

static void DKShareApplyVisibleCells(AWESharePanelViewController *controller)
    API_AVAILABLE(ios(26.0)) {
    if (!controller.isViewLoaded) return;
    NSMutableArray<AWESharePanelFunctionCell *> *cells = [NSMutableArray array];
    DKShareCollectFunctionCells(controller.view, cells, 0);
    for (AWESharePanelFunctionCell *cell in cells) DKShareApplyCell(cell, controller);
}

#pragma mark - 同步

static void DKShareRestoreController(AWESharePanelContainerViewController *container) {
    AWESharePanelViewController *content = DKShareContentController(container);
    if (content.isViewLoaded) {
        DKShareRestoreClose(DKShareCloseButton(content));
        DKShareDetachPanel(content.view);
    }
    for (AWESharePanelFunctionCell *cell in gCells.allObjects) {
        if (!content.view || [cell isDescendantOfView:content.view]) DKShareRestoreCell(cell);
    }
    [gContainers removeObject:container];
}

static void DKShareRestoreAll(void) {
    for (AWESharePanelFunctionCell *cell in gCells.allObjects) DKShareRestoreCell(cell);
    for (AWESharePanelContainerViewController *container in gContainers.allObjects) {
        AWESharePanelViewController *content = DKShareContentController(container);
        if (content.isViewLoaded) {
            DKShareRestoreClose(DKShareCloseButton(content));
            DKShareDetachPanel(content.view);
        }
    }
    [gContainers removeAllObjects];
}

static void DKShareSync(AWESharePanelContainerViewController *container) API_AVAILABLE(ios(26.0)) {
    if (!container.isViewLoaded) return;
    BOOL enabled = DKShareEnabled();
    if (!enabled && !gEverAttached) return;

    AWESharePanelViewController *content = DKShareContentController(container);
    if (!content.isViewLoaded) return;

    if (!enabled) {
        DKShareRestoreController(container);
        return;
    }

    [gContainers addObject:container];
    DKShareObserveStyle(content.view);
    UIUserInterfaceStyle style = DKShareStyleForView(content.view);
    UIView *shell = DKShareEffectView(container);

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    UIVisualEffectView *panel = DKShareAttachPanel(content.view, shell ?: content.view);
    DKShareApplyClose(DKShareCloseButton(content), content);
    DKShareApplyVisibleCells(content);
    [CATransaction commit];

    if (panel) {
        DKShareApplyStyle(style, YES);
        DKShareMaterialize(panel, content);
    }
}

static void DKShareRefreshVisible(void) {
    BOOL enabled = DKShareEnabled();
    if (!enabled) DKShareRestoreAll();
    for (AWESharePanelContainerViewController *container in gContainers.allObjects) {
        [container.viewIfLoaded setNeedsLayout];
    }
    for (AWESharePanelFunctionCell *cell in gCells.allObjects) {
        if (!enabled) continue;
        if (@available(iOS 26.0, *)) DKShareApplyCell(cell, DKShareControllerForView(cell));
    }
}

#pragma mark - Hook

%hook AWESharePanelContainerViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (@available(iOS 26.0, *)) DKShareSync(self);
}

- (void)viewDidLayoutSubviews {
    %orig;
    if (@available(iOS 26.0, *)) DKShareSync(self);
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    if (self.viewIfLoaded.window) return;
    DKShareRestoreController(self);
}

%end

%hook AWESharePanelViewController

- (void)viewDidLayoutSubviews {
    %orig;
    UIViewController *parent = self.parentViewController;
    while (parent && ![parent isKindOfClass:%c(AWESharePanelContainerViewController)]) {
        parent = parent.parentViewController;
    }
    if ([parent isKindOfClass:%c(AWESharePanelContainerViewController)]
        && @available(iOS 26.0, *)) {
        DKShareSync((AWESharePanelContainerViewController *)parent);
    }
}

- (void)awe_themeReload {
    %orig;
    UIViewController *parent = self.parentViewController;
    while (parent && ![parent isKindOfClass:%c(AWESharePanelContainerViewController)]) {
        parent = parent.parentViewController;
    }
    if ([parent isKindOfClass:%c(AWESharePanelContainerViewController)]
        && @available(iOS 26.0, *)) {
        DKShareSync((AWESharePanelContainerViewController *)parent);
    }
}

%end

%hook AWESharePanelFunctionCell

- (void)layoutSubviews {
    %orig;
    if (!DKShareEnabled()) {
        if (objc_getAssociatedObject(self, &kCellGlassKey)) DKShareRestoreCell(self);
        return;
    }
    if (@available(iOS 26.0, *)) DKShareApplyCell(self, DKShareControllerForView(self));
}

- (void)updateWithViewModel:(id)viewModel bigFontAdapter:(id)adapter {
    %orig;
    if (!DKShareEnabled()) return;
    if (@available(iOS 26.0, *)) DKShareApplyCell(self, DKShareControllerForView(self));
}

- (void)updateImageViewWithViewModel:(id)viewModel {
    %orig;
    if (!DKShareEnabled()) return;
    if (@available(iOS 26.0, *)) DKShareApplyCell(self, nil);
}

- (void)prepareForReuse {
    %orig;
    if (!DKShareEnabled()) DKShareRestoreCell(self);
}

%end

#pragma mark - 设置

%ctor {
    gGlassCarriers = [NSHashTable weakObjectsHashTable];
    gContainers = [NSHashTable weakObjectsHashTable];
    gCells = [NSHashTable weakObjectsHashTable];

    DKSettingsRegisterItem(@"分享", ^AWESettingItemModel *{
        AWESettingItemModel *item = DKMakeSwitch(
            DKKeySharePanelGlass,
            @"分享面板液态玻璃",
            @"把分享卡片换成 iOS 26 系统液态玻璃；默认 Regular"
        );
        void (^origBlock)(void) = [item.switchChangedBlock copy];
        item.switchChangedBlock = ^{
            if (origBlock) origBlock();
            void (^refresh)(void) = ^{
                if (@available(iOS 26.0, *)) DKShareRefreshVisible();
            };
            if (NSThread.isMainThread) refresh();
            else dispatch_async(dispatch_get_main_queue(), refresh);
        };
        return item;
    });

    DKSettingsRegisterItem(@"分享", ^AWESettingItemModel *{
        AWESettingItemModel *item = DKMakeSwitch(
            DKKeySharePanelGlassClear,
            @"清透玻璃",
            @"显示更多背后视频细节；关闭则使用系统 Regular"
        );
        void (^origBlock)(void) = [item.switchChangedBlock copy];
        item.switchChangedBlock = ^{
            if (origBlock) origBlock();
            void (^refresh)(void) = ^{
                if (@available(iOS 26.0, *)) {
                    UIUserInterfaceStyle style = gGlassStyle;
                    if (style == UIUserInterfaceStyleUnspecified) {
                        style = UIScreen.mainScreen.traitCollection.userInterfaceStyle;
                    }
                    DKShareApplyStyle(style, YES);
                    DKShareRefreshVisible();
                }
            };
            if (NSThread.isMainThread) refresh();
            else dispatch_async(dispatch_get_main_queue(), refresh);
        };
        return item;
    });
}
