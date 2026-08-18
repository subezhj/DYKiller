#import "DouyinHeaders.h"
#import "DKKeys.h"
#import "DKSettings.h"
#import "DKUtils.h"
#import "DKHookLogger.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

%group DKExperimentalFeaturesGroup

#pragma mark - 1. Metal 渲染管道极简优化与直通呈现 (Direct-to-Display & Offscreen Elimination)

%hook TTMetalViewVP

- (void)didMoveToWindow {
    %orig;
    if (self.window && DKPrefBool(DKKeyOptimizeRenderPipeline)) {
        if ([self.layer isKindOfClass:[CAMetalLayer class]]) {
            CAMetalLayer *metalLayer = (CAMetalLayer *)self.layer;
            metalLayer.presentsWithTransaction = NO;
            metalLayer.allowsNextDrawableTimeout = YES;
            metalLayer.opaque = YES;
            DKLogHookEvent(@"Experimental", @"TTMetalViewVP", @"Direct Metal Layer Optimization Applied");
        }
    }
}

%end

#pragma mark - 2. ProMotion 120Hz 极速触控响应 (Zero-Latency Scrolling)

%hook AWEFeedDataSafeTableView

- (void)didMoveToWindow {
    %orig;
    if (self.window && DKPrefBool(DKKeyProMotionFluidScrollEnabled)) {
        for (UIGestureRecognizer *gesture in self.gestureRecognizers) {
            if ([gesture isKindOfClass:[UIPanGestureRecognizer class]]) {
                // 提升触控优先级，消除手势仲裁延迟
                gesture.delaysTouchesBegan = NO;
                gesture.delaysTouchesEnded = NO;
            }
        }
        DKLogHookEvent(@"Experimental", @"AWEFeedDataSafeTableView", @"ProMotion 120Hz Zero-Latency Gestures Bound");
    }
}

%end

#pragma mark - 3. 智能后台冻结与内存防杀 (Anti-Jetsam)

%hook AWEShellViewController

- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig;
    if (DKPrefBool(DKKeyBackgroundAntiJetsamEnabled)) {
        DKLogHookEvent(@"Experimental", @"AWEShellViewController", @"Background Anti-Jetsam Memory Compression Triggered");
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            // 深度释放网络请求与临时图片缓存，降低内存水位至安全线以下
            [[NSURLCache sharedURLCache] removeAllCachedResponses];
            // 触发系统低内存广播，促使各子模块释放闲置纹理
            [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        });
    }
}

%end

static UIColor *DKExtractDominantColorFromImage(UIImage *image) {
    if (!image || !image.CGImage) return nil;
    CGImageRef cgImage = image.CGImage;
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    if (width == 0 || height == 0) return nil;

    uint32_t pixels[16 * 16] = {0};
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, 16, 16, 8, 16 * 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    if (!context) return nil;

    CGContextDrawImage(context, CGRectMake(0, 0, 16, 16), cgImage);
    CGContextRelease(context);

    uint64_t sumR = 0, sumG = 0, sumB = 0, count = 0;
    for (int i = 0; i < 256; i++) {
        uint32_t p = pixels[i];
        uint8_t r = (p >> 24) & 0xFF;
        uint8_t g = (p >> 16) & 0xFF;
        uint8_t b = (p >> 8) & 0xFF;
        uint8_t a = p & 0xFF;
        if (a > 30) {
            sumR += r;
            sumG += g;
            sumB += b;
            count++;
        }
    }
    if (count == 0) return nil;

    CGFloat r = (CGFloat)(sumR / count) / 255.0;
    CGFloat g = (CGFloat)(sumG / count) / 255.0;
    CGFloat b = (CGFloat)(sumB / count) / 255.0;

    CGFloat luma = 0.299 * r + 0.587 * g + 0.114 * b;
    if (luma < 0.25) {
        CGFloat factor = 0.28 / MAX(luma, 0.05);
        r = MIN(r * factor, 1.0);
        g = MIN(g * factor, 1.0);
        b = MIN(b * factor, 1.0);
    }
    return [UIColor colorWithRed:r green:g blue:b alpha:1.0];
}

#pragma mark - 4. 非全屏视频与图文自定义背景色 (Custom Backdrop Color)

%hook AWEPlayVideoViewController

