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

// 首页、朋友页、好友聊天页、搜索页、其他用户作品页统一由这一个开关控制。
static NSString *const DKKeyVideoFullscreen = @"DYKillerVideoFullscreen";
// 隐藏视频播放进度条但保留拖动热区；未写入时默认开启。
static NSString *const DKKeyHideVideoProgress = @"DYKillerHideVideoProgress";
// 0 关闭 / 1 轻 / 2 标准 / 3 强。
static NSString *const DKKeyVideoCaptionContrast = @"DYKillerVideoCaptionContrast";

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

#pragma mark - 功能组：搜索

// 在搜索中间页创建前移除猜你喜欢/热榜 Tab，阻止对应 Lynx 榜单资源加载。
static NSString *const DKKeyHideSearchTrendingBoard = @"DYKillerHideSearchTrendingBoard";
// 搜索中间页隐藏“猜你想搜”推荐词区域，保留历史搜索与热榜。
static NSString *const DKKeyHideSearchRecommend = @"DYKillerHideSearchRecommend";

#pragma mark - 功能组：调试工具

static NSString *const DKKeyDebugInspectorEnabled = @"DYKillerDebugInspectorEnabled";

#endif /* DKKeys_h */
