# 🔄 DYKiller 版本迭代与技术方案 Loop 记录文档

> **项目名称**：DYKiller (抖音 UI 增强插件)  
> **适用版本**：`0.5.5-beta63` ~ `0.5.5-beta74+`  
> **文档职责**：全面归档每一次迭代的用户需求、技术痛点、底层解法、Commit 记录与使用指南。

---

## 1. 版本迭代 Loop 完整记录表

| 版本号 | 核心需求与场景痛点 | 底层解法与技术突破 | 关键 Hook 文件与提交 Commit |
| :--- | :--- | :--- | :--- |
| **`0.5.5-beta93`** | 落地类似 FLEX 的【2D 视觉线框透视截图 (`screenshot_wireframe.png`)】自动生成系统 | 在调试快照中叠加渲染控件矩形边框、分类色块（绿色文本/紫色容器/青色控制/橙色画面）与 `{x, y, w, h}` 坐标徽章 | `DKDebugCapture.h`<br>`DKDebugCapture.m`<br>`DKDebugExport.m`<br>[`control`](file:///c:/Users/30676/Documents/project/douyin/DYKiller_repo/control) |
| **`0.5.5-beta92`** | 解剖 `1786924776` 与 FLEX 截图：1. 消除左下角文案 StackView 底部 75pt 浮空空白；2. 彻底消除图文/二级详情页底部黑条 | 1. 扩展 `AWEPlayInteractionViewController` 满高至 `superviewHeight` (874pt)，使文案栈自然贴底排版；<br>2. 释放 `RichContentContainerViewController` 满高填充 | `DKVideoPageChrome.xm`<br>[`control`](file:///c:/Users/30676/Documents/project/douyin/DYKiller_repo/control) |
| **`0.5.5-beta91`** | 1. 加回全屏播放横屏按钮 `AWELandscapeFeedEntryView`；<br>2. 修复二级详情页无 TabBar 时出现的 75pt 底部黑条 | 1. 从极简控件与渲染优化隐藏列表中剔除 `AWELandscapeFeedEntryView`；<br>2. 在 `AWEAwemeDetailTableViewCell` 中将 `targetHeight` 强制拉满 `superviewHeight` (874pt)，彻底消灭底部黑条 | `DKVideoPageChrome.xm`<br>[`control`](file:///c:/Users/30676/Documents/project/douyin/DYKiller_repo/control) |
| **`0.5.5-beta90`** | CI 编译阶段 `DouyinHeaders.h` 中 `AWEFeedProgressSlider` 重复声明接口报错 | 移除重复前向声明，保持唯一声明引用，彻底解除 Clang 重定义错误 | `DouyinHeaders.h`<br>[`control`](file:///c:/Users/30676/Documents/project/douyin/DYKiller_repo/control) |
| **`0.5.5-beta89`** | 验证 `1786890467` 日志：抖音原生清屏/放大视频 (`PureModePageCellViewController`) 默认隐藏进度条并淡出至 `alpha=0` | 挂钩 `AWEFeedProgressSlider` 与 `AWEDPlayerProgressContainerView` 的 `setAlpha:` 及 `setHidden:`，强阻原生清屏模式淡出进度条，实现放大清屏持续显示完整进度条 | `DKFluidGestures.xm`<br>`DouyinHeaders.h`<br>[`control`](file:///c:/Users/30676/Documents/project/douyin/DYKiller_repo/control) |
| **`0.5.5-beta88`** | 彻底修复调试录制状态同步、按键变红延迟、导出后状态残留及 `snapshots/stepN/` 多页快照落盘 | 1. `gDKIsCapturingLogs` 状态同步设置并联动 `viewWillAppear` 实时刷红/恢复暗色；<br>2. 正式落盘 `snapshots/step1/`、`snapshots/step2/` 多页快照文件夹 | `DKHookLogger.mm`<br>`DKDebugExport.m`<br>`DKDebugInspector.m`<br>[`control`](file:///c:/Users/30676/Documents/project/douyin/DYKiller_repo/control) |
| **`0.5.5-beta87`** | CI 编译阶段 `DKDebugCaptureContext` 调用参数与头文件属性匹配修复 | 补充 `DKDebugCapture.h` 中 `stepIndex` / `stepContexts` 属性，修正 `DKDebugCaptureContext` 3 参数调用 | `DKDebugCapture.h`<br>`DKDebugInspector.m`<br>[`control`](file:///c:/Users/30676/Documents/project/douyin/DYKiller_repo/control) |
| **`0.5.5-beta86`** | 落地快捷手势调试引擎：录制中「单击小钥匙」秒抓快照，「长按 0.8s」打包导出 ZIP | **快捷手势多页调试交互**：`handleWrenchTap` 实现无打扰秒级快照 + 触觉震动 + 缩放反馈；`handleWrenchLongPress` 实现长按快捷完成导出打包 | `DKDebugInspector.m`<br>[`control`](file:///c:/Users/30676/Documents/project/douyin/DYKiller_repo/control) |
| **`0.5.5-beta85`** | 重构调试录制流程：1. 开启抓取时立即变红高亮；2. 增加【📸 捕抓当前页快照】多页序列采集；3. 精简设置菜单无用冗余按钮 | **多页快照多段录制架构**：支持按页采集 `step1_`, `step2_` 图层与视图树快照，且开启后小钥匙高亮亮红白色边框 | `DKDebugInspector.m`<br>`DKDebugCapture.h`<br>`DKDebugExport.m`<br>`DKDebugEntry.xm`<br>[`control`](file:///c:/Users/30676/Documents/project/douyin/DYKiller_repo/control) |
| **`0.5.5-beta84`** | 用户在两指捏合切清屏/放大视频时，希望能保留完整/可拖拽的底层视频进度条 | **清屏模式保留进度条系统** (`DKKeyKeepProgressInCleanMode`)：在 `dk_handleFluidPinch` 中精准过滤并保留 `AWEDPlayerProgressContainerView` / `AWEFeedProgressSlider` 透明度为 1.0 且可交互 | `DKFluidGestures.xm`<br>`DKVideoGeometry.xm`<br>[`control`](file:///c:/Users/30676/Documents/project/douyin/DYKiller_repo/control) |
| **`0.5.5-beta83`** | 推荐页卡片显示“距离你 xx km”本地商业广告壳；验证 `1786887418` 性能降低至 844MB RAM | 挂钩 `AWEAwemeModel` 的 `isAd` / `isCommerce` / `adLinkType` 及 `AWEFeedCellViewController` 的 `setModel:` 彻底阻断本地广告卡片 | `DKJunkResourceBlocker.xm`<br>`DouyinHeaders.h`<br>[`control`](file:///c:/Users/30676/Documents/project/douyin/DYKiller_repo/control) |
| **`0.5.5-beta82`** | CI 编译阶段 `DKVideoPageChrome.xm` 中 `AWEPlayInteractionViewController` 重复声明 Hook 方法冲突报错 | 合并 `viewDidLayoutSubviews` Hook 方法块，彻底解除 Logos 符号生成重复冲突 | `DKVideoPageChrome.xm`<br>[`control`](file:///c:/Users/30676/Documents/project/douyin/DYKiller_repo/control) |
| **`0.5.5-beta81`** | CI 编译阶段重定义接口类与 `DouyinHeaders.h` 冲突报错 | 统一收拢营销与挂件类定义至 `DouyinHeaders.h`，彻底解除 Clang 接口重定义错误 | `DouyinHeaders.h`<br>`DKJunkResourceBlocker.xm`<br>[`control`](file:///c:/Users/30676/Documents/project/douyin/DYKiller_repo/control) |
| **`0.5.5-beta80`** | CI 编译阶段 `DKJunkResourceBlocker.xm` 前向声明缺少 `UIView` 继承定义，导致 Clang 报 `property 'hidden' cannot be found` | 补全 `@interface ViewClass : UIView @end` 定义，彻底解开 Clang 属性编译限制 | `DKJunkResourceBlocker.xm`<br>[`control`](file:///c:/Users/30676/Documents/project/douyin/DYKiller_repo/control) |
| **`0.5.5-beta79`** | 落地“极简控件模式”，剥离播放界面冗余无效图标与挂件 | **极简控件模式** (`DKKeyZenFeedUIEnabled`)：隐去暂停半透明图标、短剧引流水印与无用提示，大幅提升画质清爽度 | `DKVideoPageChrome.xm`<br>`DKVideoGeometry.xm`<br>[`control`](file:///c:/Users/30676/Documents/project/douyin/DYKiller_repo/control) |
| **`0.5.5-beta78`** | 屏蔽营销图层浮窗，且不影响预加载；优化 Metal 视口重叠的 22 层冗余渐变遮罩渲染管道 | 1. **独立营销图层拦截** (`DKKeyBlockMarketingLayers`)：挂钩短剧水文引流与带货挂件，不影响视频预加载；<br>2. **Metal 渲染管道极简优化** (`DKKeyOptimizeRenderPipeline`)：剥离 `AWEGradientView` 提升 GPU 帧合成效率 | `DKJunkResourceBlocker.xm`<br>`DKVideoPageChrome.xm`<br>`DKVideoGeometry.xm`<br>[`control`](file:///c:/Users/30676/Documents/project/douyin/DYKiller_repo/control) |
| **`0.5.5-beta77`** | 横屏视频切换时，小钥匙调试按钮缺失消失；阶段抓取时间可能延迟不及时 | 1. 监听 `UIDeviceOrientationDidChangeNotification` 与 `UIWindowDidBecomeKeyNotification` 自动重选最顶层全屏层级 (`1000000.0`) 并按横竖屏重分布；<br>2. 抓取开启时增加主线程实时同步 Flush 保障及时性 | `DKDebugInspector.m`<br>[`control`](file:///c:/Users/30676/Documents/project/douyin/DYKiller_repo/control) |
| **`0.5.5-beta76`** | 用户提出希望能强切 Apple 原生 `AVPlayer` (AVFoundation) 解码引擎以降低功耗并增强原生系统融合 | **iOS 原生 AVPlayer 解禁引擎**：开启开关后在 `AWEPlayVideoViewController` 中拦截 `playerType` 与 `useAVPlayer` 强切原生 `AVPlayer` | `DKVideoPageChrome.xm`<br>`DKVideoGeometry.xm`<br>[`control`](file:///c:/Users/30676/Documents/project/douyin/DYKiller_repo/control) |
| **`0.5.5-beta75`** | CI 编译阶段 `DKFluidGestures.xm` 中 `setPlaybackRate:` 在 ObjC++ 严苛模式下报无已知选择器错误 | 使用动态函数指针强转 `(DKSetRateIMP)[self methodForSelector:sel]` 调用，彻底解除 Clang 编译隐患 | `DKFluidGestures.xm`<br>[`control`](file:///c:/Users/30676/Documents/project/douyin/DYKiller_repo/control) |
| **`0.5.5-beta74`** | DyYY 悬浮图标遮挡画面；低清/压缩短视频模糊昏暗 | 1. **Metal GPU 锐化/彩增强引擎**：`TTMetalViewVP.layer` 注入 `CISharpenLuminance` & `CIColorControls`；<br>2. **0 图标流体手势**：两指捏合切清屏，两指轻击循环切倍速 | `DKFluidGestures.xm`<br>`DKVideoPageChrome.xm`<br>[`0bddd44`](https://github.com/subezhj/DYKiller/commit/0bddd44) |
| **`0.5.5-beta73`** | CI 编译阶段 `DKMediaIsland.xm` 缺失 `DKLogHookEvent` 声明 | 在 `DKHookLogger.h` 还原补齐 C 函数原型声明 `DKLogHookEvent` | `DKHookLogger.h`<br>[`125390a`](https://github.com/subezhj/DYKiller/commit/125390a) |
| **`0.5.5-beta72`** | CI 编译阶段 `DKDebugEntry.xm` 误调用未暴露私有函数 `DKStartExport` | 将非法私有函数调用替换为引导弹窗，彻底修复 Clang 编译错 | `DKDebugEntry.xm`<br>[`65d320c`](https://github.com/subezhj/DYKiller/commit/65d320c) |
| **`0.5.5-beta71`** | 全屏模式 2 下，若抖音官方原生未提取到明亮颜色（呈现暗黑），上下留空显得生硬 | **智能提色兜底算法**：检测到亮度 $< 0.18$ 时，自动从视频首帧/封面图抽取主调色并升亮，回涂至 `playerBackgroundView.backgroundColor` | `DKVideoPageChrome.xm`<br>[`1951724`](https://github.com/subezhj/DYKiller/commit/1951724) |
| **`0.5.5-beta70`** | 需要能够手动开启/关闭阶段性日志抓取（例如刷 3 个视频后停止并打包） | **阶段性数据抓取系统**：实现 `DKStartLogCapture` / `DKStopLogCapture`，扳手按钮变红提示，停止后自动唤起 ZIP 打包导出 | `DKHookLogger.mm`<br>`DKDebugInspector.m`<br>[`e2ba7a6`](https://github.com/subezhj/DYKiller/commit/e2ba7a6) |
| **`0.5.5-beta69`** | 模式 2 下 `TTMetalViewVP` 被抖音底层引擎强制放大到 `491.625pt`（导致左右仍被裁切 89.6px） | **Metal 视口帧钳制算法**：Hook `%hook TTMetalViewVP setFrame:`，强行将宽度锁死在 `402pt`，实现物理级 0 像素裁切 | `DKVideoPageChrome.xm`<br>[`6a8aec8`](https://github.com/subezhj/DYKiller/commit/6a8aec8) |
| **`0.5.5-beta68`** | 全屏模式 2 下推荐页下拉刷新卡顿悬停 | 恢复 `DKMergeCanCoverScreen` 容器撑高，修复 `viewDidLayoutSubviews` 幂等性，保障 preloader 周期 | `DKVideoGeometry.xm`<br>[`91f4f88`](https://github.com/subezhj/DYKiller/commit/91f4f88) |
| **`0.5.5-beta67`** | 用户提出希望实现 0 裁切的原比例无损全屏方案 (全屏模式 2) | 重构全屏系统为 3 模式切换（0 关闭 / 1 满屏填充 / 2 原比例无损），模式 2 下配合原生 GPU 氛围渐变伸展 | `DKVideoGeometry.xm`<br>`DKVideoPageChrome.xm` |
| **`0.5.5-beta64`** | 个人主页显示“新访客”导流按钮；字幕与用户名在无遮罩画面下对比度不足；音乐按钮包含“听合集” | 1. 净化 `AWEUserHomeVisitorButton`；<br>2. 统一可读性开关为 3 选项 (仅字幕/仅用户名/全量)；<br>3. 扩展音乐按钮过滤文本包含 `"听合集"` | `DKProfileCleaner.xm`<br>`DKVideoPageChrome.xm`<br>`DKHideMusicInfo.xm` |

---

## 2. 核心技术原理与设计模式总结

### 2.1 Metal GPU 视口钳制与硬件滤镜链
为解决视频画面在 AspectFit 模式下被底层播放器强制按比例放大剪裁的问题，DYKiller 直接挂钩 Metal 解码输出视图 `TTMetalViewVP`：
```objc
%hook TTMetalViewVP

- (void)setFrame:(CGRect)frame {
    if (DKVideoFullscreenModeValue() == 2) {
        // 强制把 Metal 视口宽度钳制在屏幕宽 402pt，X 偏移重置为 0
        frame = CGRectMake(0.0, newY, 402.0, newH);
    }
    %orig(frame);
}

- (void)didMoveToWindow {
    %orig;
    // 注入 GPU 硬件级锐化与色彩控制滤镜
    self.layer.filters = @[ CISharpenLuminanceFilter, CIColorControlsFilter ];
}

%end
```

### 2.2 0 图标流体手势管线 (`DKFluidGestures.xm`)
为了解决 DyYY 悬浮按键遮挡画面、容易误触的痛点，DYKiller 采用轻量级流体手势管线：
- **两指捏合 (`UIPinchGestureRecognizer`)**：平滑隐去/恢复 `interactionViewController.view`；
- **双指轻击 (`UITapGestureRecognizer` `touches=2`)**：无缝循环切换播放倍速（`1.0x` $\rightarrow$ `1.25x` $\rightarrow$ `1.5x` $\rightarrow$ `2.0x` $\rightarrow$ `3.0x`）。

---

*文档更新时间：2026-08-16 | Antigravity AI Codebase Docs*
