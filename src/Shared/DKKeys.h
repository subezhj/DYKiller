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

// 评论区回复底栏（单选，整数）：0 显示 / 1 隐藏（原位置可点击回复）/ 2 移除（点击交给列表）；后两档列表均铺满。
static NSString *const DKKeyCommentReplyBottomBarMode = @"DYKillerCommentReplyBottomBarMode";
static NSString *const DKKeyCommentAIParseMode = @"DYKillerCommentAIParseMode";
static NSString *const DKKeyCommentSearchAnchorMode = @"DYKillerCommentSearchAnchorMode";
static NSString *const DKKeyCommentLunaAnchorMode = @"DYKillerCommentLunaAnchorMode";
static NSString *const DKKeyCommentLocationMode = @"DYKillerCommentLocationMode";
static NSString *const DKKeyCommentGameAnchorMode = @"DYKillerCommentGameAnchorMode";
static NSString *const DKKeyCommentPlayerDiscussionMode = @"DYKillerCommentPlayerDiscussionMode";
static NSString *const DKKeyCommentStoreReviewMode = @"DYKillerCommentStoreReviewMode";
static NSString *const DKKeyCommentSeriesAnchorMode = @"DYKillerCommentSeriesAnchorMode";
// 移除评论列表中的「评论氛围是否满意」评价卡片。
static NSString *const DKKeyRemoveCommentSurvey = @"DYKillerRemoveCommentSurvey";
static NSString *const DKKeyCommentMediaCleanBottomBar = @"DYKillerCommentMediaCleanBottomBar";
// 材质单选（DKMakeGlassChoice）：总开关 + 清透档两个 BOOL，清透档关即系统 Regular。
static NSString *const DKKeyCommentGlass         = @"DYKillerCommentGlass";
static NSString *const DKKeyCommentGlassClear    = @"DYKillerCommentGlassClear";
// 0 默认 / 1 12pt / 2 20pt / 3 28pt / 4 36pt。
static NSString *const DKKeyCommentTopRadius     = @"DYKillerCommentTopRadius";

#pragma mark - 功能组：分享

// 材质单选（DKMakeGlassChoice）：总开关 + 清透档两个 BOOL，清透档关即系统 Regular。
static NSString *const DKKeySharePanelGlass      = @"DYKillerSharePanelGlass";
static NSString *const DKKeySharePanelGlassClear = @"DYKillerSharePanelGlassClear";

#pragma mark - 功能组：应用内通知

// 材质单选（DKMakeGlassChoice）：总开关 + 清透档两个 BOOL，清透档关即系统 Regular。
static NSString *const DKKeyInnerNotiGlass      = @"DYKillerInnerNotiGlass";
static NSString *const DKKeyInnerNotiGlassClear = @"DYKillerInnerNotiGlassClear";
// 0–100：0 为抖音原圆角，100 为胶囊。未写入时按 100。
static NSString *const DKKeyInnerNotiCorner     = @"DYKillerInnerNotiCorner";

#pragma mark - 功能组：底栏

// 材质单选（DKMakeGlassChoice）：总开关 + 清透档两个 BOOL，清透档关即系统默认磨砂。
static NSString *const DKKeyGlassTabBar      = @"DYKillerGlassTabBar";
static NSString *const DKKeyGlassTabBarClear = @"DYKillerGlassTabBarClear";
// 按底栏每个按钮下方内容的明暗分别切换模板标题颜色。
static NSString *const DKKeyGlassTabBarAutoTint = @"DYKillerGlassTabBarAutoTint";
// 底部交互与进度条抬升高度（0 关闭 / 1 抬升 4pt / 2 抬升 8pt / 3 抬升 12pt / 4 抬升 16pt）
static NSString *const DKKeyInteractionBottomLiftOffset = @"DYKillerInteractionBottomLiftOffset";
// 完全隐藏主底栏及其悬浮玻璃效果
static NSString *const DKKeyHideBottomBar    = @"DYKillerHideBottomBar";
// 自定义拍摄图标：图片本体存文件（见 DKPlusIcon.xm），这个键只作设置项 identifier，
// NSUserDefaults 里不写值。是否使用由「拍摄按钮」（DKKeyPlusStyle）选「自定义图片」决定。
static NSString *const DKKeyPlusIcon         = @"DYKillerPlusIcon";
// 底栏项目移除：每项一个 BOOL 键，前缀 + 抖音 tabID（见 DKTabBarRemoval.xm）。
static NSString *const DKKeyBottomBarHidePrefix = @"DYKillerHideBottomBar.";
static NSString *const DKKeyHidePlusButton      = @"DYKillerHideBottomBar.homepage_publish";
// 设置主页入口的 identifier，NSUserDefaults 里不写值。
static NSString *const DKKeyBottomBar           = @"DYKillerBottomBar";

