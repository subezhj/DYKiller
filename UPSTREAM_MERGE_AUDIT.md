# 自定义功能整理与上游合并评估

评估日期：2026-10-19。第 1–7 节保留最初评估快照；实际整合进展见第 8 节。

## 1. 基线与结论

- 当前工作区：`main`，`aff2417`，0.5.5-beta153，工作区原先干净。
- 自有远端：`https://github.com/subezhj/DYKiller.git`，`origin/main = 3d7a3ae`。
- 原仓库：`https://github.com/HierarchThurs/DYKiller.git`，`upstream/main = 7019f3b`，0.6.3，2026-10-18。
- 共同祖先：`fea0673ed545d8ae3615c0085378a89da9d9ce42`。
- 相对共同祖先：自有远端独有 164 个提交，上游独有 65 个提交。上游修改 160 个文件，自有远端修改 41 个文件。
- 可以整合，但不能直接自动合并后发布。`git merge-tree --write-tree --name-only origin/main upstream/main` 模拟得到 15 个文本冲突；没有文本冲突的文件仍有接口和运行行为风险。
- 建议以自有远端最新修复为定制基线，引入上游设置框架和新增模块，逐项移植自定义功能；保留完整合并历史，在独立整合分支验证。

## 2. 已找到的历史资料

- 当前目录 `DOCS/ITERATION_LOOP_CHANGELOG.md`：即本次找到的 Loop 记录，记录延伸到 beta153；开头的适用版本及末尾更新时间已经落后，不能据此判定实现状态。
- `DOCS/FULLSCREEN_LAYOUT.md`、`DOCS/BACKDROP_DIAGNOSIS_ARCHITECTURE.md`、`DOCS/SCENE_CLASSIFICATION_ANALYSIS.md`：布局与背景诊断资料。
- 自有远端新增 `code-arch.md`：beta153 审核及 beta154 修复记录，本地 HEAD 尚无该文件。
- 在当前及父目录递归查找，没有找到另一个以 code_loop 命名的文件。
- `DOCS/` 被 Git 忽略，因此本报告置于仓库根目录，便于后续随代码跟踪。

## 3. 自定义功能保留清单

以下按用户指出的保留范围整理。部分基础功能在共同祖先中已存在；“保留”表示保留当前定制行为，不把整个模块都归为本分支原创。具体差异以共同祖先到 `origin/main` 的 diff 为准。

| 功能组 | 当前实现与配置 | 整合要求 |
|---|---|---|
| 调试工具 | `src/Debug/DKDebugInspector.m`、`DKDebugCapture.m`、`DKDebugExport.m`、`DKHookLogger.mm`；全局扳手、横竖屏入口、阶段开始/停止抓取、ZIP 导出 | 保留操作链、阶段日志和导出目录；叠加上游 FLEXKing Provider 与新增诊断字段 |
| 抓包工具 | `src/Debug/DKNetworkLogger.xm`，`DYKillerNetworkLoggerEnabled`；Inspector 中可切换，导出 `probe/network_requests.txt` | 保留网络记录入口与导出；采用 beta154 默认关闭与时间格式器缓存修复；与净化模块共同检查网络 Hook |
| 播放体验 | `DKHideMusicInfo.xm`、`DKTransparentMixBar.xm`、`DKChatVideoBottomBar.xm`、`DKHideFollowButton.xm`；音乐按钮文字隐藏、合集条背景透明、详情底栏移除、关注按钮处理 | 保留自定义入口；上游三档显示/隐藏/移除与旧配置迁移统一处理，避免旧 Hook 与新播放页精简同时控制同一元素 |
| 评论区 | `DKCommentGlass.xm`、`DKCommentBottomBar.xm`、`DKCommentMediaCleaner.xm`、`DKCommentFullBackdrop.xm`；自定义圆角、玻璃与底栏行为 | 上游新版输入区玻璃结构作为兼容基础，移植自定义圆角等差异；保留 beta154 热路径守卫；验证回复、艾特、表情和大图分页 |
| 自适应与实验功能 | `DKExperimentalFeatures.xm`；非全屏背景默认/深灰/主色自适应、官方 Model 背景通道、DYYY 优先让权、POI 文案统一、ProMotion、后台缓存处理 | 保留模式值和 DYYY 让权；与全屏、底栏透明背景同步审查；沿用 beta154 缓存与后台入口修复 |
| 净化与搜索 | `DKJunkResourceBlocker.xm`、`DKSearchTrendingBlocker.xm`；热榜、推荐词、营销、电商、Lynx、挂件过滤 | 保留独立配置和过滤范围；与上游 ContentFilter 按“请求/模型/列表/视图”区分职责，避免重复丢弃同一内容或误伤预加载 |
| 个人主页 | `DKProfileCleaner.xm`；发作品引导、新访客入口隐藏 | 上游只迁移了基础项注册方式；新访客键和行必须显式加入新设置布局，自动合并并不保证入口可用 |
| 底栏 | `DKGlassTabBar.xm`、`DKFavoriteGlassBackdrop.xm`；底部交互与进度条抬升 0/4/8/12/16pt、整栏隐藏、收藏页背景 | 保留抬升档位与整栏隐藏优先级；区分上游单项移除、互动区位移和底栏外观；防止多处偏移叠加 |
| 视频 | `DKVideoGeometry.xm`、`DKVideoFeedTable.xm`、`DKVideoPageChrome.xm`、`DKProgressUnderline.xm`、`DKFluidGestures.xm` | 保留三档全屏（关闭/填充/原比例）、Metal 视口钳制、自适应背景、可读性目标、清屏保留进度条、双指手势；移入上游详情表分页修复 |
| 播放器 | 同上；原生 AVPlayer、Metal 锐化/色彩增强、渲染管道优化 | 保留为实验项；历史报告已明确 Metal layer.filters 实效与原生播放器枚举尚待真机验证，不标记为已验证能力 |
| 后台与音频 | `Background/DKMediaIsland.xm`、`DKPiPQuickLaunch.xm`、TabBar 音频可视化及 Shared 音频链 | 纳入 beta154 离线 PiP、资源释放修复与上游音频取样状态修复；已被 beta154 删除的空 LiveActivity 实现不复活 |

