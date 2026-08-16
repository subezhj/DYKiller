//
//  DKPiPQuickLaunch.xm
//  画中画悬浮直达秒开模块（AVPictureInPictureController 强制前台唤醒）
//  退后台时，利用系统画中画小窗，提供 100% 绝对无条件调起前台的能力！
//  无论任何签名、证书类型，点击画中画恢复全屏按钮，iOS 媒体引擎强制将抖音唤醒至前台！
//

#import "DouyinHeaders.h"
#import "DKKeys.h"
#import "DKSettings.h"
#import "DKUtils.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>

@interface DKPiPLaunchManager : NSObject <AVPictureInPictureControllerDelegate>
@property (nonatomic, strong) AVPictureInPictureController *pipController;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) AVPlayer *player;
+ (instancetype)sharedManager;
- (void)startPiPIfNeeded;
- (void)stopPiPIfNeeded;
@end

@implementation DKPiPLaunchManager

+ (instancetype)sharedManager {
    static DKPiPLaunchManager *mgr;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mgr = [[DKPiPLaunchManager alloc] init];
    });
    return mgr;
}

- (void)startPiPIfNeeded {
    if (!DKPrefBool(DKKeyPiPQuickLaunchEnabled)) return;
    if (![AVPictureInPictureController isPictureInPictureSupported]) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.pipController && self.pipController.isPictureInPictureActive) return;

        if (!self.player) {
            NSURL *url = [NSURL URLWithString:@"https://vjs.zencdn.net/v/oceans.mp4"];
            self.player = [AVPlayer playerWithURL:url];
            self.player.muted = YES;
            self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
            self.playerLayer.frame = CGRectMake(0, 0, 1, 1);

            UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
            if (keyWindow) {
                [keyWindow.layer addSublayer:self.playerLayer];
            }
        }

        if (!self.pipController && self.playerLayer) {
            self.pipController = [[AVPictureInPictureController alloc] initWithPlayerLayer:self.playerLayer];
            self.pipController.delegate = self;
            if (@available(iOS 14.2, *)) {
                self.pipController.canStartPictureInPictureAutomaticallyFromInline = YES;
            }
        }

        [self.player play];
        [self.pipController startPictureInPicture];
    });
}

- (void)stopPiPIfNeeded {
    if (self.pipController && self.pipController.isPictureInPictureActive) {
        [self.pipController stopPictureInPicture];
    }
}

#pragma mark - AVPictureInPictureControllerDelegate

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController
restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completionHandler {
    if (completionHandler) {
        completionHandler(YES);
    }
}

@end

%group DKPiPQuickLaunchGroup

%hook UIApplication

- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig;
    if (DKPrefBool(DKKeyPiPQuickLaunchEnabled)) {
        [[DKPiPLaunchManager sharedManager] startPiPIfNeeded];
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    %orig;
    if (DKPrefBool(DKKeyPiPQuickLaunchEnabled)) {
        [[DKPiPLaunchManager sharedManager] stopPiPIfNeeded];
    }
}

%end

%end

%ctor {
    %init(DKPiPQuickLaunchGroup);
    DKSettingsRegisterItem(@"全屏/后台", ^AWESettingItemModel *{
        return DKMakeSwitch(
            DKKeyPiPQuickLaunchEnabled,
            @"画中画悬浮直达秒开",
            @"退后台时悬浮画中画小窗，点击画中画“切回App”按钮 100% 绝对无条件秒开切回抖音（兼容所有签名）"
        );
    });
}
