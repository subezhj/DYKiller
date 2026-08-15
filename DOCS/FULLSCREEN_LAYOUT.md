# DYKiller 视频全屏与 HUD 布局架构及 Douyin 页面分区分析文档

> **版本适用**：DYKiller 0.5.5-beta40+  
> **目标宿主**：抖音 iOS 39.8.0 及以上版本  
> **核心机制**：模块化 Hook 框架、防重叠元素过滤、DYYY 优雅兼容

---

## 1. 概述与核心设计原则

DYKiller 的视频全屏与 HUD 布局框架旨在为 iOS 抖音提供纯净、流畅、无黑边的全屏观看体验。其核心设计原则包括：

1. **高性能零跳动拦截**：95% 以上的高频尺寸调整在 `setFrame:` 写入入口即时修饰，避免在 `layoutSubviews` 兜底导致逐帧闪烁与画面抖动。
2. **零冲突独立防守**：对不同视图控制器（Feed 首页、详情页、作品页、搜索页）建立独有的几何与避让规则，互不牵连。
3. **DYYY 优雅协同**：通过动态检测 `DYYYEnableFullScreen` 开关，当 DYYY 开启全屏时自动让出控制权；当 DYYY 关闭全屏时，由 DYKiller 独立提供全套全屏支持。

---

## 2. 抖音 39.8.0 核心页面分区与布局矩阵

抖音在不同功能场景下采用了不同的 `UIViewController` 和 `UITableView` 组合。DYKiller 将全 App 的视频播放场景收敛为以下 5 大核心分区：

| 页面分区类型 | 宿主控制器 (ViewController) | 核心表/容器视图 (View) | 表高 (Height) | HUD 文案避让 (Bottom Margin) |
| :--- | :--- | :--- | :--- | :--- |
| **1. 首页 Recommendation Feed** | `AWEFeedCellViewController` | `AWEFeedTableView` | 物理全高 (`874pt`) | 沉底避让 Safe Area，底部 TabBar 透明化 |
| **2. 经验视频/详情页视频** | `AWEAwemeDetailTableViewController` | `AWEAwemeDetailTableView` | 物理全高 (`874pt`) | `safeAreaInsets.bottom + 48pt` 避让 |
| **3. 搜索结果播放页** | `AWESearchViewController` -> Detail | `AWEAwemeDetailTableView` | 物理全高 (`874pt`) | `safeAreaInsets.bottom` 避让顶部/底部元素 |
| **4. 个人主页/他人作品页** | `AWEAwemeDetailTableViewController` | `AWEAwemeDetailTableView` | 物理全高 (`874pt`) | 原生 Stack 垂直排列（`safeAreaInsets.bottom + 48pt`） |
| **5. 图文/多图文播放页** | `RichContentContainerViewController` | `AWEStoryContainerCollectionView` | 物理全高 (`874pt`) | 背景渐变层伸展，文案自然置底 |
| **特殊放行区 (Chat & Live)** | `AWEAwemeDetailTableViewController` | 聊天/直播特化 Cell | 宿主原生高度 | 保持原生约束，避免覆盖输入框与直播弹幕 |

---

## 3. 核心 Hook 源码映射与职责划分

DYKiller 的全屏功能分布在 `src/Features/VideoFullscreen/` 目录下的 3 个核心 Hook 文件与 1 个 Debug 工具文件中：

### 3.1 `DKVideoGeometry.xm` —— 全局视频容器几何拦截
* **职责**：作为全项目**唯一的全局 `UIView setFrame:` 拦截点**。
* **主要逻辑**：
  * 对 `AWEDPlayerViewController_Merge`（视频播放器容器）进行目标尺寸算力修正 (`DKVideoContainerTargetFrame`)。
  * 对竖屏比例达标（Aspect Ratio $\ge 1.70$）的视频强制拉满整屏；对横屏或图文视频保持自然比例，防止 Aspect-Fill 过裁。
  * 评论区展开/拖拽时拦截视频位置挪动（`gMoveWrites`），保持视频播放器在原点静止，实现评论区毛玻璃冻结效果。

### 3.2 `DKVideoFeedTable.xm` —— 视频表尺寸撑高
* **职责**：修复 `AWEFeedDataSafeTableView` / `AWEFeedTableView` / `AWEAwemeDetailTableView` 因原生底栏预留空间导致的 `799pt` 压缩问题。
* **主要逻辑**：
  * `%hook AWEAwemeDetailTableView` 与 `%hook AWEFeedTableView`：拦截 `setFrame:` 写入，计算屏幕物理高度余数 `remainder`，将其修饰拉伸至物理屏幕全高 (`874pt`)。
  * 记下表在撑高前的原始高度 `originalHeight`，作为 HUD 交互层的参考依据。

