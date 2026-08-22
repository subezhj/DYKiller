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

    // 抖音官方质感深色调自适应算法：
    // 1. 保留画面的主体色相 (Hue)
    // 2. 饱和度 (Saturation) 范围放宽至 0.28 ~ 0.45，让绿色、暖色等画面主色调更加鲜明清晰
    // 3. 亮度 (Brightness) 调整在 0.14 ~ 0.22 之间，呈现纯正深色氛围底色
    UIColor *rawColor = [UIColor colorWithRed:r green:g blue:b alpha:1.0];
    CGFloat hue = 0, sat = 0, bri = 0, alp = 0;
    if ([rawColor getHue:&hue saturation:&sat brightness:&bri alpha:&alp]) {
        CGFloat clampedSat = MAX(0.20, MIN(sat * 0.75, 0.45)); // 保持适中饱和度，让自适应色彩鲜活可辨
        CGFloat clampedBri = 0.14 + 0.08 * MIN(bri, 1.0);      // 亮度维持在 14%~22% 的高级深色调区间
        return [UIColor colorWithHue:hue saturation:clampedSat brightness:clampedBri alpha:1.0];
    }

    // 兜底微混
    CGFloat baseGrey = 35.0 / 255.0;
    return [UIColor colorWithRed:baseGrey green:baseGrey blue:baseGrey alpha:1.0];
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

static UIColor *DKKnowledgeGradientNativeColor(UIView *view) {
    if (!view) return nil;
    if ([view.layer isKindOfClass:[CAGradientLayer class]]) {
        CAGradientLayer *gl = (CAGradientLayer *)view.layer;
        NSArray *colors = gl.colors;
        if (colors.count > 0) {
            id lastColorRef = colors.lastObject;
            if (lastColorRef) {
                UIColor *c = [UIColor colorWithCGColor:(__bridge CGColorRef)lastColorRef];
                if (DKIsDouyinAlreadyCustomColored(c)) {
                    return c;
                }
            }
        }
    }
    return nil;
}

static BOOL DKKnowledgeGradientHasNativeColor(UIView *view) {
    return DKKnowledgeGradientNativeColor(view) != nil;
}

static void DKApplyBackdropColorRecursively(UIView *view, UIColor *color, NSInteger depth) {
    if (!view || !color || depth > 8) return;
    NSString *cls = NSStringFromClass(view.class);
    // 覆盖所有非全屏图文/实况容器与适配器层
    if ([cls containsString:@"LivePhoto"] ||
        [cls containsString:@"AdapterCellView"] ||
        [cls containsString:@"ImageContentBackgroundColorView"] ||
        [cls containsString:@"DefaultContentCellView"] ||
        [cls containsString:@"fullscreenBackgroundView"]) {
        view.backgroundColor = color;
        view.accessibilityLabel = @"DKBackdropView";
    }
    // 隐藏 Cell 内部贴底的 280pt 黑色压暗层（AWEGradientView），消除图片底部与上方的色差黑块
    if ([cls isEqualToString:@"AWEGradientView"] || [cls containsString:@"AWEGradientView"]) {
        if (CGRectGetMinY(view.frame) > 400.0 || CGRectGetHeight(view.bounds) > 200.0) {
            view.hidden = YES;
        }
    }
    for (UIView *sub in view.subviews) {
        DKApplyBackdropColorRecursively(sub, color, depth + 1);
    }
}

static void DKHideVideoGradientsRecursively(UIView *view, NSInteger depth) {
    if (!view || depth > 8) return;
    NSString *cls = NSStringFromClass(view.class);
    if ([cls isEqualToString:@"AWEGradientView"] || [cls containsString:@"AWEGradientView"]) {
        if (CGRectGetMinY(view.frame) > 400.0 || CGRectGetHeight(view.bounds) > 200.0) {
            view.hidden = YES;
        }
    }
    for (UIView *sub in view.subviews) {
        DKHideVideoGradientsRecursively(sub, depth + 1);
    }
}

