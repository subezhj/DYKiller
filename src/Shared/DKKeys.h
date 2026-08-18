//
//  DKKeys.h
//  集中管理所有 NSUserDefaults 开关键与插件元信息。
//  开关键字符串用于 NSUserDefaults 持久化。
//

#ifndef DKKeys_h
#define DKKeys_h

#import <Foundation/Foundation.h>

#ifndef DK_VERSION
#error DK_VERSION must be injected by Makefile from control Version.
#endif

#pragma mark - 功能组：视频全屏

// 全屏模式：0 关闭 / 1 满屏填充 (画面无黑边) / 2 原比例无损 (画面零裁切)
static NSString *const DKKeyVideoFullscreenMode = @"DYKillerVideoFullscreenMode";
// 首页、朋友页、好友聊天页、搜索页、其他用户作品页统一由这一个开关控制。
static NSString *const DKKeyVideoFullscreen = @"DYKillerVideoFullscreen";
// 隐藏视频播放进度条但保留拖动热区；未写入时默认开启。
static NSString *const DKKeyHideVideoProgress = @"DYKillerHideVideoProgress";
// 0 关闭 / 1 轻 / 2 标准 / 3 强。
static NSString *const DKKeyVideoCaptionContrast = @"DYKillerVideoCaptionContrast";
// 开启 Metal GPU 画面边缘锐化（提升低分辨率/压缩视频清晰度）
static NSString *const DKKeyMetalSharpeningEnabled = @"DYKillerMetalSharpeningEnabled";
// 开启 Metal Vibrant 画面色彩对比度与饱和度调谐
static NSString *const DKKeyMetalVibrantColorEnabled = @"DYKillerMetalVibrantColorEnabled";
// 开启非侵入式流体手势（双指捏合切清屏 / 双指轻击切倍速，0 悬浮图标）
static NSString *const DKKeyFluidGesturesEnabled = @"DYKillerFluidGesturesEnabled";
// 开启 iOS 原生 AVPlayer 硬件解码引擎（实验性：极低功耗与内存，原生锁屏/画中画融合）
static NSString *const DKKeyForceNativeAVPlayer = @"DYKillerForceNativeAVPlayer";
// 极简控件模式：隐去播放界面冗余挂件与无用浮层，提升视觉清爽度与渲染性能。
static NSString *const DKKeyZenFeedUIEnabled = @"DYKillerZenFeedUIEnabled";
// 清屏与放大模式保留视频进度条：捏合切清屏时保留底部完整/可拖拽进度条。
static NSString *const DKKeyKeepProgressInCleanMode = @"DYKillerKeepProgressInCleanMode";

#pragma mark - 功能组：评论区

static NSString *const DKKeyCommentHideBottomBar = @"DYKillerHideCommentBottomBar";
static NSString *const DKKeyCommentMediaCleanBottomBar = @"DYKillerCommentMediaCleanBottomBar";
static NSString *const DKKeyCommentGlass         = @"DYKillerCommentGlass";
// 只在评论玻璃总开关开启时生效；默认关闭即使用系统 Regular 材质。
static NSString *const DKKeyCommentGlassClear    = @"DYKillerCommentGlassClear";
// 0 默认 / 1 12pt / 2 20pt / 3 28pt / 4 36pt。
static NSString *const DKKeyCommentTopRadius     = @"DYKillerCommentTopRadius";

#pragma mark - 功能组：分享

static NSString *const DKKeySharePanelGlass      = @"DYKillerSharePanelGlass";
// 只在分享面板玻璃总开关开启时生效；默认关闭即使用系统 Regular 材质。
static NSString *const DKKeySharePanelGlassClear = @"DYKillerSharePanelGlassClear";

#pragma mark - 功能组：应用内通知

static NSString *const DKKeyInnerNotiGlass      = @"DYKillerInnerNotiGlass";
// 只在通知玻璃总开关开启时生效；默认关闭即使用系统 Regular 材质。
static NSString *const DKKeyInnerNotiGlassClear = @"DYKillerInnerNotiGlassClear";
// 0–100：0 为抖音原圆角，100 为胶囊。未写入时按 100。
static NSString *const DKKeyInnerNotiCorner     = @"DYKillerInnerNotiCorner";

#pragma mark - 功能组：底栏

static NSString *const DKKeyGlassTabBar      = @"DYKillerGlassTabBar";
static NSString *const DKKeyGlassTabBarClear = @"DYKillerGlassTabBarClear";
// 按底栏每个按钮下方内容的明暗分别切换模板标题颜色。
static NSString *const DKKeyGlassTabBarAutoTint = @"DYKillerGlassTabBarAutoTint";
// 底部交互与进度条抬升高度（0 关闭 / 1 抬升 4pt / 2 抬升 8pt / 3 抬升 12pt / 4 抬升 16pt）
static NSString *const DKKeyInteractionBottomLiftOffset = @"DYKillerInteractionBottomLiftOffset";
// 完全隐藏主底栏及其悬浮玻璃效果
static NSString *const DKKeyHideBottomBar    = @"DYKillerHideBottomBar";

#pragma mark - 功能组：音频可视化

// 两项都是单选，用对话框选，故存整数而非 BOOL。
// 位置：0 关闭 / 1 胶囊上方水平 / 2 胶囊整栏环绕 / 3 拍摄圆键环绕
static NSString *const DKKeyAudioVizPosition = @"DYKillerAudioVizPosition";
// 形态：0 离散条 / 1 连续流体
static NSString *const DKKeyAudioVizStyle = @"DYKillerAudioVizStyle";

