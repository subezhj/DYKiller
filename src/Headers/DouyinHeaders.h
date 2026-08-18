//
//  DouyinHeaders.h
//  抖音私有类的最小前向声明（只声明本插件用到的成员）。
//  按"功能类 / 设置系统"分区；新增功能用到新类时在对应区追加即可。
//

#ifndef DouyinHeaders_h
#define DouyinHeaders_h

#import <UIKit/UIKit.h>

#pragma mark - 详情页视频功能组用到的类

@interface AWEAwemeDetailTableViewController : UIViewController
@property (nonatomic, copy) NSString *referString;
- (BOOL)canShowFixedBottomBar;
- (void)setBottomBarHidden:(BOOL)hidden;
- (NSString *)realReferString;
@end

@interface AWEAwemeIMDetailTableViewController : AWEAwemeDetailTableViewController   // 私信「分享视频」详情页专属表控制器（作用域判定用）
@end

@interface AWEMixVideoPanelDetailTableViewController : AWEAwemeDetailTableViewController
@property (nonatomic, strong) UIView *bottomBackgroundView;
@property (nonatomic, assign) BOOL isShowingRelatedMixViewController;
@end

@interface AWEVideoModel : NSObject                                 // 视频信息（取宽高判比例）
@property (nonatomic, strong) NSNumber *width;
@property (nonatomic, strong) NSNumber *height;
@end

@interface AWEAwemeModel : NSObject                                 // 单条内容模型
@property (nonatomic, strong) AWEVideoModel *video;
@property (nonatomic, assign) long long awemeType;
@property (nonatomic, assign) BOOL isAd;
@property (nonatomic, assign) BOOL isCommerce;
@property (nonatomic, assign) NSInteger adLinkType;
@end

@interface AWEFeedCellViewController : UIViewController
- (void)setModel:(id)model;
@end

// 视频+交互合并容器。其 .view 用于视频容器布局调整。
@interface AWEDPlayerViewController_Merge : UIViewController
@property (nonatomic, strong) AWEAwemeModel *model;                 // 取视频宽高做比例限幅
@property (nonatomic, assign) BOOL hasInlandscape;                  // 横屏视频判据（横屏排除全屏）
@property (nonatomic, strong) UIView *gradientBackgroundView;       // 评论 shrink 会调整该渐变透明度
@property (nonatomic, copy) NSString *referString;                  // 页面来源，用于限定搜索详情页
@property (nonatomic, strong) UIView *contentView;
- (BOOL)isInLandscapeFeedStatus;
- (void)videoDidShrink;
- (BOOL)isPlaying;
- (void)play;                                                       // 真正的播放入口，经 videoShouldPlay
- (void)pause;
- (BOOL)shouldPreventPlay;                                          // videoShouldPlay 的第一条判据
- (BOOL)videoShouldPlay;                                            // 播放前的总闸门
@end

// 视频播放控制器。抖音把横屏智能背景色画在 playerBackgroundView 上（插入其 view 的最底层）。
// playerWillLoopPlaying: 是播放引擎的循环回调，本类自己实现（发 OnPlayerWillLoopPlayingEvent、
// 写 loopTimes、finishLogIfNeeded），播完一遍必到；它是 Merge 的子控制器。
@interface AWEPlayVideoViewController : UIViewController
@property (nonatomic, strong) UIView *playerBackgroundView;
- (void)playerWillLoopPlaying:(id)player;
@end

@interface AWEDPlayerProgressContainerView : UIView                // 进度条容器；底边压着一条纯黑细条
@end

@interface AWEFeedProgressSlider : UIView                              // video 页新增的播放进度滑块
@end

@interface AWEElementStackView : UIView                                // HUD 左侧文案栈与右侧按钮栈
@end

@interface AWEPlayInteractionDescriptionLabel : UILabel                // 左侧视频文案
@end

@interface AWEMusicCoverButton : UIButton                               // 右下角音乐封面按钮
@property (nonatomic, strong) UILabel *guidanceLabel;
@end

@interface AWEPlayInteractionSingleSongMusicStyleView : UIView
@property (nonatomic, strong) UILabel *listenTitleLabel;
@property (nonatomic, strong) UILabel *playInteractionLabel;
@end

@interface AWEGradientView : UIView                                // HUD 可读性压暗渐变
@end

@interface AWEIMFeedVideoQuickReplayInputViewController : UIViewController  // 底部快捷回复栏控制器
@end

@interface AWEPlayInteractionViewController : UIViewController      // HUD 控制器；评论态其 view 顶部会被塞状态栏黑底，全屏时需压掉
@property (nonatomic, assign) BOOL hideMusicInfo;
@property (nonatomic, copy) NSString *referString;
@end

// 图文整页的背景层，挂在图文列表控制器 view 的直接子层，与内容类型无关。
// +layerClass 是 CAGradientLayer；全屏时用 transform 纵向拉伸以延伸到底栏（不改 frame）。
@interface AWEKnowledgeGradientView : UIView
@end