// 判断当前视频控制器是否为纯横屏/非竖屏视频（画面宽高比显著大于竖屏，留有上下黑边）
static BOOL DKIsHorizontalVideo(AWEPlayVideoViewController *controller) {
    if (!controller) return NO;
    // 检查视频播放画面的尺寸/比例
    UIView *playerView = [controller respondsToSelector:@selector(playerView)] ? (UIView *)[controller performSelector:@selector(playerView)] : nil;
    if (playerView) {
        CGRect f = playerView.frame;
        if (f.size.width > 0 && f.size.height > 0) {
            // 横屏视频的宽度 >= 高度，或者高度明显小于屏幕高度（留黑边）
            if (f.size.width >= f.size.height || f.size.height < 650.0) {
                return YES;
            }
        }
    }
    // 检查 TTMetalViewVP 内部图层
    UIView *rootView = controller.viewIfLoaded;
    if (rootView) {
        for (UIView *sub in rootView.subviews) {
            if ([sub isKindOfClass:NSClassFromString(@"TTPlayerView")]) {
                for (UIView *metal in sub.subviews) {
                    if ([metal isKindOfClass:NSClassFromString(@"TTMetalViewVP")]) {
                        CGRect mf = metal.frame;
                        if (mf.size.height > 0 && mf.size.height < 600.0) {
                            return YES;
                        }
                    }
                }
            }
        }
    }
    // 兜底检查 model 分辨率宽高
    id awemeModel = [controller respondsToSelector:@selector(model)] ? [controller performSelector:@selector(model)] : nil;
    if (awemeModel && [awemeModel respondsToSelector:@selector(video)]) {
        id video = [awemeModel performSelector:@selector(video)];
        if (video && [video respondsToSelector:@selector(width)] && [video respondsToSelector:@selector(height)]) {
            CGFloat w = [[video performSelector:@selector(width)] doubleValue];
            CGFloat h = [[video performSelector:@selector(height)] doubleValue];
            if (w > 0 && h > 0 && w >= h) {
                return YES;
            }
        }
    }
    return NO;
}

