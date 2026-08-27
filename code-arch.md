# DYKiller 代码审核与架构梳理报告

> 审核基线:`aff2417`(v0.5.5-beta153),目标抖音 39.9.0
> 审核范围:`src/` 全部 58 个源文件(约 14,400 行),重点为设置页功能生效性与 dylib 插件优化点

---

## 〇、修复记录(本报告产出后的落地情况)

> 经确认:「团购/POI 文案与 DYYY 统一」实测有效,**保留**;其余问题已全部修复。

| # | 问题 | 修复方式 | 涉及文件 |
|---|---|---|---|
| 1 | `? 1 : 1` 全屏默认值 bug | 改为 `? 1 : 0`,旧开关关闭的升级用户不再被强制开满屏 | DKVideoGeometry.xm |
| 2 | 电商拦截 isAd 互斥 | 删除 isAd/isCommerce/adLinkType 三个「恣 NO」钩子,setModel: 隐藏改读抖音原始判定,广告 cell 隐藏生效 | DKJunkResourceBlocker.xm |
| 3 | LiveActivity 死开关(空实现) | 整体下架:删文件、删键、删诊断报告行 | DKLiveActivityIsland.xm(已删)、DKKeys.h、DKHookLogger.mm |
| 4 | 网络日志默认值撒谎 | 未写入键时返回 NO,与 UI 一致;NSDateFormatter 静态复用(POSIX locale) | DKNetworkLogger.xm |
| 5 | MediaIsland 双触发/不清理 | 删 willResignActive 触发(只留 didEnterBackground);回前台清空 nowPlayingInfo;文案收敛 | DKMediaIsland.xm |
| 6 | PiP 第三方 CDN 视频/不释放 | 本地生成 2 秒灰片(AVAssetWriter,离线可用);回前台 pause;didStop/failedToStart 回调同样收敛 | DKPiPQuickLaunch.xm(重写) |
| 7 | 「移除底栏」死开关 | 补实现:AWENormalModeTabBar 整栏隐藏(优先级高于玻璃底栏),setHidden: 钉住,关联标记精准还原 | DKGlassTabBar.xm |
| 8 | POI 文案统一热路径开销 | 功能保留;加开关+DYYY 缩放双重判定,结果按 defaults 纪元缓存,关闭时全局 hook 仅一次整数比较 | DKExperimentalFeatures.xm |
| 9 | Anti-Jetsam 挂点不可达 | 从 AWEShellViewController 改挂 UIApplication didEnterBackground(必达);内存警告改主线程 post;文案收敛 | DKExperimentalFeatures.xm |
| 10 | 全局 setFrame: 逐帧读 defaults | 新增 DKDefaultsEpoch(变更纪元)+ DKHotVideoGeometryActive(合成缓存),未启用时一次整数比较即返回 | DKUtils.h/.m、DKVideoGeometry.xm |
| 11 | 全局 setBackgroundColor: 无守卫 | 加 gEverAttached 短路,本会话从未启用时直接放行 | DKCommentGlass.xm |

**未动(待真机验证):Metal 锐化/色彩增强(layer.filters 对 Metal 层内容可能不生效)、原生 AVPlayer 引擎枚举值;其余 P3 打磨项(类名收敛、README 同步、synchronize 移除)待后续。**

---

## 一、项目架构梳理

### 1.1 模块结构

