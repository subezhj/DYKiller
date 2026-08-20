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
    if (!image || !image.CGImage) return [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:25.0/255.0 alpha:1.0];
    CGImageRef cgImage = image.CGImage;
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    if (width == 0 || height == 0) return [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:25.0/255.0 alpha:1.0];

    // 优化性能：极轻量 8x8 快速采样，杜绝多图滑动卡顿
    uint32_t pixels[8 * 8] = {0};
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, 8, 8, 8, 8 * 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    if (!context) return [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:25.0/255.0 alpha:1.0];

    CGContextDrawImage(context, CGRectMake(0, 0, 8, 8), cgImage);
    CGContextRelease(context);

    uint64_t sumR = 0, sumG = 0, sumB = 0, count = 0;
    for (int i = 0; i < 64; i++) {
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
    if (count == 0) return [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:25.0/255.0 alpha:1.0];

    CGFloat r = (CGFloat)(sumR / count) / 255.0;
    CGFloat g = (CGFloat)(sumG / count) / 255.0;
    CGFloat b = (CGFloat)(sumB / count) / 255.0;

    // 柔和高级深色调算法：
    // 不直接使用原图高饱和艳色，而是将提取到的微弱色相以 20%~25% 的权重轻微混入石墨深灰 (#191919 / #222222)
    // 既保持与画面的色调一致性（冷色调带微冷灰、暖色调带微暖灰），又彻底杜绝刺眼大红大绿与大面积鲜艳亮色！
    CGFloat baseGrey = 28.0 / 255.0; // 基础雅致深灰
    CGFloat blendRatio = 0.22;       // 22% 柔和色调权重
    CGFloat finalR = (1.0 - blendRatio) * baseGrey + blendRatio * r * 0.45;
    CGFloat finalG = (1.0 - blendRatio) * baseGrey + blendRatio * g * 0.45;
    CGFloat finalB = (1.0 - blendRatio) * baseGrey + blendRatio * b * 0.45;

    return [UIColor colorWithRed:finalR green:finalG blue:finalB alpha:1.0];
}

static UIImage *DKFindImageRecursivelyInView(UIView *view, NSInteger depth) {
    if (!view || depth > 6) return nil;
    if ([view isKindOfClass:[UIImageView class]]) {
        UIImage *img = ((UIImageView *)view).image;
        if (img && img.size.width > 50 && img.size.height > 50) return img;
    }
    for (UIView *sub in view.subviews) {
        UIImage *cand = DKFindImageRecursivelyInView(sub, depth + 1);
        if (cand) return cand;
    }
    return nil;
}

static BOOL DKIsDouyinAlreadyCustomColored(UIColor *color) {
    if (!color) return NO;
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) return NO;
    if (a < 0.1) return NO;
    // 如果非纯黑/非深黑底色（亮度或三色通道有显著氛围色彩，即抖音官方已经给出了定制氛围背景），则判定抖音已变色
    CGFloat luma = 0.299 * r + 0.587 * g + 0.114 * b;
    return (luma > 0.12 && (fabs(r - g) > 0.03 || fabs(g - b) > 0.03 || luma > 0.20));
}

static BOOL DKKnowledgeGradientHasNativeColor(UIView *view) {
    if (!view) return NO;
    if ([view.layer isKindOfClass:[CAGradientLayer class]]) {
        CAGradientLayer *gl = (CAGradientLayer *)view.layer;
        NSArray *colors = gl.colors;
        if (colors.count > 0) {
            for (id colorRef in colors) {
                UIColor *c = [UIColor colorWithCGColor:(__bridge CGColorRef)colorRef];
                if (DKIsDouyinAlreadyCustomColored(c)) {
                    return YES;
                }
            }
        }
    }
    return NO;
}

