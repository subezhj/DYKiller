//
//  DKMediaIsland.xm
//  灵动岛媒体直达唤醒模块（方案一：MPNowPlayingInfoCenter 媒体灵动岛）
//  在后台或锁屏时，向系统 MPNowPlayingInfoCenter 写入元数据，激活灵动岛媒体卡片与波形指示器。
//  用户在桌面或任何第三方 App 中点击灵动岛，系统自动将抖音唤醒至前台！
//

#import "DouyinHeaders.h"
#import "DKKeys.h"
#import "DKSettings.h"
#import "DKUtils.h"
#import "DKHookLogger.h"
#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

static void DKSetupRemoteCommandsIfNeeded(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
        [commandCenter.playCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
            return MPRemoteCommandHandlerStatusSuccess;
        }];
        [commandCenter.pauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
            return MPRemoteCommandHandlerStatusSuccess;
        }];
        [commandCenter.togglePlayPauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
            return MPRemoteCommandHandlerStatusSuccess;
        }];
    });
}

static void DKUpdateMediaIslandState(void) {
    if (!DKPrefBool(DKKeyMediaIslandEnabled)) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        NSError *error = nil;
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryPlayback error:&error];
        [session setActive:YES error:&error];

        DKSetupRemoteCommandsIfNeeded();

        Class infoCenterClass = NSClassFromString(@"MPNowPlayingInfoCenter");
        if (!infoCenterClass) return;

        id defaultCenter = [infoCenterClass performSelector:@selector(defaultCenter)];
        if (!defaultCenter || ![defaultCenter respondsToSelector:@selector(setNowPlayingInfo:)]) return;

        NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier] ?: @"com.ss.iphone.ugc.Aweme";

        NSMutableDictionary *info = [NSMutableDictionary dictionary];
        info[MPMediaItemPropertyTitle] = @"抖音 · 点击返回前台";
        info[MPMediaItemPropertyArtist] = @"DYKiller 灵动岛直达";
        info[MPNowPlayingInfoPropertyPlaybackRate] = @1.0;
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @1.0;
        info[MPMediaItemPropertyPlaybackDuration] = @100.0;

        if (@available(iOS 13.0, *)) {
            info[MPNowPlayingInfoPropertyServiceIdentifier] = currentBundleID;
        }

        [defaultCenter setNowPlayingInfo:info];
        DKLogHookEvent(@"MediaIsland", @"setNowPlayingInfo", [NSString stringWithFormat:@"BundleID=%@", currentBundleID]);
    });
}

%group DKMediaIslandGroup

%hook UIApplication

- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig;
    if (DKPrefBool(DKKeyMediaIslandEnabled)) {
        DKUpdateMediaIslandState();
    }
}

- (void)applicationWillResignActive:(UIApplication *)application {
    %orig;
    if (DKPrefBool(DKKeyMediaIslandEnabled)) {
        DKUpdateMediaIslandState();
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    %orig;
    if (DKPrefBool(DKKeyMediaIslandEnabled)) {
        // 切回前台后可更新或清理
    }
}

%end

%end

%ctor {
    %init(DKMediaIslandGroup);
    DKSettingsRegisterItem(@"全屏/后台", ^AWESettingItemModel *{
        return DKMakeSwitch(
            DKKeyMediaIslandEnabled,
            @"灵动岛媒体直达唤醒",
            @"退后台时在灵动岛常驻媒体波形胶囊，点击灵动岛即可瞬间秒开切回抖音（兼容所有个人证书自签 IPA）"
        );
    });
}