```text
DYKiller.dylib (Theos Tweak, 注入 Aweme 进程)
│
├── Settings/   设置框架(注册式、解耦)
│   ├── DKSettingsMenu.xm     在「抖音设置→账号」上方插入 DYKiller 入口;
│   │                         手动构建 AWESettingBaseViewController + 关联对象挂 viewModel
│   └── DKSettings.h          对外 C API:DKSettingsRegisterItem / DKMakeSwitch /
│                             DKMakeChoice / DKMakeButton / DKMakePercentSlider
│
├── Features/   功能模块(每个文件自带 %ctor 注册开关,互不耦合)
│   ├── VideoFullscreen/      几何拦截(setFrame)、表撑高、页面修饰、进度条、流体手势
│   ├── Comment/              评论玻璃、底栏移除、图片清理、全屏垫底、弹幕
│   ├── TabBar/               悬浮玻璃底栏、音频可视化、收藏页玻璃
│   ├── Share/ Notification/  分享面板玻璃、应用内通知玻璃
│   ├── Feed/                 网络拦截、搜索净化、音乐信息、合集条
│   ├── Profile/ ChatVideo/ Interaction/
│   ├── Background/           灵动岛×2、画中画秒开
│   └── Experimental/         自定义背景、渲染优化、ProMotion、防杀、POI 统一
│
├── Shared/    DKKeys(键集中)、DKUtils、DKGlassGuard(iOS26 守卫)、DKAudioTap/Signal/Levels(实时音频)
├── Debug/     调试入口、Inspector、抓取导出、HookLogger、NetworkLogger、TabBarProbe、AudioProbe
├── FLEX/      ClassDump、ZipWriter(导出辅助)
└── Headers/   DouyinHeaders.h 私有类前向声明
```

### 1.2 设置框架工作流

```text
功能文件 %ctor ──DKSettingsRegisterItem(header, builder)──▶ 全局注册表(保序)
用户点「DYKiller」入口 ──▶ DKShowSettings ──▶ 遍历注册表按 header 分组构建 item
                                                    │
AWESettingItemModel(cellType 6=开关 / 26=点击) ◀────┘
开关写入 ──▶ NSUserDefaults[key] + synchronize
hook 侧读取 ──▶ DKPrefBool / DKPrefInteger(gated 键在 iOS<26 强制返回 NO)
```

- 开关即 NSUserDefaults 键,identifier 即键名,无中间层。
- `DKGlassGuard` 在 iOS<26 启动时清空全部玻璃类键,设置项由 `DKGlassLockItemIfNeeded` 加 "(iOS26+)" 后缀灰显——**该守卫设计良好**。
- 分区顺序 = %ctor 执行顺序 = 链接顺序(Makefile 用 `find | sort` 固定),确定性有保证但**隐式**:重命名文件会重排设置分区,建议在注册 API 加显式 `order` 参数或在 README 标注此约束。

### 1.3 关键设计决策(值得保留的亮点)

| 亮点 | 位置 |
|---|---|
| 写入时拦截 + 布局后兜底双路径(实测 130:6 命中比) | DKVideoGeometry / DKVideoFeedTable |
| 玻璃/背景类改动全部「先存原值再改,关开关精准还原」(关联对象 baseline) | 全部玻璃模块 |
| 音频实时层无锁纪律:RT 线程零分配/零锁/零 ObjC 消息,BSS 定长缓冲,seqlock 格式 | DKAudioTap.mm |
| platter glassEffect 探测一次后永久缓存结论,逐帧不再 @try/@catch | DKGlassTabBar |
| 灵动岛/染色口径实测注释文化(亮度数值、beta 编号溯源) | 各文件头注释 |
| DYYY 共存让权(DYYYVideoBGColor / DYYYEnableFullScreen 检测) | DKVideoGeometry / DKExperimentalFeatures |

---

## 二、设置页功能生效性核查表

逐键交叉核对「DKKeys.h 定义 → 设置 UI 注册 → hook 消费」三方一致性:

### ✅ 生效正常(34 项)