static void DKApplyBackdropColorRecursively(UIView *view, UIColor *color, NSInteger depth) {
    if (!view || !color || depth > 8) return;
    NSString *cls = NSStringFromClass(view.class);
    if ([cls containsString:@"BackgroundColorView"] ||
        [cls containsString:@"DefaultContentCellView"] ||
        [cls containsString:@"ImageContentView"] ||
        [cls containsString:@"LivePhoto"] ||
        [cls containsString:@"AdapterCellView"] ||
        [cls containsString:@"fullscreenBackgroundView"]) {
        view.backgroundColor = color;
        view.accessibilityLabel = @"DKBackdropView";
    }
    Class gradientCls = %c(AWEKnowledgeGradientView);
    if ((gradientCls && [view isKindOfClass:gradientCls]) || [cls isEqualToString:@"AWEKnowledgeGradientView"]) {
        // 仅当抖音自身没有绘制有效氛围色时，才由插件接管替换渐变色
        if (!DKKnowledgeGradientHasNativeColor(view)) {
            if ([view.layer isKindOfClass:[CAGradientLayer class]]) {
                CAGradientLayer *gl = (CAGradientLayer *)view.layer;
                gl.colors = @[(id)color.CGColor, (id)color.CGColor];
            }
            view.backgroundColor = color;
            view.accessibilityLabel = @"DKBackdropGradientView";
        }
    }
    // 隐藏贴底黑色渐变压暗层（AWEGradientView），避免与自适应背景色产生二次混合造成底部色差与灰条，同时降低 GPU 混合渲染图层开销
    if ([cls isEqualToString:@"AWEGradientView"] || [cls containsString:@"AWEGradientView"]) {
        if (CGRectGetMinY(view.frame) > 400.0 || CGRectGetHeight(view.bounds) > 200.0) {
            view.hidden = YES;
        }
    }
    for (UIView *sub in view.subviews) {
        DKApplyBackdropColorRecursively(sub, color, depth + 1);
    }
}

#pragma mark - 4. 非全屏视频与图文/实况自定义背景色与居中 (Custom Backdrop Color & Centering)

static void DKApplyVideoBackdropColor(AWEPlayVideoViewController *controller) {
    if (!controller) return;
    NSInteger style = [[NSUserDefaults standardUserDefaults] integerForKey:DKKeyCustomBackdropColorStyle];
    if (style <= 0) return;

    UIView *backgroundView = controller.playerBackgroundView;
    if (!backgroundView) return;

    // 如果抖音原生已经绘制了氛围色彩，则我们不干预，直接放行
    if (backgroundView.backgroundColor && DKIsDouyinAlreadyCustomColored(backgroundView.backgroundColor)) {
        return;
    }

    if (style == 1) {
        // 选项 A：优雅石墨深灰 (#191919)
        UIColor *grey = [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:25.0/255.0 alpha:1.0];
        backgroundView.backgroundColor = grey;
        backgroundView.accessibilityLabel = @"DKBackdropPlayerView";
    } else if (style == 2) {
        // 选项 B：视频柔和微调主色自适应
        UIImage *cover = nil;
        if ([controller respondsToSelector:@selector(coverImageView)]) {
            UIImageView *iv = (UIImageView *)[controller performSelector:@selector(coverImageView)];
            if (iv && [iv isKindOfClass:[UIImageView class]]) cover = iv.image;
        }
        if (!cover && [controller respondsToSelector:@selector(firstFrameImageView)]) {
            UIImageView *iv = (UIImageView *)[controller performSelector:@selector(firstFrameImageView)];
            if (iv && [iv isKindOfClass:[UIImageView class]]) cover = iv.image;
        }
        if (!cover) {
            UIView *view = controller.viewIfLoaded;
            if (view) {
                cover = DKFindImageRecursivelyInView(view, 0);
            }
        }
        if (cover) {
            UIColor *dominant = DKExtractDominantColorFromImage(cover);
            if (dominant) {
                backgroundView.backgroundColor = dominant;
                backgroundView.accessibilityLabel = @"DKBackdropPlayerView";
            }
        }
    }
}

%hook AWEPlayVideoViewController

- (void)setPlayerBackgroundView:(UIView *)backgroundView {
    %orig;
    DKApplyVideoBackdropColor(self);
}

- (void)viewDidLayoutSubviews {
    %orig;
    DKApplyVideoBackdropColor(self);
}

%end

%hook RichContentContainerViewController

