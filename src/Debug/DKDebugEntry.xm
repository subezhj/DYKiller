//
//  DKDebugEntry.xm
//  DYKiller
//
//  注册调试开关，并在前台窗口变化时同步全局调试浮层。
//

#import "DKDebugInspector.h"
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
        return DKMakeFLEXButtonItem();
    });
    DKDebugInspectorInstall();
}