| 分区 | 开关 | 消费点 |
|---|---|---|
| 视频 | 视频全屏模式 / 可读性增强 / 文字对比度 / 极简控件 / 清屏保留进度条 / 隐藏进度条 | DKVideoGeometry、DKVideoPageChrome、DKProgressUnderline、DKFluidGestures |
| 高级与播放器 | Metal 渲染管道优化 | DKVideoPageChrome(隐藏渐变层)+ DKExperimentalFeatures(Metal flag) |
| 评论区 | 隐藏评论底栏 / 图片清理底栏 / 评论玻璃 / 清透 / 顶部圆角 | DKCommentBottomBar、DKCommentMediaCleaner、DKCommentGlass |
| 分享 | 分享面板玻璃 / 清透 | DKSharePanelGlass |
| 通知 | 通知玻璃 / 清透 / 圆角滑条 | DKInnerNotificationGlass |
| 底栏 | 悬浮玻璃底栏 / 清透 / 文字自动变色 / 底部抬升 | DKGlassTabBar、DKVideoPageChrome |
| 音频可视化 | 位置 / 形态(依赖玻璃底栏) | DKAudioVisualizer |
| 播放体验 | 详情页底栏 / 关注按钮 / 音乐信息 / 音乐按钮文字 / 合集条 | DKChatVideoBottomBar、DKHideFollowButton、DKHideMusicInfo、DKTransparentMixBar |
| 个人主页 | 发作品引导 / 新访客 | DKProfileCleaner |
| 搜索 | 热榜 / 猜你想搜 | DKSearchTrendingBlocker(runtime hook 按需安装,处理 dylib 懒加载,设计正确) |
| 净化与拦截 | 网络拦截 / 活动挂件 / Lynx 卡片 / 水印图层 | DKJunkResourceBlocker |
| 实验性 | 非全屏自定义背景 | DKExperimentalFeatures(AWEAwemeModel 双通道)+ DKVideoPageChrome |
| 调试 | 调试工具 | DKDebugEntry/Inspector |

### ❌ 死开关——注册了但无任何消费点(2 项)

> 注:下表为审核时结论,处置结果见顶部「修复记录」。