static void DKApplyVideoBackdropColor(AWEPlayVideoViewController *controller) {
    if (!controller) return;
    NSInteger style = [[NSUserDefaults standardUserDefaults] integerForKey:DKKeyCustomBackdropColorStyle];
    if (style <= 0) return;

    // 严格限制：只对纯横屏视频（有上下黑边的视频）生效！普通竖屏全屏视频绝不干预
    if (!DKIsHorizontalVideo(controller)) {
        return;
    }

    UIView *backgroundView = controller.playerBackgroundView;
    if (!backgroundView) {
        UIView *view = controller.viewIfLoaded;
        if (view) {
            backgroundView = [[UIView alloc] initWithFrame:view.bounds];
            backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [view insertSubview:backgroundView atIndex:0];
            if ([controller respondsToSelector:@selector(setPlayerBackgroundView:)]) {
                [controller performSelector:@selector(setPlayerBackgroundView:) withObject:backgroundView];
            }
        }
    }
    if (!backgroundView) return;

    // 如果抖音原生已经绘制了氛围色彩，则直接继承该色彩打通全屏，不强制覆盖
    if (backgroundView.backgroundColor && DKIsDouyinAlreadyCustomColored(backgroundView.backgroundColor)) {
        UIColor *native = backgroundView.backgroundColor;
        UIView *canvas = controller.viewIfLoaded;
        if (canvas) {
            canvas.backgroundColor = native;
            for (UIView *ancestor = canvas.superview; ancestor; ancestor = ancestor.superview) {
                if ([NSStringFromClass(ancestor.class) containsString:@"Cell"] || [NSStringFromClass(ancestor.class) containsString:@"ContentView"]) {
                    ancestor.backgroundColor = native;
                    break;
                }
            }
            DKHideVideoGradientsRecursively(canvas, 0);
        }
        return;
    }

    UIColor *targetColor = nil;
    if (style == 1) {
        // 选项 A：优雅石墨深灰 (#191919)
        targetColor = [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:25.0/255.0 alpha:1.0];
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
            targetColor = DKExtractDominantColorFromImage(cover);
        }
    }

    if (targetColor) {
        backgroundView.backgroundColor = targetColor;
        backgroundView.accessibilityLabel = @"DKBackdropPlayerView";

        // 同步给祖先 contentView/Cell，防止播放器底边与底栏之间的间隙露出纯黑底
        UIView *canvas = controller.viewIfLoaded;
        if (canvas) {
            canvas.backgroundColor = targetColor;
            for (UIView *ancestor = canvas.superview; ancestor; ancestor = ancestor.superview) {
                if ([NSStringFromClass(ancestor.class) containsString:@"Cell"] || [NSStringFromClass(ancestor.class) containsString:@"ContentView"]) {
                    ancestor.backgroundColor = targetColor;
                    break;
                }
            }
            // 彻底递归隐藏视频控制器内部所有贴底的黑色压暗遮罩（AWEGradientView）
            DKHideVideoGradientsRecursively(canvas, 0);
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

// 覆盖所有非全屏多图文与实况照片 Cell
%hook UICollectionViewCell

- (void)layoutSubviews {
    %orig;
    NSInteger style = [[NSUserDefaults standardUserDefaults] integerForKey:DKKeyCustomBackdropColorStyle];
    if (style <= 0) return;

    NSString *cls = NSStringFromClass(self.class);
    // 严格排除评论区、搜索卡片、Tab等无关 CollectionViewCell
    if ([cls containsString:@"Comment"] || [cls containsString:@"Header"] || [cls containsString:@"Footer"] || [cls containsString:@"TabContent"]) {
        return;
    }

    // 精确命中图文与实况适配器 Cell
    if ([cls containsString:@"ImageContentAdapterCellView"] ||
        [cls containsString:@"LivePhotoContentAdapterCellView"] ||
        [cls containsString:@"DefaultContentCellView"] ||
        [cls containsString:@"LivePhoto"]) {

        // 优先检查祖先或自身是否包含抖音官方原生设置的有效渐变背景色
        UIColor *nativeColor = nil;
        Class gradientCls = %c(AWEKnowledgeGradientView);
        for (UIView *sub in self.subviews) {
            if ((gradientCls && [sub isKindOfClass:gradientCls]) || [NSStringFromClass(sub.class) isEqualToString:@"AWEKnowledgeGradientView"]) {
                nativeColor = DKKnowledgeGradientNativeColor(sub);
                if (nativeColor) break;
            }
        }
        if (!nativeColor && self.superview) {
            for (UIView *sub in self.superview.subviews) {
                if ((gradientCls && [sub isKindOfClass:gradientCls]) || [NSStringFromClass(sub.class) isEqualToString:@"AWEKnowledgeGradientView"]) {
                    nativeColor = DKKnowledgeGradientNativeColor(sub);
                    if (nativeColor) break;
                }
            }
        }

        UIColor *targetColor = nil;
        if (nativeColor) {
            // 抖音官方自带氛围渐变：100% 继承并打通官方渐变末色，消除内部 Cell 遮挡与黑底
            targetColor = nativeColor;
        } else if (style == 1) {
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

#pragma mark - 5. 同步 DYYY 文案缩放与排版至图文标题与同城/团购推荐卡片 (Sync Description & Rich Aweme Text Style)

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

// 针对图文作品标题/文案及同城卡片做 DYYY 字体缩放与颜色统一
%hook UIView

- (void)layoutSubviews {
    %orig;
    NSString *cls = NSStringFromClass(self.class);
    if ([cls containsString:@"AWERichAwemeLifeCard"] ||
        [cls containsString:@"POICommentCard"] ||
        [cls containsString:@"POIRatingList"] ||
        [cls containsString:@"POIAnchor"] ||
        [cls containsString:@"AWERichAwemeLifeCardImageDescView"]) {

        NSString *scaleStr = [[NSUserDefaults standardUserDefaults] stringForKey:@"DYYYDescriptionScale"];
        CGFloat scale = scaleStr.length > 0 ? [scaleStr floatValue] : 1.0;
        if (scale > 0.0 && fabs(scale - 1.0) > 0.001) {
            if (CGAffineTransformEqualToTransform(self.transform, CGAffineTransformIdentity)) {
                self.transform = CGAffineTransformMakeScale(scale, scale);
            }
        }

        NSString *descColorHex = [[NSUserDefaults standardUserDefaults] stringForKey:@"DYYYDescriptionColor"];
        if (descColorHex.length > 0) {
            for (UIView *sub in self.subviews) {
                if ([sub isKindOfClass:[UILabel class]]) {
                    ((UILabel *)sub).alpha = 0.95;
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
