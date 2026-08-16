# 🔄 DYKiller 版本迭代与技术方案 Loop 记录文档

> **项目名称**：DYKiller (抖音 UI 增强插件)  
> **适用版本**：`0.5.5-beta63` ~ `0.5.5-beta74+`  
> **文档职责**：全面归档每一次迭代的用户需求、技术痛点、底层解法、Commit 记录与使用指南。

---

## 1. 版本迭代 Loop 完整记录表

| 版本号 | 核心需求与场景痛点 | 底层解法与技术突破 | 关键 Hook 文件与提交 Commit |
| :--- | :--- | :--- | :--- |
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