// 图文横滑内容集合；完成 visibleCells 布局后同步贴底压暗，并解除其祖先链上的实际裁剪点。
@interface AWEStoryContainerCollectionView : UICollectionView
@end

// 图文的顶层容器控制器。首页、朋友页、好友聊天页三种图文列表实现都挂在它下面，
// 且全部类导出里只有它声明 updateShrinkState:——那是图文版的 videoDidShrink。
@interface RichContentContainerViewController : UIViewController
@property (nonatomic, readonly, strong) UIViewController *contentListViewController;  // 图文列表实现，背景渐变挂在它 view 下
- (void)updateShrinkState:(BOOL)shrink insets:(UIEdgeInsets)insets animated:(BOOL)animated;
@end

// 视频表的基类。首页/朋友页的 AWEFeedTableView 与好友聊天/搜索/其他用户主页的
// AWEAwemeDetailTableView 都从它派生；被底栏压掉一个底栏高时就是视频不全屏的源头层。
@interface AWEFeedDataSafeTableView : UITableView
@end

@interface AWEFeedTableView : AWEFeedDataSafeTableView              // 首页 / 朋友页
@end

@interface AWEAwemeDetailTableView : AWEFeedDataSafeTableView         // 好友聊天 / 搜索 / 个人主页作品页
@end

@interface AFDViewedBottomView : UIView
@property (nonatomic, strong) UIView *effectView;
@end

@interface AWEIMFeedBottomQuickEmojiInputBar : UIView
@end


// 直播预览的四层容器（背景 / 画面 / 内容 / 控件）。画面与背景按窗口尺寸排，chrome 挂在容器高度上：
// 表被撑高后容器跟着变高，贴底的那套元素就整体下移一个底栏高，需要叠 transform 抬回去。
// 具名槽位除 bottomDarkWatermark 外均为调试探针采集用。
@interface AWELivePreStream4LayerContainerView : UIView
@property (nonatomic, strong) UIImageView *bottomDarkWatermark;     // 底部暗水印，抬升目标之一
@property (nonatomic, readonly, strong) UIView *gradientContainerView;
@property (nonatomic, readonly, strong) UIView *controlContainer;
@property (nonatomic, strong) UIView *leftContainer;
@property (nonatomic, strong) UIView *centerContainer;
@property (nonatomic, strong) UIView *bottomContainer;
@end

#pragma mark - 底栏功能组用到的类

// 抖音自绘底栏。它自身的 hidden/alpha 是抖音全部显隐逻辑的唯一汇聚点，可直接当镜像源。
@interface AWENormalModeTabBar : UITabBar
@end

@interface AWEFakeTabBar : UIView
@end

@interface AWENormalModeTabBarBlurView : UIView
@end

@interface AWETabBarSkinContainerView : UIView
@end

@interface AWETabBarSkinView : UIView
@end

@interface AWEHPTabBarButtonTransitionBackgroundView : UIView
@end

@interface _UITabBarContainerWrapperView : UIView
@end

@interface _UITabBarContainerView : UIView
@end



#pragma mark - 评论区功能组用到的类

@interface AWECommentContainerViewController : UIViewController
@end

// 评论图片大图页。主集合视图按 item 分页，底部输入栏是其根视图的独立子层。
// backButton 是左上角返回键，点击走 previewDismissByClickBackBtn。
@interface AWECommentMediaFeedViewController : UIViewController
@property (nonatomic, assign) long long currentIndex;
@property (nonatomic, strong) UIButton *backButton;
- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)previewDismissByClickBackBtn;
@end

// 大图页内部图片 Cell。mediaContainerView 承载静态图片或 Live Photo 预览。
@interface AWECommentMediaFeedImageCell : UICollectionViewCell
- (UIView *)mediaContainerView;
@end

// 评论区放大到全屏时被 push 上来的容器。它带整套 transition_* 协议方法，配 AWECommentFullScreenZoomTransition
// 与 CommentFullScreenZoomAnimator——是自定义交互式转场的目标，不能拦下这次 push 改用控制器包含：
// 转场框架在 push 之前已建好 context 并禁用交互，吞掉 %orig 它的完成回调就永远不来。
@interface AWEDPlayerFeedPlayerViewController : UIViewController
@property (nonatomic, strong) UIView *contentView;
@end

@interface AWECommentFullScreenContainerViewController : UIViewController
@end


// 视频侧的评论面板控制器。内嵌画中画（全屏评论区里把视频交出去、缩成右上角小窗）归它管，
// enableShowInnerPiPWhenFullScreen 是这条功能的唯一闸门：enter / show / exit /
// tryToPause / tryToPlay / viewDidLoad / commentVC 每个入口都先问它。
@interface AWEPlayInteractionCommentPanelController : NSObject
- (BOOL)enableShowInnerPiPWhenFullScreen;
@end