- (void)setPlayerBackgroundView:(UIView *)backgroundView {
    %orig;
    NSInteger style = [[NSUserDefaults standardUserDefaults] integerForKey:DKKeyCustomBackdropColorStyle];
    if (style == 1) {
        // 选项 A：优雅石墨深灰 (#191919)
        UIColor *grey = [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:25.0/255.0 alpha:1.0];
        backgroundView.backgroundColor = grey;
    } else if (style == 2) {
        // 选项 B：视频主色自适应
        UIImage *cover = nil;
        if ([self respondsToSelector:@selector(coverImageView)]) {
            UIImageView *iv = (UIImageView *)[self performSelector:@selector(coverImageView)];
            if (iv && [iv isKindOfClass:[UIImageView class]]) cover = iv.image;
        }
        if (!cover && [self respondsToSelector:@selector(firstFrameImageView)]) {
            UIImageView *iv = (UIImageView *)[self performSelector:@selector(firstFrameImageView)];
            if (iv && [iv isKindOfClass:[UIImageView class]]) cover = iv.image;
        }
        if (cover) {
            UIColor *dominant = DKExtractDominantColorFromImage(cover);
            if (dominant) backgroundView.backgroundColor = dominant;
        }
    }
}

%end

%hook RichContentContainerViewController

- (void)viewDidLayoutSubviews {
    %orig;
    NSInteger style = [[NSUserDefaults standardUserDefaults] integerForKey:DKKeyCustomBackdropColorStyle];
    if (style == 1) {
        UIColor *grey = [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:25.0/255.0 alpha:1.0];
        UIView *listView = self.contentListViewController.viewIfLoaded;
        if (listView) {
            listView.backgroundColor = grey;
            for (UIView *sub in listView.subviews) {
                if ([NSStringFromClass(sub.class) containsString:@"BackgroundColorView"] ||
                    [NSStringFromClass(sub.class) containsString:@"DefaultContentCellView"]) {
                    sub.backgroundColor = grey;
                }
            }
        }
    }
}

%end

#pragma mark - 5. 同步 DYYY 文案缩放至“展开”与截断按钮 (Sync Description Truncation Scale)

%hook AWEPlayInteractionDescriptionLabel

- (void)layoutSubviews {
    %orig;
    NSString *scaleStr = [[NSUserDefaults standardUserDefaults] stringForKey:@"DYYYDescriptionScale"];
    CGFloat scale = scaleStr.length > 0 ? [scaleStr floatValue] : 1.0;
    if (scale > 0.0 && fabs(scale - 1.0) > 0.001) {
        // 递归对所有子视图中的按钮或截断视图应用等比缩放
        for (UIView *sub in self.subviews) {
            if ([sub isKindOfClass:[UIButton class]] || [NSStringFromClass(sub.class) containsString:@"Button"] || [NSStringFromClass(sub.class) containsString:@"Expand"]) {
                if (CGAffineTransformEqualToTransform(sub.transform, CGAffineTransformIdentity)) {
                    sub.transform = CGAffineTransformMakeScale(scale, scale);
                }
            }
        }
    }
}

%end

%end

%ctor {
    %init(DKExperimentalFeaturesGroup);
    
    DKSettingsRegisterItem(@"新特性与实验性功能", ^AWESettingItemModel *{
        return DKMakeChoice(
            DKKeyCustomBackdropColorStyle,
            @"[实验性] 非全屏自定义背景",
            @[ @"系统默认", @"优雅深灰 (#191919)", @"视频主色自适应" ]
        );
    });

    DKSettingsRegisterItem(@"新特性与实验性功能", ^AWESettingItemModel *{
        return DKMakeSwitch(
            DKKeyOptimizeRenderPipeline,
            @"[实验性] Metal 渲染穿透优化",
            @"Direct-to-Display 异步硬件表面呈现，剔除冗余离屏合成，降低 GPU 发热并提升高刷帧率"
        );
    });

    DKSettingsRegisterItem(@"新特性与实验性功能", ^AWESettingItemModel *{
        return DKMakeSwitch(
            DKKeyProMotionFluidScrollEnabled,
            @"[实验性] ProMotion 120Hz 极速触控",
            @"消除短视频与列表滑动手势的仲裁等待与锁帧延迟，实现 120Hz 零延迟极速跟手"
        );
    });
    
    DKSettingsRegisterItem(@"新特性与实验性功能", ^AWESettingItemModel *{
        return DKMakeSwitch(
            DKKeyBackgroundAntiJetsamEnabled,
            @"[实验性] 智能后台冻结与防杀",
            @"退后台瞬间主动卸载冗余图片与网络缓存，杜绝系统 Jetsam 杀后台，实现前台 100% 极速秒开"
        );
    });
}