### 3.3 `DKVideoPageChrome.xm` —— HUD 交互层防重叠与元素避让
* **职责**：管理视频浮层文案（昵称、文字描述、话题）、合集栏（Mix Video）、防沉迷提示栏（Notice Bar）及顶部黑遮罩。
* **反向精准排除算法** (`DKInteractionUsesFullHeight`)：
  ```objc
  static BOOL DKInteractionUsesFullHeight(UIViewController *interaction) {
      NSString *refer = nil;
      if ([interaction respondsToSelector:@selector(referString)]) {
          refer = [interaction performSelector:@selector(referString)];
      }
      // 仅在用户个人作品页（personal_homepage / others_homepage / user_post）预留 75pt 空间，
      // 以防止合集栏与防沉迷栏重叠；
      // 其余所有场景（经验视频 homepage_fresh、精选页、群聊 chat、搜索 general_search、首页推荐等）一律满高 (874pt)。
      if (refer && (
          [refer isEqualToString:@"personal_homepage"] ||
          [refer isEqualToString:@"others_homepage"] ||
          [refer isEqualToString:@"user_post"]
      ) && !DKNavigationCameFromSearch(interaction)) {
          return NO;
      }
      return YES;
  }
  ```
* **关键防重叠过滤算法** (`DKIsAuthorDescriptionStack`)：
  ```objc
  static BOOL DKIsAuthorDescriptionStack(UIView *view) {
      if (![view isKindOfClass:NSClassFromString(@"AWEElementStackView")]) return NO;
      for (UIView *sub in view.subviews) {
          NSString *clsName = NSStringFromClass([sub class]);
          // 过滤合集栏 (Mix)、防沉迷/提示栏 (Notice)、广告 Banner 容器
          if ([clsName containsString:@"Notice"] || [clsName containsString:@"Mix"] || [clsName containsString:@"Banner"]) {
              return NO;
          }
      }
      return YES;
  }
  ```
  * **避坑防重叠机制**：抖音会在 `AWEPlayInteractionViewController` 中包含多个 `AWEElementStackView` 容器。通过类名特征判断，防止将合集栏（`AWEMixVideoPanel`）和防沉迷提示栏（`AWEAntiAddictedNoticeBarView`）强行移动到与作者描述文案同一 Y 坐标，彻底杜绝元素完全重叠错乱。

### 3.4 `DKNetworkLogger.xm` —— 全局 API 网络请求日志引擎
* **职责**：在后台实时拦截并记录 `TTNetworkManager` 的所有 API 联网请求。
* **功能**：自动将请求 URL、HTTP Method、时间戳与 HTTP Status 格式化输出至 `probe/network_requests.txt`，并在点击“导出调试 ZIP”或调试小钥匙菜单开关控制时自动打包导出。

---

## 4. DYYY 互斥与协同机制

DYKiller 实现了对 DYYY 插件的动态感应：

```objc
BOOL DKVideoGeometryOwnedByDYYY(void) {
    return DKDYYYImageLoaded()
        && [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableFullScreen"];
}
```

1. 当用户同时安装了 DYYY 并且在 DYYY 设置中**开启了全屏**，`DKVideoGeometryOwnedByDYYY()` 返回 `YES`，DYKiller 会静默让出控制权，避免双重 Hook 产生布局冲突。
2. 当用户在 DYYY 中**关闭了全屏**，DYKiller 独立全面接管，在首页、经验视频、搜索页、用户作品页提供无缝的全屏拉伸与 HUD 避让支持。

---

## 5. 关键 Bug 防御与踩坑总结

1. **不可直接修改 `AWEPlayInteractionViewController.view.frame`**：
   在 `viewDidLayoutSubviews` 中直接强行修改 `AWEPlayInteractionViewController.view.frame` 会触发递归 Layout 通道，破坏 `AWEFeedTableView` 的手势识别器（`UIGestureRecognizer`），导致手势失效、卡死、滑动白屏。
2. **多 StackView 动态解耦**：
   抖音 39.8.0 引入了极其动态的模组化 Stack 架构。视频 HUD 内可能并行存在 3~4 个 Stack 容器，绝对不能使用遍历统一改坐标的方式处理，必须使用 `DKIsAuthorDescriptionStack` 进行特征隔离。
3. **反向排除法判定页面满高（0.5.5-beta46+ 经验视频与精选页突破）**：
   正向白名单极易漏掉特定场景的 `referString`（如经验视频的 `homepage_fresh` 或精选页）。通过反向排除法，仅将明确需要预留合集栏高度的 `personal_homepage` / `others_homepage` 列为例外，其余全局默认 `874pt` 满高，一举解决所有派生分区的文案偏高与避让问题。

---
*文档更新时间：2026-08-15 | Antigravity AI Codebase Docs*