#pragma mark - 功能组：外观定制

// 底栏样式（单选，整数）：0 默认 / 1 单图标 / 2 图标+文字，作用于首页、朋友或商城、消息、我。
static NSString *const DKKeyTabBarStyle = @"DYKillerTabBarStyle";
// 拍摄按钮（单选，整数）：0 默认 / 1 新图标 / 2 新双色图标 / 3 自定义图片（图片本体见 DKKeyPlusIcon）。
static NSString *const DKKeyPlusStyle   = @"DYKillerPlusStyle";
// 底栏文字：每项一个字符串键，前缀 + 抖音 tabID；未设置即抖音默认文字。
static NSString *const DKKeyTabTitlePrefix       = @"DYKillerTabBarTitle.";
static NSString *const DKKeyTabTitleHome         = @"DYKillerTabBarTitle.homepage_home";
static NSString *const DKKeyTabTitleFriends      = @"DYKillerTabBarTitle.homepage_familiar";
static NSString *const DKKeyTabTitleMall         = @"DYKillerTabBarTitle.homepage_mall";
static NSString *const DKKeyTabTitleNotification = @"DYKillerTabBarTitle.homepage_notification";
static NSString *const DKKeyTabTitleProfile      = @"DYKillerTabBarTitle.homepage_profile";

#pragma mark - 功能组：互动按钮

// 透明度：0–100，默认 100；缩放：常规 50–100，默认 100；
// 显示方式：0 显示 / 1 隐藏（不显示、仍可点击）/ 2 移除（不显示、不可点击，所在行收拢）。
// 缩放与上移的范围登记在 DKAdjustRange.m，开启「扩展所有缩放与位移」后放宽。
static NSString *const DKKeyInteractionIconAlpha  = @"DYKillerInteractionIconAlpha";
static NSString *const DKKeyInteractionLabelAlpha = @"DYKillerInteractionLabelAlpha";
static NSString *const DKKeyAvatarAlpha           = @"DYKillerAvatarAlpha";
static NSString *const DKKeyMusicAlpha            = @"DYKillerMusicAlpha";
static NSString *const DKKeyInteractionScale      = @"DYKillerInteractionScale";
static NSString *const DKKeyAvatarScale            = @"DYKillerAvatarScale";
static NSString *const DKKeyMusicScale             = @"DYKillerMusicScale";
static NSString *const DKKeyInteractionDisplay    = @"DYKillerInteractionDisplay";
static NSString *const DKKeyAvatarDisplay         = @"DYKillerAvatarDisplay";
static NSString *const DKKeyMusicDisplay          = @"DYKillerMusicDisplay";
// 头像下方关注入口：0 显示 / 1 隐藏（仍可点击）/ 2 移除（与已关注作者时一致）。
static NSString *const DKKeyFollowButtonDisplay   = @"DYKillerFollowButtonDisplayMode";
// 互动区域上移：0–100 pt，默认 0（抖音原位）；头像、互动按钮、音乐整体上移。
static NSString *const DKKeyInteractionOffset     = @"DYKillerInteractionOffset";

#pragma mark - 功能组：昵称文案