#pragma mark - 功能组：播放体验

static NSString *const DKKeyDetailHideBottomBar = @"DYKillerHideChatVideoBottomBar";
static NSString *const DKKeyHideFollowButton     = @"DYKillerHideFollowButton";
static NSString *const DKKeyHideMusicInfo        = @"DYKillerHideMusicInfo";
// 只隐藏右下角音乐按钮上的“拍同款/听抖音”等引导文字，保留按钮本体。
static NSString *const DKKeyHideMusicButtonText  = @"DYKillerHideMusicButtonText";
// 清除视频底部 40pt 合集条背景，保留内容与点击。
static NSString *const DKKeyTransparentMixBar    = @"DYKillerTransparentMixBar";

#pragma mark - 功能组：个人主页

static NSString *const DKKeyProfileHideUGCGuide = @"DYKillerHideProfileUGCGuide";
// 隐藏个人主页顶部的“新访客”提示卡片与入口
static NSString *const DKKeyProfileHideVisitorGuide = @"DYKillerHideProfileVisitorGuide";

#pragma mark - 功能组：可读性

// 可读性增强目标：0 仅视频描述文案 / 1 仅作者用户名 / 2 全量增强（视频文案 + 作者用户名）
static NSString *const DKKeyReadabilityTarget = @"DYKillerReadabilityTarget";

#pragma mark - 功能组：搜索

// 在搜索中间页创建前移除猜你喜欢/热榜 Tab，阻止对应 Lynx 榜单资源加载。
static NSString *const DKKeyHideSearchTrendingBoard = @"DYKillerHideSearchTrendingBoard";
// 搜索中间页隐藏“猜你想搜”推荐词区域，保留历史搜索与热榜。
static NSString *const DKKeyHideSearchRecommend = @"DYKillerHideSearchRecommend";

#pragma mark - 功能组：净化与网络拦截

// 拦截广告推送、监控埋点、活动挂件及垃圾资源联网请求。
static NSString *const DKKeyBlockJunkResources = @"DYKillerBlockJunkResources";
// 屏蔽主页与全屏营销活动浮窗/悬浮球挂件（如春节/中秋/红包雨/任务挂件）。
static NSString *const DKKeyBlockHomePagePendants = @"DYKillerBlockHomePagePendants";
// 屏蔽电商带货与广告营销（带货黄色小黄车/商品卡片/广告落地页/Tetris组件）。
static NSString *const DKKeyBlockEcommerceMarketing = @"DYKillerBlockEcommerceMarketing";
// 拦截冗余 Lynx 动态前端卡片（阻止后台下发加载非核心 Lynx 浮层与模板）。
static NSString *const DKKeyBlockLynxComponents = @"DYKillerBlockLynxComponents";
// 屏蔽视频挂件与拍同款贴纸（隐藏 Feed 营销卡片、投票与互动贴纸，保留文案与操作栏）。
static NSString *const DKKeyHideFeedStickersAndWidgets = @"DYKillerHideFeedStickersAndWidgets";
// 拦截营销挂件、短剧水印、电商与活动浮层图层（不影响正常视频预加载）。
static NSString *const DKKeyBlockMarketingLayers = @"DYKillerBlockMarketingLayers";
// Metal 渲染管道极简优化：剥离渲染层冗余渐变遮罩，提升 GPU 帧合成效率与滑动流畅度。
static NSString *const DKKeyOptimizeRenderPipeline = @"DYKillerOptimizeRenderPipeline";

#pragma mark - 功能组：画中画与灵动岛

// 灵动岛媒体直达与后台唤醒：在后台或锁屏时激活系统灵动岛媒体波形，点击直达抖音前台
static NSString *const DKKeyMediaIslandEnabled = @"DYKillerMediaIslandEnabled";
// 灵动岛 ActivityKit 实时活动直达：在 iOS 16.1+ 灵动岛展示专属 Live Activity 控件，支持胶囊与展开态快捷秒开
static NSString *const DKKeyLiveActivityIslandEnabled = @"DYKillerLiveActivityIslandEnabled";
// 画中画悬浮直达秒开：退后台时开启系统画中画小窗，点击画中画恢复按钮 100% 绝对无条件秒开切回抖音
static NSString *const DKKeyPiPQuickLaunchEnabled = @"DYKillerPiPQuickLaunchEnabled";

#pragma mark - 功能组：新特性与实验性功能 (Experimental)

// [实验性] ProMotion 120Hz 极速触控响应：优化手势时钟优先级，消除滑动短视频与列表的手势抖动与延迟
static NSString *const DKKeyProMotionFluidScrollEnabled = @"DYKillerProMotionFluidScrollEnabled";
// [实验性] 智能后台冻结与内存防杀 (Anti-Jetsam)：退后台深度压缩 Lynx 与网络缓存，杜绝系统杀后台，实现前台秒开
static NSString *const DKKeyBackgroundAntiJetsamEnabled = @"DYKillerBackgroundAntiJetsamEnabled";
// [实验性] 非全屏视频与图文自定义背景：0 默认 / 1 优雅深灰(#191919) / 2 视频主色自适应
static NSString *const DKKeyCustomBackdropColorStyle = @"DYKillerCustomBackdropColorStyle";

#pragma mark - 功能组：调试工具

static NSString *const DKKeyDebugInspectorEnabled = @"DYKillerDebugInspectorEnabled";
static NSString *const DKKeyNetworkLoggerEnabled  = @"DYKillerNetworkLoggerEnabled";

#endif /* DKKeys_h */