## 4. 自有远端尚未进入本地的修复

本地落后自有远端 3 个提交，应先作为整合输入，不应只以本地 beta153 为基线：

1. `8ee1bfc`：死开关、功能缺陷与热路径修复，包括整栏隐藏实现、默认全屏值、网络日志默认值、实验功能缓存、LiveActivity 空实现下架等。
2. `7518ba8`：PiP 编译修复，`addInput:` 返回 void 的处理与 AVPlayerLooper 构造修正。
3. `3d7a3ae`：本地参考仓库及调试资料忽略规则。

## 5. 上游更新的主要价值

| 更新组 | 代表提交 | 对本分支的价值与注意事项 |
|---|---|---|
| 新版兼容、评论与分享玻璃 | `f56682d`、`c97ee7f`、`d6518d5`、`7779de5` | 更新运行时类与输入面板处理；评论玻璃变化较大，应在新版实现上保留自定义项 |
| 全屏与分页 | `97ffb9e`、`58c1e8c`、`3b2084d` | 修复直播 HUD、用户主页全屏、详情分页和评论大图分页；不能退回上游单 BOOL 全屏而丢弃本分支三档模式 |
| 设置与备份 | `f1ec2e2`、`c320be5`、`636b45a`、`3af56ee` | 分组子页、联动、统一值声明和备份恢复；这是迁移自定义功能的先决框架 |
| 内容过滤 | `ba5aed2`、`c0a9ce0` | 低赞、直播、广告、推荐音乐与热点过滤；与自定义请求拦截和净化组合检查 |
| 交互与外观 | `994bcac`、`024d7ba`、`bb63ed2`、`fe21df4`、`abcdd02` | 双击评论、底栏图标文字、互动按钮和昵称文案外观；与双指手势、底部抬升、可读性增强检查组合 |
| 播放页与评论顶部精简 | `7781dba`、`ad79218`、`a12a64a` | 三档元素控制与旧键迁移；需收敛重复 Hook，防止新迁移删除了仍被旧实现读取的配置 |
| 进度条与时间 | `f45610a`、`00fc081`、`f1f93ae` | 常显、即时刷新、已播/总时长与多位置布局；检查自定义隐藏进度条、清屏保留和抬升组合 |
| 媒体保存 | `7a0f007`、`f447219`、`a2e7c7a`、`ec96e79` | 新增作品、评论、表情媒体保存，主体为新增模块；仍依赖新设置系统、头文件和框架链接 |
| 音频与诊断 | `af6c50e`、`34d503d`、`54bbcb1` | 音频取样切换修复、FLEXKing 接入和更完整诊断；应与自定义抓包和阶段抓取一起保留 |

## 6. 模拟合并结果与语义风险

文本冲突共 15 个：

```text
.gitignore
Makefile
README.md
control
src/Features/Comment/DKCommentGlass.xm
src/Features/Feed/DKHideMusicInfo.xm
src/Features/TabBar/DKGlassTabBar.xm
src/Features/VideoFullscreen/DKProgressUnderline.xm
src/Features/VideoFullscreen/DKVideoFeedTable.xm
src/Features/VideoFullscreen/DKVideoGeometry.xm
src/Headers/DouyinHeaders.h
src/Settings/DKSettings.h
src/Settings/DKSettingsMenu.xm
src/Shared/DKKeys.h
src/Shared/DKUtils.m
```

最关键的非文本冲突：

