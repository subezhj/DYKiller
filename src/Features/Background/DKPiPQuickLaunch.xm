//
//  DKPiPQuickLaunch.xm
//  画中画悬浮直达:退后台时用本地生成的小视频激活系统画中画,
//  点击画中画恢复按钮把抖音带回前台。
//
//  素材为首次使用时在本地生成的 2 秒灰片(240×160 / 10fps / 循环):
//  不联网、无第三方依赖、可离线、不耗流量;生成失败本次静默放弃,下次退后台再试。
//  回前台停止画中画并暂停播放器,不占用解码;失败回调同样收敛到暂停。
//

#import "DouyinHeaders.h"
#import "DKKeys.h"
#import "DKSettings.h"
#import "DKUtils.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <unistd.h>

#pragma mark - 本地素材

static NSString *const kDKPiPClipName = @"dk-pip-launch.mp4";

static id DKPiPClipLock(void) {
    static id lock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ lock = [NSObject new]; });
    return lock;
}

// 生成 240×160 的 2 秒灰片。已存在则直接复用;失败返回 nil。
// 只在后台队列调用(生成含忙等),不在主线程执行。
static NSURL *DKPiPLocalClipURL(void) {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:kDKPiPClipName];
    NSURL *fileURL = [NSURL fileURLWithPath:path];
    NSFileManager *fileManager = NSFileManager.defaultManager;
    if ([fileManager fileExistsAtPath:path]) return fileURL;

    @synchronized(DKPiPClipLock()) {
        if ([fileManager fileExistsAtPath:path]) return fileURL;

        NSError *error = nil;
        AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:fileURL
                                                           fileType:AVFileTypeMPEG4
                                                              error:&error];
        if (!writer || error) return nil;

        NSDictionary *settings = @{
            AVVideoCodecKey: AVVideoCodecTypeH264,
            AVVideoWidthKey: @240,
            AVVideoHeightKey: @160,
        };
        AVAssetWriterInput *input =
            [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                outputSettings:settings];
        input.expectsMediaDataInRealTime = NO;
        AVAssetWriterInputPixelBufferAdaptor *adaptor =
            [AVAssetWriterInputPixelBufferAdaptor
                assetWriterInputPixelBufferAdaptorWithAssetWriterInput:input
                                        sourcePixelBufferAttributes:nil];
        if (![writer canAddInput:input]) {
            [writer cancelWriting];
            return nil;
        }
        // SDK 里 addInput: 返回 void，能不能加只能用 canAddInput: 判断。
        [writer addInput:input];

        CVPixelBufferRef buffer = NULL;
        CVPixelBufferCreate(kCFAllocatorDefault, 240, 160,
                            kCVPixelFormatType_32BGRA, NULL, &buffer);
        if (!buffer) {
            [writer cancelWriting];
            return nil;
        }
        CVPixelBufferLockBaseAddress(buffer, 0);
        memset(CVPixelBufferGetBaseAddress(buffer), 0x30, CVPixelBufferGetDataSize(buffer));
        CVPixelBufferUnlockBaseAddress(buffer, 0);

        [writer startWriting];
        [writer startSessionAtSourceTime:kCMTimeZero];
        CMTime frameDuration = CMTimeMake(1, 10);
        for (int32_t i = 0; i < 20; i++) {
            while (!input.isReadyForMoreMediaData) usleep(5000);
            [adaptor appendPixelBuffer:buffer
                   withPresentationTime:CMTimeMultiply(frameDuration, i)];
        }
        CVPixelBufferRelease(buffer);
        [input markAsFinished];
        [writer finishWritingWithCompletionHandler:^{}];
        while (writer.status == AVAssetWriterStatusWriting) usleep(10000);

        if (writer.status != AVAssetWriterStatusCompleted) {
            [fileManager removeItemAtPath:path error:nil];
            return nil;
        }
    }
    return fileURL;
}

#pragma mark - 管理器

@interface DKPiPLaunchManager : NSObject <AVPictureInPictureControllerDelegate>
@property (nonatomic, strong) AVPictureInPictureController *pipController;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) AVQueuePlayer *player;
@property (nonatomic, strong) AVPlayerLooper *looper;
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

- (void)setupPlayerWithURL:(NSURL *)url {
    if (self.player || !url) return;

    self.player = [[AVQueuePlayer alloc] initWithURL:url];
    self.player.muted = YES;
    self.looper = [AVPlayerLooper playerLooperWithPlayer:self.player
                                             templateItem:self.player.currentItem];

    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.frame = CGRectMake(0, 0, 1, 1);
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (keyWindow) [keyWindow.layer addSublayer:self.playerLayer];

    self.pipController = [[AVPictureInPictureController alloc] initWithPlayerLayer:self.playerLayer];
    self.pipController.delegate = self;
    if (@available(iOS 14.2, *)) {
        self.pipController.canStartPictureInPictureAutomaticallyFromInline = YES;
    }
}

- (void)startPiPNow {
    if (!self.pipController) return;
    [self.player play];
    [self.pipController startPictureInPicture];
}

- (void)startPiPIfNeeded {
    if (!DKPrefBool(DKKeyPiPQuickLaunchEnabled)) return;
    if (![AVPictureInPictureController isPictureInPictureSupported]) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.pipController && self.pipController.isPictureInPictureActive) return;
        if (self.player) {
            [self startPiPNow];
            return;
        }
        // 素材生成可能耗时(首次约百毫秒),放后台队列,完成后回主线程装配播放器。
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            NSURL *clipURL = DKPiPLocalClipURL();
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!clipURL) return;
                [self setupPlayerWithURL:clipURL];
                [self startPiPNow];
            });
        });
    });
}

- (void)stopPiPIfNeeded {
    if (!self.pipController) return;
    if (self.pipController.isPictureInPictureActive) {
        [self.pipController stopPictureInPicture];
    }
    // 回前台不再占用解码;画中画停了小窗也保留最后一帧供系统过渡。
    [self.player pause];
}

#pragma mark - AVPictureInPictureControllerDelegate

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController
restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completionHandler {
    if (completionHandler) {
        completionHandler(YES);
    }
}

- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    [self.player pause];
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController
      failedToStartPictureInPictureWithError:(NSError *)error {
    [self.player pause];
}

@end

#pragma mark - Hook

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
    DKSettingsRegister(DKKeyPiPQuickLaunchEnabled, ^AWESettingItemModel *{
        return DKMakeSwitch(
            DKKeyPiPQuickLaunchEnabled,
            @"画中画悬浮直达秒开",
            @"退后台时悬浮画中画小窗（本地素材、不联网），点击画中画恢复按钮即可切回抖音"
        );
    });
}