// 视频左下昵称一行与文案及其余信息行。透明度：0–100，默认 100；缩放：常规 25–100，默认 100；
// 上移：常规 0–100 pt，默认 0。缩放与上移的范围登记在 DKAdjustRange.m。
static NSString *const DKKeyNicknameAlpha    = @"DYKillerNicknameAlpha";
static NSString *const DKKeyDescriptionAlpha = @"DYKillerDescriptionAlpha";
static NSString *const DKKeyNicknameScale    = @"DYKillerNicknameScale";
static NSString *const DKKeyDescriptionScale = @"DYKillerDescriptionScale";
static NSString *const DKKeyInfoOffset       = @"DYKillerInfoOffset";

#pragma mark - 功能组：音频可视化

// 两项都是单选，用对话框选，故存整数而非 BOOL。
// 位置：0 关闭 / 1 胶囊上方水平 / 2 胶囊整栏环绕 / 3 拍摄圆键环绕
static NSString *const DKKeyAudioVizPosition = @"DYKillerAudioVizPosition";
// 形态：0 离散条 / 1 连续流体
static NSString *const DKKeyAudioVizStyle = @"DYKillerAudioVizStyle";

#pragma mark - 功能组：播放体验

static NSString *const DKKeyDoubleTapOpenComment = @"DYKillerDoubleTapOpenComment";
static NSString *const DKKeyDetailHideBottomBar = @"DYKillerHideChatVideoBottomBar";
static NSString *const DKKeyHideFollowButton     = @"DYKillerHideFollowButton";
static NSString *const DKKeyHideMusicInfo        = @"DYKillerHideMusicInfo";
// 只隐藏右下角音乐按钮上的“拍同款/听抖音”等引导文字，保留按钮本体。
static NSString *const DKKeyHideMusicButtonText  = @"DYKillerHideMusicButtonText";
// 清除视频底部 40pt 合集条背景，保留内容与点击。
static NSString *const DKKeyTransparentMixBar    = @"DYKillerTransparentMixBar";
// 所有视频常态下都显示底部进度条。
static NSString *const DKKeyProgressAlwaysVisible = @"DYKillerProgressAlwaysVisible";
// 进度条旁的已播 / 总时长：0 关闭 / 1 两端（与进度条同一行）/ 2 右端 · 上方 / 3 右端 · 下方 / 4 两端 · 上方 / 5 两端 · 下方
static NSString *const DKKeyProgressTimeStyle = @"DYKillerProgressTimeStyle";

#pragma mark - 功能组：播放页精简

// 每项单选，存整数：0 显示 / 1 隐藏（不显示、仍可点击，位置保留）/ 2 移除（不显示、不可点击，按抖音原生排布收拢）。
static NSString *const DKKeyPlaybackFullscreenMode         = @"DYKillerPlaybackFullscreenMode";
static NSString *const DKKeyPlaybackDanmakuMode            = @"DYKillerPlaybackDanmakuMode";
// 文案上方
static NSString *const DKKeyPlaybackOtherUserRecommendMode = @"DYKillerPlaybackOtherUserRecommendMode";
static NSString *const DKKeyPlaybackFriendRecommendMode    = @"DYKillerPlaybackFriendRecommendMode";
static NSString *const DKKeyPlaybackFriendShareMode        = @"DYKillerPlaybackFriendShareMode";
static NSString *const DKKeyPlaybackSelectedMode           = @"DYKillerPlaybackSelectedMode";
static NSString *const DKKeyPlaybackGameTagMode            = @"DYKillerPlaybackGameTagMode";
static NSString *const DKKeyPlaybackMusicAnchorMode        = @"DYKillerPlaybackMusicAnchorMode";
static NSString *const DKKeyPlaybackPropEffectMode         = @"DYKillerPlaybackPropEffectMode";
static NSString *const DKKeyPlaybackJianyingMode           = @"DYKillerPlaybackJianyingMode";
static NSString *const DKKeyPlaybackLocationMode           = @"DYKillerPlaybackLocationMode";
static NSString *const DKKeyPlaybackStoreMode              = @"DYKillerPlaybackStoreMode";
// 昵称右侧
static NSString *const DKKeyPlaybackChapterHighlightsMode  = @"DYKillerPlaybackChapterHighlightsMode";
static NSString *const DKKeyPlaybackCoCreatorMode          = @"DYKillerPlaybackCoCreatorMode";
static NSString *const DKKeyPlaybackSlidesTagMode          = @"DYKillerPlaybackSlidesTagMode";
// 文案下方
static NSString *const DKKeyPlaybackRelatedSearchMode      = @"DYKillerPlaybackRelatedSearchMode";
static NSString *const DKKeyPlaybackRiskNoticeMode         = @"DYKillerPlaybackRiskNoticeMode";
static NSString *const DKKeyPlaybackVideoCollectionMode    = @"DYKillerPlaybackVideoCollectionMode";
static NSString *const DKKeyPlaybackHotspotMode            = @"DYKillerPlaybackHotspotMode";
static NSString *const DKKeyPlaybackMusicInfoMode          = @"DYKillerPlaybackMusicInfoMode";
static NSString *const DKKeyPlaybackQuickReplyMode         = @"DYKillerPlaybackQuickReplyMode";
static NSString *const DKKeyPlaybackAppDownloadMode        = @"DYKillerPlaybackAppDownloadMode";

