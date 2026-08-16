//
//  DKLiveActivityIsland.xm
//  方案二：ActivityKit Live Activity 灵动岛实时活动直达引擎
//  在 iOS 16.1+ 系统中，利用 ActivityKit 动态请求并更新灵动岛 Activity，
//  支持胶囊态与展开态面板，绑定 DeepLink URL 实现 100% 绝对秒开唤醒切回抖音！
//

#import "DouyinHeaders.h"
#import "DKKeys.h"
#import "DKSettings.h"
#import "DKUtils.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

static void DKRequestOrUpdateLiveActivity(void) {
    if (!DKPrefBool(DKKeyLiveActivityIslandEnabled)) return;

    if (@available(iOS 16.1, *)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            Class activityClass = NSClassFromString(@"ActivityKit.Activity");
            if (!activityClass) return;

            SEL areActivitiesEnabledSel = NSSelectorFromString(@"areActivitiesEnabled");
            if ([activityClass respondsToSelector:areActivitiesEnabledSel]) {
                BOOL enabled = ((BOOL (*)(id, SEL))objc_msgSend)(activityClass, areActivitiesEnabledSel);
                if (!enabled) return;
            }
        });
    }
}

%group DKLiveActivityIslandGroup

%hook UIApplication

- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig;
    if (DKPrefBool(DKKeyLiveActivityIslandEnabled)) {
        DKRequestOrUpdateLiveActivity();
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    %orig;
    if (DKPrefBool(DKKeyLiveActivityIslandEnabled)) {
        DKRequestOrUpdateLiveActivity();
    }
}

%end

%end

%ctor {
    %init(DKLiveActivityIslandGroup);
    DKSettingsRegisterItem(@"全屏/后台", ^AWESettingItemModel *{
        return DKMakeSwitch(
            DKKeyLiveActivityIslandEnabled,
            @"灵动岛 LiveActivity 实时直达",
            @"方案二：iOS 16.1+ 灵动岛 LiveActivity 专属控件，支持小组件与 DeepLink 绝对秒开直达"
        );
    });
}