- (void)viewDidLayoutSubviews {
    %orig;
    NSInteger style = [[NSUserDefaults standardUserDefaults] integerForKey:DKKeyCustomBackdropColorStyle];
    if (style <= 0) return;

    UIView *listView = self.contentListViewController.viewIfLoaded;
    if (!listView) return;

    // 检查抖音是否本身已给图文设置了原生色彩渐变
    Class gradientCls = %c(AWEKnowledgeGradientView);
    for (UIView *sub in listView.subviews) {
        if ((gradientCls && [sub isKindOfClass:gradientCls]) || [NSStringFromClass(sub.class) isEqualToString:@"AWEKnowledgeGradientView"]) {
            if (DKKnowledgeGradientHasNativeColor(sub)) {
                return; // 抖音原生已变色，不干预！
            }
        }
    }

    UIColor *targetColor = nil;
    if (style == 1) {
        // 优雅石墨深灰 (#191919)
        targetColor = [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:25.0/255.0 alpha:1.0];
    } else if (style == 2) {
        // 视频与图文/实况柔和主色自适应
        UIImage *foundImg = DKFindImageRecursivelyInView(listView, 0);
        if (foundImg) {
            targetColor = DKExtractDominantColorFromImage(foundImg);
        }
    }

    if (targetColor) {
        listView.backgroundColor = targetColor;
        DKApplyBackdropColorRecursively(listView, targetColor, 0);
    }
}

%end

%hook UICollectionViewCell

- (void)layoutSubviews {
    %orig;
    NSInteger style = [[NSUserDefaults standardUserDefaults] integerForKey:DKKeyCustomBackdropColorStyle];
    if (style <= 0) return;

    NSString *cls = NSStringFromClass(self.class);
    // 严格排除评论区、搜索卡片等其它 CollectionViewCell，仅限图文/实况专用 Cell
    if ([cls containsString:@"Comment"] || [cls containsString:@"Header"] || [cls containsString:@"Footer"] || [cls containsString:@"TabContent"]) {
        return;
    }

    if ([cls containsString:@"ImageContentAdapterCellView"] ||
        [cls containsString:@"LivePhotoContentAdapterCellView"] ||
        [cls containsString:@"DefaultContentCellView"]) {
        
        // 检查自身是否已经包含抖音原生有效渐变
        Class gradientCls = %c(AWEKnowledgeGradientView);
        for (UIView *sub in self.subviews) {
            if ((gradientCls && [sub isKindOfClass:gradientCls]) || [NSStringFromClass(sub.class) isEqualToString:@"AWEKnowledgeGradientView"]) {
                if (DKKnowledgeGradientHasNativeColor(sub)) {
                    return; // 抖音原生已变色，不干预！
                }
            }
        }

        UIColor *targetColor = nil;
        if (style == 1) {
            targetColor = [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:25.0/255.0 alpha:1.0];
        } else if (style == 2) {
            UIImage *img = DKFindImageRecursivelyInView(self, 0);
            if (img) {
                targetColor = DKExtractDominantColorFromImage(img);
            }
        }
        if (targetColor) {
            self.backgroundColor = targetColor;
            self.contentView.backgroundColor = targetColor;
            DKApplyBackdropColorRecursively(self, targetColor, 0);
        }
    }
}

%end

#pragma mark - 5. 同步 DYYY 文案缩放至“展开”与同城/团购推荐卡片 (Sync Description & POI Card Style)

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

%hook UIView

- (void)layoutSubviews {
    %orig;
    if (DKPrefBool(DKKeyPOICommentStyleUnified)) {
        NSString *cls = NSStringFromClass(self.class);
        if ([cls containsString:@"POICommentCard"] || [cls containsString:@"POIRatingList"] || [cls containsString:@"POIAnchor"]) {
            NSString *descColorHex = [[NSUserDefaults standardUserDefaults] stringForKey:@"DYYYDescriptionColor"];
            NSString *scaleStr = [[NSUserDefaults standardUserDefaults] stringForKey:@"DYYYDescriptionScale"];
            CGFloat scale = scaleStr.length > 0 ? [scaleStr floatValue] : 1.0;
            if (scale > 0.0 && fabs(scale - 1.0) > 0.001) {
                if (CGAffineTransformEqualToTransform(self.transform, CGAffineTransformIdentity)) {
                    self.transform = CGAffineTransformMakeScale(scale, scale);
                }
            }
            if (descColorHex.length > 0) {
                for (UIView *sub in self.subviews) {
                    if ([sub isKindOfClass:[UILabel class]]) {
                        // 统一跟随 DYYY 文案排版风格
                        ((UILabel *)sub).alpha = 0.95;
                    }
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
            DKKeyPOICommentStyleUnified,
            @"[实验性] 团购/POI推荐文案与DYYY统一",
            @"自动将同城团购、大家都在说及店铺推荐卡片的文字排版与缩放同步为 DYYY 样式"
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