#pragma mark - 功能组：内容过滤

static NSString *const DKKeyFilterLowLikes = @"DYKillerFilterLowLikes";
static NSString *const DKKeyMinimumLikes = @"DYKillerMinimumLikes";
static NSString *const DKKeyRemoveRecommendedLive = @"DYKillerRemoveRecommendedLive";
static NSString *const DKKeyFilterRecommendedMusic = @"DYKillerFilterRecommendedMusic";
static NSString *const DKKeyFilterRecommendedHotspot = @"DYKillerFilterRecommendedHotspot";
static NSString *const DKKeyFilterAds = @"DYKillerFilterAds";

#pragma mark - 功能组：顶部频道

// 每个频道一个 BOOL 键：前缀 + channelID。
static NSString *const DKKeyTopChannelHidePrefix = @"DYKillerHideTopChannel.";
// 扫描到的频道目录：NSArray<NSDictionary>，每项含 id/name/title/locked/present。
static NSString *const DKKeyTopChannelCatalog = @"DYKillerTopChannelCatalog";
// 设置主页入口的 identifier，NSUserDefaults 里不写值。
static NSString *const DKKeyTopChannels = @"DYKillerTopChannels";

#pragma mark - 功能组：顶栏入口

// 单选，存整数：0 显示 / 1 隐藏（不显示、仍可点击）/ 2 移除（不显示、不可点击）。
static NSString *const DKKeyTopBarSideBarMode = @"DYKillerTopBarSideBarMode";
static NSString *const DKKeyTopBarSearchMode  = @"DYKillerTopBarSearchMode";
// 屏蔽在最左侧频道右滑展开左侧栏。
static NSString *const DKKeyBlockSideBarSwipe = @"DYKillerBlockSideBarSwipe";
// 顶栏透明度：0–100，默认 100；作用于左侧栏入口、全部频道与搜索图标。
static NSString *const DKKeyTopBarAlpha       = @"DYKillerTopBarAlpha";

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
// 画中画悬浮直达秒开：退后台时开启系统画中画小窗，点击画中画恢复按钮 100% 绝对无条件秒开切回抖音
static NSString *const DKKeyPiPQuickLaunchEnabled = @"DYKillerPiPQuickLaunchEnabled";

#pragma mark - 功能组：新特性与实验性功能 (Experimental)

// [实验性] ProMotion 120Hz 极速触控响应：优化手势时钟优先级，消除滑动短视频与列表的手势抖动与延迟
static NSString *const DKKeyProMotionFluidScrollEnabled = @"DYKillerProMotionFluidScrollEnabled";
// [实验性] 智能后台冻结与内存防杀 (Anti-Jetsam)：退后台深度压缩 Lynx 与网络缓存，杜绝系统杀后台，实现前台秒开
static NSString *const DKKeyBackgroundAntiJetsamEnabled = @"DYKillerBackgroundAntiJetsamEnabled";
// [实验性] 非全屏视频与图文自定义背景：0 默认 / 1 优雅深灰(#191919) / 2 视频主色自适应
static NSString *const DKKeyCustomBackdropColorStyle = @"DYKillerCustomBackdropColorStyle";
// [实验性] 同城/团购推荐文案与 DYYY 样式统一：自动统一 POI 推荐卡片及评价文案的排版与颜色
static NSString *const DKKeyPOICommentStyleUnified = @"DYKillerPOICommentStyleUnified";

