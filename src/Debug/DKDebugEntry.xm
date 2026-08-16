//
//  DKDebugEntry.xm
//  DYKiller
//
//  注册调试开关，并在前台窗口变化时同步全局调试浮层。
//

#import "DKDebugInspector.h"
#import "DKDebugCapture.h"
#import "DKDebugExport.h"
#import "DKHookLogger.h"
#import "DKAudioProbe.h"
#import "DKKeys.h"
#import "DKSettings.h"

static BOOL DKEntryIsDebugWindow(UIWindow *window) {
    return [NSStringFromClass(window.class) hasPrefix:@"DKDebug"];
}

static AWESettingItemModel *DKMakeDebugSwitch(void) {
    AWESettingItemModel *item = DKMakeSwitch(DKKeyDebugInspectorEnabled, @"调试工具", @"开启后显示全局扳手入口");
    void (^origBlock)(void) = [item.switchChangedBlock copy];
    item.switchChangedBlock = ^{
        if (origBlock) origBlock();
        DKAudioProbePreferenceDidChange();
        DKDebugInspectorRefreshOverlay();
    };
    return item;
}

%hook UIWindow

- (void)becomeKeyWindow {
    %orig;
    if (!DKEntryIsDebugWindow(self)) DKDebugInspectorRefreshOverlay();
}

- (void)makeKeyAndVisible {
    %orig;
    if (!DKEntryIsDebugWindow(self)) DKDebugInspectorRefreshOverlay();
}

- (void)setHidden:(BOOL)hidden {
    %orig(hidden);
    if (!hidden && !DKEntryIsDebugWindow(self)) DKDebugInspectorRefreshOverlay();
}

%end

static AWESettingItemModel *DKMakeCaptureButtonItem(void) {
    BOOL capturing = DKIsLogCapturing();
    NSString *title = capturing ? @"⏹️ 停止抓取并提示导出 (录制中...)" : @"▶️ 开启调试数据抓取 (阶段性数据抓取)";
    NSString *detail = capturing ? @"正在录制 Hook 与网络/性能数据，点击停止抓取" : @"点击开启阶段性抓取，刷几个视频后点击【停止并导出】";

    return DKMakeButton(title, detail, ^{
        if (DKIsLogCapturing()) {
            DKStopLogCapture();
            UIWindow *window = DKDebugTargetWindow();
            UIViewController *topVC = DKDebugTopPresenter(window);
            if (topVC) {
                UIAlertController *toast = [UIAlertController alertControllerWithTitle:@"⏹️ 调试抓取已关闭"
                                                                               message:@"抓取已结束！请点击界面悬浮小钥匙【导出本页 zip】或【停止并导出】即可分享当前阶段的调试数据包！"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [toast addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
                [topVC presentViewController:toast animated:YES completion:nil];
            }
        } else {
            DKStartLogCapture();
            UIWindow *window = DKDebugTargetWindow();
            UIViewController *topVC = DKDebugTopPresenter(window);
            if (topVC) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"▶️ 调试抓取已开启"
                                                                               message:@"现已开始记录 Hook 与网络/性能数据。\n请任意刷几个视频或执行操作，完成后点击悬浮小钥匙选【停止并导出】即可！"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
                [topVC presentViewController:alert animated:YES completion:nil];
            }
        }
    });
}

static AWESettingItemModel *DKMakeFLEXButtonItem(void) {
    return DKMakeButton(@"打开 FLEX++ 调试面板", @"调出/隐藏 FLEX++ 运行时 UI 层级与 API 调试工具栏", ^{
        if (!DKToggleFLEXExplorer()) {
            UIWindow *window = DKDebugTargetWindow();
            UIViewController *topVC = DKDebugTopPresenter(window);
            if (topVC) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"FLEX++ 提示"
                                                                               message:@"未在进程中检测到 FLEX++.dylib！\n\n请在签名或打包 IPA 时添加注入 FLEX++.dylib 即可开启完整 FLEX 调试功能！"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:nil]];
                [topVC presentViewController:alert animated:YES completion:nil];
            }
        }
    });
}

%ctor {
    DKAudioProbeInstallIfEnabled(YES);
    DKSettingsRegisterItem(@"调试", ^AWESettingItemModel *{
        return DKMakeDebugSwitch();
    });
    DKSettingsRegisterItem(@"调试", ^AWESettingItemModel *{
        return DKMakeCaptureButtonItem();
    });
    DKSettingsRegisterItem(@"调试", ^AWESettingItemModel *{
        return DKMakeFLEXButtonItem();
    });
    DKDebugInspectorInstall();
}