// 弹幕渲染层。抖音开评论面板时就是把这一层的 alpha 压成 0（实测半屏 / 全屏都是），
// 容器与各条弹幕视图本身不动。
@interface DDanmakuPlayerView : UIView
@end

@interface AWEListKitMagicCollectionView : UICollectionView
@end

@interface AWECommentInputBackgroundView : UIView                   // 详情页底部输入栏，是 AWECommentInputViewController 的根视图
@end

@interface AWEIMEmoticonPanelContainerView : UIView                 // 表情面板；评论区复用 IM 那一套，挂在输入容器里
@end

#pragma mark - 分享面板功能组用到的类

// DUX 底栏弹层外壳。contentView 是带 20pt 顶圆角的 DUXVisualEffectView，目前几乎不模糊。
@interface AWESharePanelContainerViewController : UIViewController
@end

@interface AWESharePanelViewController : UIViewController
- (void)awe_themeReload;
@end

// 第三行功能键。imageView 是 56×56 白圆+图标；smallImageView 导出里无图。
@interface AWESharePanelFunctionCell : UICollectionViewCell
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIImageView *smallImageView;
- (void)updateWithViewModel:(id)viewModel bigFontAdapter:(id)adapter;
- (void)updateImageViewWithViewModel:(id)viewModel;
@end

#pragma mark - 应用内通知功能组用到的类

@interface AWEInnerNotificationContainerView : UIView
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIStackView *contentContainerView;
- (void)renderModel:(id)model context:(id)context;
- (void)viewDidDisappear:(BOOL)animated reason:(long long)reason;
@end

@interface AWEInnerPushCommonView : UIView
@property (nonatomic, strong) UIView *leftExtraIconBackgroundView;
@property (nonatomic, strong) UIImageView *leftExtraIcon;
@property (nonatomic, strong) UIButton *rightActionButton;
@property (nonatomic, strong) UIStackView *middleContentTextStackView;
- (void)updateViewWithRequest:(id)request notificationContent:(id)content viewModel:(id)viewModel;
@end

#pragma mark - 播放体验功能组用到的类

@interface AWEPlayInteractionFollowPromptView : UIView             // 头像下方「关注(+)」容器；整视图仅含 + 图标
@end

#pragma mark - 垃圾资源与挂件拦截用到的类

@interface AWELuckyCatBannerView : UIView
@end

@interface _TtC21AWEIncentiveSwiftImpl29IncentivePendantContainerView : UIView
@end

@interface AWECommerceAnchorView : UIView
@end

@interface AWEPOITradeEntryAnchorView : UIView
@end

@interface AWECommercePendantView : UIView
@end

@interface UILynxView : UIView
@end

@interface BDXLynxView : UIView
@end

@interface AWEAwemePlayletWaterMarkView : UIView
@end

#pragma mark - 个人主页功能组用到的类


@interface AWEUserProfileUGCContributionGuideEmptyCollectionViewCell : UICollectionViewCell
@property (nonatomic, strong) UIView *bodyView;
+ (double)viewHeight;
@end

#pragma mark - 抖音设置系统（注入设置菜单用）

@interface AWESettingItemModel : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, assign) NSInteger type;
@property (nonatomic, copy) NSString *svgIconImageName;
@property (nonatomic, assign) NSInteger cellType;
@property (nonatomic, assign) NSInteger colorStyle;
@property (nonatomic, assign) BOOL isEnable;
@property (nonatomic, assign) BOOL isSwitchOn;
@property (nonatomic, copy) void (^cellTappedBlock)(void);
@property (nonatomic, copy) void (^switchChangedBlock)(void);
@end

@interface AWESettingSectionModel : NSObject
@property (nonatomic, assign) NSInteger type;
@property (nonatomic, assign) CGFloat sectionHeaderHeight;
@property (nonatomic, copy) NSString *sectionHeaderTitle;
@property (nonatomic, strong) NSArray *itemArray;
@end

@interface AWESettingBaseViewModel : NSObject
@end

@interface AWESettingsViewModel : AWESettingBaseViewModel
@property (nonatomic, assign) NSInteger colorStyle;
@property (nonatomic, strong) NSArray *sectionDataArray;
@property (nonatomic, weak) id controllerDelegate;
@end

@interface AWESettingBaseViewController : UIViewController
- (AWESettingBaseViewModel *)viewModel;
@end

@interface AWENavigationBar : UIView
@property (nonatomic, strong) UILabel *titleLabel;
@end

@interface AWEUserHomeVisitorButton : UIView
@end

@interface AWEUserHomeVisitorButtonAccessView : UIView
@end

@interface AWEPlayInteractionUserNameLabel : UILabel
@end

@interface AWEAwemeAuthorContainerView : UIView
@end

@interface TTMetalViewVP : UIView
@end

@interface TTPlayerView : UIView
@end

@interface AWEFeedStickerContainerView : UIView
@end

@interface AWEShellViewController : UIViewController
@end

#endif /* DouyinHeaders_h */