| 开关 | 位置 | 说明 |
|---|---|---|
| **「移除底栏」** `DKKeyHideBottomBar` | DKGlassTabBar.xm:1065 | 全项目无任何代码读取 `DYKillerHideBottomBar`。switchChangedBlock 只调 setNeedsLayout,而 layoutSubviews hook 只认 `DKKeyGlassTabBar`。**已补实现(修复 #7)。** |
| **「[实验性] 团购/POI推荐文案与DYYY统一」** `DKKeyPOICommentStyleUnified` | DKExperimentalFeatures.xm:391 | 无直接消费点;POI 卡片样式实际由全局 UIView hook 依据 `DYYYDescriptionScale` 驱动。**经确认实测有效,保留并补上开关守卫(修复 #8)。** |

### ❌ 占位功能——实现为空(1 项)

| 开关 | 位置 | 说明 |
|---|---|---|
| **「灵动岛 LiveActivity 实时直达」** | DKLiveActivityIsland.xm | `DKRequestOrUpdateLiveActivity` 仅做类存在性与 `areActivitiesEnabled` 两次检查后**直接返回,从未 request 任何 Activity**。且技术上限死:宿主 App 无法用 `NSClassFromString(@"ActivityKit.Activity")` 在运行时创建实时活动——需要 Widget 扩展 + 编译期 `ActivityAttributes` 类型。**该功能 100% 无效,建议直接下架开关,或改为引导文案。** |

### ⚠️ 生效但有缺陷(7 项)

| 开关 | 问题 |
|---|---|
| **「灵动岛媒体直达唤醒」** DKMediaIsland.xm | ① `willResignActive` + `didEnterBackground` 双触发,每次退后台**两次**写 nowPlayingInfo、两次激活音频会话;② `willEnterForeground` 回调体为空——**假条目「抖音·点击返回前台」在回前台后永不清理**,锁屏/控制中心残留;③ 强制 `setCategory:Playback + setActive:YES` 与抖音自身会话管理冲突(抢 now-playing 归属、改变静音键语义);④ 注册的 play/pause/toggle 远程命令返回 Success 但不做事,挤占抖音遥控链路。 |
| **「画中画悬浮直达秒开」** DKPiPQuickLaunch.xm | ① 播放**第三方 CDN 视频** `vjs.zencdn.net/v/oceans.mp4`:无网不可用、隐私/合规风险、每次退后台耗流量,应内置本地素材;② 回前台只 stopPictureInPicture,**不 pause 不释放 player**,前台持续解码远端视频;③ 1×1 playerLayer 挂 keyWindow.layer 永不摘除;④ 未设 playback 音频类别,依赖抖音当时会话状态,视频未播时 PiP 可能秒挂。 |
| **「屏蔽电商带货与广告」** DKJunkResourceBlocker.xm:230-247 | **自相矛盾**:本文件把 `AWEAwemeModel.isAd/isCommerce` 强制返回 NO,而隐藏执行点 `AWEFeedCellViewController setModel:` 又依赖 `[model isAd]`(被自己 hook 成恒 NO)→ **广告卡片隐藏路径永不触发**。小黄车/POI 锚点等独立 hook 有效。修法:执行点改读原始值(绕过自家 hook 缓存),或删掉 setModel 执行段。 |
| **「API 网络请求抓包日志」** DKNetworkLogger.xm:75-78 | 默认值撒谎:`DKNetworkLoggerActive()` 对未写入键返回 **YES**(实际全量记录),`DKMakeSwitch` 却显示 OFF。界面显示关闭、后台仍记录每个请求(含 JSON 序列化 + 每条新建 NSDateFormatter)。 |
| **「Metal 画面边缘锐化 / 色彩增强」** DKVideoPageChrome.xm(TTMetalViewVP) | 实现为写 `layer.filters`(CIFilter 数组)——**iOS 上 CALayer filters 对 CAMetalLayer 内容普遍不生效**(macOS 语义),且 TTMetalView 内容由 Metal drawable 直供,不经过 CA 滤镜管线。大概率安慰剂,需真机 A/B 验证,无效则下架。 |
| **「[实验性] 智能后台冻结与防杀」** DKExperimentalFeatures.xm:53 | hook 挂在 `AWEShellViewController - applicationDidEnterBackground:`——**UIViewController 并不会自动收到该回调**,除非抖音自己实现/转发此方法。若未实现则 Logos 挂上后无人调用,整个功能不存在。需真机打点验证。且 `removeAllCachedResponses` + 手动广播内存警告只能释放 URL 缓存,"杜绝杀后台/100%秒开"文案过度承诺。 |
| **「iOS 原生 AVPlayer 引擎」** DKVideoPageChrome.xm:370-386 | `playerType` 返回 1 / `useAVPlayer` 返回 YES 属于枚举值猜测,需对 39.9.0 class-dump 确认 1 的语义;已标实验性,保留观察。 |

---

## 三、明确 Bug 清单

| # | 严重度 | 位置 | 问题 |
|---|---|---|---|
| 1 | 🔴 | DKVideoGeometry.xm:254 | `NSInteger legacy = DKPrefBool(DKKeyVideoFullscreen) ? 1 : 1;` 三元两分支同为 1,应为 `? 1 : 0`。现效果:**所有升级用户无论旧开关状态,一律被默认成「满屏填充」**。 |
| 2 | 🔴 | DKJunkResourceBlocker.xm | isAd/isCommerce 钩子与 setModel 隐藏执行互斥(见上表)。 |
| 3 | 🔴 | DKLiveActivityIsland.xm | 空实现(见上表)。 |
| 4 | 🟠 | DKNetworkLogger.xm | 默认开 + UI 显示关(见上表)。 |
| 5 | 🟠 | DKMediaIsland.xm | 无清理/双触发/会话冲突(见上表)。 |
| 6 | 🟠 | DKPiPQuickLaunch.xm | 第三方 URL/不 pause(见上表)。 |
| 7 | 🟡 | DKFluidGestures.xm:207-212 | 设置入口被注释「待手势体验完善后再开放」,但 hooks 照常安装,`DKKeyFluidGesturesEnabled` 成幽灵键(用户无法开启,代码常驻)。要么补完 UI,要么整组进 `%group` 不 `%init`。 |
| 8 | 🟡 | DKGlassTabBar.xm:1065 | 死开关(见上表)。 |
| 9 | 🟡 | DKExperimentalFeatures.xm:391 | 死开关(见上表)。 |

---

## 四、性能优化建议(dylib 注入全局开销)

### P0 — 删除无条件的热路径全局 hook

**`%hook UIView layoutSubviews`(DKExperimentalFeatures.xm:344)**

```objc
%hook UIView
- (void)layoutSubviews {
    %orig;
    NSString *cls = NSStringFromClass(self.class);          // 每次布局分配字符串
    if ([cls containsString:@"AWERichAwemeLifeCard"] || …   // ×5 次 containsString
```

- layoutSubviews 是 UIKit 最热路径之一,滚动时全 App 每秒数百~上千次调用;
- **无任何 DYKiller 开关守卫**:所有功能关闭、甚至 DYYY 未配置时,每个视图每次布局都要付出 NSStringFromClass + 5×containsString;
- 五个目标类(`AWERichAwemeLifeCard`、`POICommentCard`、`POIRatingList`、`POIAnchor`、`AWERichAwemeLifeCardImageDescView`)全部可直接 `%hook` 精准挂载。
- **改法:删除该全局 hook,改为 5 个具名类 hook。收益:全用户全场景减一整层布局开销。**

### P1 — 全局 `setFrame:` 的 NSUserDefaults 读取缓存(DKVideoGeometry.xm:230)

当前每次 `setFrame:`(全 App 最热写入路径)执行:

```objc
NSInteger customBackdrop = [defaults integerForKey:DKKeyCustomBackdropColorStyle]; // ①
if (!DKVideoFullscreenOn() /* objectForKey + boolForKey = ②③ */ 
    && !DKCommentFreezeOn() /* boolForKey = ④ */ && customBackdrop <= 0) { %orig; return; }
```

≈ 4 次 NSUserDefaults 读取/次。虽单次便宜,但叠加在每秒数千次调用的路径上。

**改法(推荐,一处改动全局受益):** 在设置框架引入代数计数器——

```objc
// DKSettings 内
static _Atomic int gDKPrefGeneration = 0;   // DKMakeSwitch/Choice/Slider 每次写入 atomic_fetch_add
int DKPrefGeneration(void);

// DKUtils 内
BOOL DKAnyVideoGeometryHot(void);  // 内部 static 缓存,代数变化时才重读 4 个键并缓存
```

`setFrame:` 守卫改为一次原子读 + 一次缓存布尔比较。`DKJunkResourceBlocker` 各 layoutSubviews 的多键组合读取同样接入此缓存。

### P2 — 全局 `setBackgroundColor:` 短路(DKCommentGlass.xm:602)

iOS 26 上无条件安装,每次 2×`objc_getAssociatedObject`(hash 查找)。文件内已有 `gEverAttached` 标志却未用于守卫:

```objc
- (void)setBackgroundColor:(UIColor *)color {
    if (!gEverAttached) { %orig; return; }   // 从未启用过即放行,几乎零成本
    …
```

### P3 — 日志模块的 NSDateFormatter 分配

- `DKNetworkLogger DKAddNetworkLogDetailed`、`DKHookLogger DKLogHookEvent`:**每条日志新建 NSDateFormatter**(毫秒级分配);
- 改为 `static NSDateFormatter`(其本身线程安全),或缓存 `CFAbsoluteTime` + 导出时统一格式化;
- 配合「网络日志默认关」修复,默认路径零开销。

### P4 — 逐帧递归收敛

- `DKExperimentalFeatures DKApplyBackdropColorRecursively / DKHideVideoGradientsRecursively`:挂在 `AWEPlayVideoViewController.viewDidLayoutSubviews`,每次布局 depth≤8 全树递归 + 每节点 2 次 NSStringFromClass/containsString。建议:容器上挂关联标记「本容器已处理」,布局签名(宽高)未变即跳过;
- `DKHideMusicInfo DKSyncMusicButtonTextTree` 每次 music view 布局全子树遍历 UILabel——命中面小,可保留但建议先比对开关值(已有)再走树。

### P5 — 杂项

- `DKShowToastHUD`(DKFluidGestures)静态 toast 视图在快速连续触发时 dispatch_after 竞态(旧 completion 移除新视图)——功能未开放,优先级低;
- `AWESettingsViewModel sectionDataArray` hook 每次读都重建 entry section——设置页浏览频率低,可接受;
- `DKMakeSwitch` 每次写开关都 `synchronize`(阻塞落盘)——iOS 12+ 已无必要,可去掉。

---

## 五、稳定性与健壮性建议

1. **AWEShellViewController 生命周期钩子验证**(见上表):用 `DKLogHookEvent` 打点确认 `applicationDidEnterBackground:` 是否真的被抖音调用,否则防杀功能移挂到 `UIApplication` 通知(与 MediaIsland/PiP 一致的挂法)。
2. **PiP 本地化**:把 oceans.mp4 换成 dylib 内嵌或 Documents 的 1-2 秒本地循环素材;回前台 `[player pause]` + 移除 layer;补充 `pictureInPictureControllerDidStopPictureInPicture:` 里 `restoreUserInterface…` 后清理 nowPlaying。
3. **MediaIsland 生命周期对称**:didEnterBackground 写入、willEnterForeground 置空 `nowPlayingInfo` + 停用会话;去掉 willResignActive 重复触发;远程命令只注册 toggle 或透传给抖音。
4. **网络拦截 NSURLSession 分支**:对 `about:blank` 请求 NSURLSession 可能产生 "unsupported URL" 错误回调,建议改为主机 `127.0.0.1` 空请求或直接不创建 task 返回 nil(与 TTNetworkManager 分支对齐)。
5. **类名字符串依赖集中化**做得较好(`kDKBadgeContainerClass` 等),但 `DKIsSearchDetailView`、`DKNavigationCameFromSearch`、互动容器 referString 白名单等散落各文件——抖音 40.x 改名时建议统一收敛到 DouyinHeaders.h 或一个 DKClasses.m。
6. **设置入口判据脆弱**:`sectionDataArray` 以「账号」分区识别设置主页,抖音改文案即失效;可叠加 `controllerDelegate` 类名判据兜底。
7. **升级迁移**:`? 1 : 1` 修复后,建议顺带为已写死 1 的存量用户保留现值(不回滚用户数据)。

---

## 六、文案与 README 同步

- README「现有功能」未覆盖:搜索净化、净化与拦截(5 开关)、实验性(5 项)、全屏/后台(3 项)、高级与播放器(2 项)——建议同步;
- 过度承诺措辞建议收敛:「100% 绝对无条件秒开」「杜绝系统杀后台」「极速秒开」等,实验性功能尤其如此;
- 死开关(LiveActivity、POI 统一、移除底栏)在修复或下架前应从 README/设置文案移除,避免用户误解为生效功能。

---

## 七、建议处置优先级

| 优先级 | 事项 |
|---|---|
| P0(下个版本必修) | ① `? 1 : 1` 全屏默认值 bug;② 删除 Experimental 全局 UIView layoutSubviews hook;③ 下架 LiveActivity 死开关;④ 电商拦截 isAd 互斥修复 |
| P1(尽快) | ⑤ 网络日志默认值对齐 + formatter 缓存;⑥ MediaIsland 清理与去重触发;⑦ PiP 本地素材 + 资源释放;⑧ 死开关「移除底栏」「POI 统一」下架或补实现 |
| P2(规划) | ⑨ setFrame 热路径偏好缓存(代数计数器);⑩ Anti-Jetsam 挂点验证;⑪ Metal 锐化/色彩真机 A/B 验证,无效下架;⑫ setBackgroundColor 短路、递归收敛 |
| P3(打磨) | ⑬ 类名依赖收敛、README 同步、synchronize 移除、分区显式排序 |

---

## 附:核查方法说明

- 生效性 = `DKKeys.h 55 键` × `DKMake*(注册)` × `DKPref*/NSUserDefaults(消费)` 三方交叉比对(grep 全源码);
- 热路径 = 追踪所有 `%hook UIView`(3 处)、`%hook UILabel`、`%hook UIApplication` 与各 layoutSubviews/setFrame 挂点的每调用成本;
- 逐文件通读 Features/Settings/Shared/Debug 全部 58 文件,Debug 导出链(FLEX/Zip/ClassDump)未发现阻塞问题。