1. **设置 API 已替换。** 上游用 `DKSettingsRegister(key, builder)` 替代 `DKSettingsRegisterItem(section, builder)`，布局由 `DKSettingsLayout.m` 显式定义。自定义模块必须迁移注册方式和布局；旧 `DKMakeButton`、`DKMakeChoiceWithMessage` 等调用也要适配。仅保留文件会导致编译失败、未归类入口或缺少备份声明。
2. **全屏配置模型不同。** 本分支 `DYKillerVideoFullscreenMode` 存三档，上游仍用 `DYKillerVideoFullscreen` BOOL。要统一读取、迁移默认值及新旧键关系，保持原比例模式和关闭语义。
3. **上游会删除部分旧键。** `DKSettingsMigration.m` 将音乐信息、评论底栏、关注按钮旧键迁到三档并删除旧值。如果保留仍读旧键的自定义代码，会静默失效。
4. **几何 Hook 可能叠加。** 即使 `DKVideoPageChrome.xm` 自动合并，上游互动外观、进度条时间、底栏背景与本分支 setFrame/Metal/背景同步仍可能同时操作同一视图，必须核对调用顺序及关闭恢复。
5. **构建配置应取并集。** 本分支需要 AVFoundation/CoreMedia/MediaToolbox/AVKit 等，上游媒体保存有额外依赖；不能对 Makefile 简单选一侧。
6. **备份覆盖不是自动完成。** 所有新增自定义设置需有正确类型、范围、默认值、onChange 与备份声明；调试临时状态应排除。

## 7. 推荐落地顺序与验证门槛

1. 从 `origin/main` 建立 `codex/integrate-upstream-0.6.3` 整合分支，保留当前 main 作为 beta153 参照。
2. 合并固定的上游提交 `7019f3b`；先处理设置系统、头文件、键与共享工具，再处理功能冲突。禁止整文件统一选 ours/theirs。
3. 迁移上表所有自定义设置到新版注册/布局/备份系统，建立键清单核查；保留原值，确需换键时显式迁移。
4. 将全屏几何、底栏抬升、进度条、背景同步作为同一组合处理；将播放精简与净化规则中的重叠 Hook 收敛。
5. 静态检查无冲突标记、无重复声明、无未实现旧 API、无已删键引用；进行 arm64/arm64e 构建，检查 rootful/rootless/roothide 产物。
6. 真机回归：三档全屏 × 玻璃底栏开关 × 整栏隐藏 × 抬升档位；自适应/DYYY 背景；首页/搜索详情/用户作品/横屏/直播/图文；回复/艾特/表情/评论大图；调试阶段抓取、抓包导出；旧配置升级和备份往返；音频可视化、PiP 后台恢复。

本轮完成了历史梳理、远端抓取、差异分析和模拟合并。尚未进行实际代码整合、编译或真机回归；当前环境未检出 make/clang 命令，不能声称通过 Theos/iOS 构建。

## 8. 实际整合记录（2026-10-19）

- 参考 tag：`reference/custom-beta153-20261019`，指向原本地 HEAD `aff2417`，保留原代码。
- 整合分支：`codex/integrate-upstream-0.6.3`，从 `origin/main = 3d7a3ae` 开始，包含自有远端三个修复提交。
- 上游合并目标固定为 `7019f3b`，整合版本号为 `0.6.3-custom1`。
- 15 处文本冲突已处理。采用新版设置框架，迁移自定义注册和说明 API，新增“自定义功能”子页收纳原有定制配置；全屏三档入口替换上游单开关入口。
- 音乐信息、关注按钮、评论底栏使用上游三档显示模式及旧键迁移；自定义音乐按钮文字、合集透明、新访客净化独立保留。
- 全屏三档、DYYY 几何让权、原比例渲染、底部抬升、自适应背景、抓包与阶段日志保留；引入上游详情表布局准备和分页修复，详情表使用同一 DYYY 让权判据。
- 合并重复私有类声明，保留双方成员；Makefile 框架取并集并显式链接 CoreImage；去除渲染优化设置的重复注册。
- 自定义取色保留上游图标与选中/未选中样式；关闭玻璃底栏会调用拆除路径。设置改动副作用接入统一 onChange，使备份恢复也能刷新相关界面。
- 建页过程不再写入全屏迁移、可读性和抬升默认值；迁移在启动时执行，其他默认值通过 registerDefaults 注册，避免备份预览建项改动持久化值。
- 抓包开关作为设备临时调试状态排除备份，与调试工具一致。

验证：`python .github/scripts/check-integration.py` 检查 194 个源/头文件、133 个设置注册，覆盖冲突标记、括号、Logos 作用域、本地头文件、重复声明、注册与布局对应关系；所有自有远端新增源文件均保留。该脚本为静态检查，不能替代 Logos 预处理、Clang 编译、链接与真机测试。

仍需验证：Theos 的 arm64/arm64e 与三种打包方案；全屏/底栏/背景组合；评论回复与大图分页；抓包与 ZIP；设置升级、备份恢复；音频与 PiP。Windows 当前未配置 make/clang，WSL 不可用，因此尚未取得编译及真机验证结果。

组合约定：自定义“隐藏视频进度条”保留其原默认开启行为，优先于上游“进度条常显”的视觉显示；需要显示上游新增进度条与时长效果时，先关闭自定义隐藏项。底部抬升与上游互动区位移可同时设置，组合效果需要真机确认。

本地完成整合后仍不代表可发布版本。未向 GitHub 推送 tag、分支或触发 CI，也未发布安装包。