#pragma mark - 功能组：媒体保存

// 作品长按面板里的保存项；保存视频 / 保存当前图片开启时移除原生「保存至相册」。
static NSString *const DKKeyMediaSaveVideo         = @"DYKillerMediaSaveVideo";
static NSString *const DKKeyMediaSaveCurrentImage  = @"DYKillerMediaSaveCurrentImage";
static NSString *const DKKeyMediaSaveAllImages     = @"DYKillerMediaSaveAllImages";
static NSString *const DKKeyMediaSaveCover         = @"DYKillerMediaSaveCover";
static NSString *const DKKeyMediaSaveMusic         = @"DYKillerMediaSaveMusic";
// 评论长按「保存到相册」改由插件保存图片、实况与视频评论。
static NSString *const DKKeyMediaSaveComment       = @"DYKillerMediaSaveComment";
// 评论表情：长按菜单与单击后的表情页增加「保存表情包」。
static NSString *const DKKeyMediaSaveCommentSticker = @"DYKillerMediaSaveCommentSticker";
// 抖音原生的评论图片 / 实况保存不带水印。
static NSString *const DKKeyCommentImageNoWatermark     = @"DYKillerCommentImageNoWatermark";
static NSString *const DKKeyCommentLivePhotoNoWatermark = @"DYKillerCommentLivePhotoNoWatermark";
// 私信表情消息长按菜单、单击后的表情页、表情面板长按预览增加「保存表情包」。
static NSString *const DKKeyMediaSaveChatSticker   = @"DYKillerMediaSaveChatSticker";
static NSString *const DKKeyMediaSaveHaptic        = @"DYKillerMediaSaveHaptic";
// 保存提示的材质单选（DKMakeGlassChoice）：总开关关时为普通模糊提示，开时按清透档取 Regular / Clear。
static NSString *const DKKeyMediaSaveGlass         = @"DYKillerMediaSaveGlass";
static NSString *const DKKeyMediaSaveGlassClear    = @"DYKillerMediaSaveGlassClear";

#pragma mark - 功能组：备份工具

// 备份工具页的四个动作行，只作设置项 identifier，NSUserDefaults 里不写值。
static NSString *const DKKeyBackupExport  = @"DYKillerBackupExport";
static NSString *const DKKeyBackupRestore = @"DYKillerBackupRestore";
static NSString *const DKKeyBackupUndo    = @"DYKillerBackupUndo";
static NSString *const DKKeyBackupReset   = @"DYKillerBackupReset";
// 上次导出备份的时间（NSDate）。不属于任何设置项：不进备份，恢复默认也不清。
static NSString *const DKKeyBackupLastExportDate = @"DYKillerBackupLastExportDate";

#pragma mark - 设置页

// 「液态玻璃 (iOS26+)」子页入口的 identifier，供玻璃守卫在低系统灰显整个入口；不写值。
static NSString *const DKKeySettingsPageGlass = @"DYKillerPageLiquidGlass";

#pragma mark - 功能组：调整范围

// 扩展所有缩放与位移：开启后 DKAdjustRange 登记的各项按扩展范围生效。开启前须确认，不进备份。
static NSString *const DKKeyAdjustRangeExtended = @"DYKillerAdjustRangeExtended";

#pragma mark - 功能组：调试工具

static NSString *const DKKeyDebugInspectorEnabled = @"DYKillerDebugInspectorEnabled";
static NSString *const DKKeyNetworkLoggerEnabled  = @"DYKillerNetworkLoggerEnabled";

#endif /* DKKeys_h */
