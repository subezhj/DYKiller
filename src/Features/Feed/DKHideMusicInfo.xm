//
//  DKHideMusicInfo.xm
//  功能：播放体验 —— 移除视频底部文案下方的「去汽水听」音乐信息栏。
//
//  实现：
//   - Hook AWEPlayInteractionViewController 的 hideMusicInfo getter。
//   - 开关开启时返回 YES，令抖音走自身隐藏逻辑。
//

#import "DouyinHeaders.h"
#import "DKUtils.h"
#import "DKKeys.h"
#import "DKSettings.h"
#import <objc/runtime.h>

static char kDKMusicButtonTextHiddenKey;

%hook AWEPlayInteractionViewController

- (BOOL)hideMusicInfo {
    if (DKPrefBool(DKKeyHideMusicInfo)) return YES;
    return %orig;
}

%end

static BOOL DKIsMusicButtonText(NSString *text) {
    if (text.length == 0) return NO;
    return [text isEqualToString:@"听抖音"]
        || [text isEqualToString:@"拍同款"]
        || [text isEqualToString:@"玩同款"]
        || [text isEqualToString:@"听完整版"];
}

static void DKSyncMusicButtonText(UILabel *label) {
    if (!label) return;
    BOOL enabled = DKPrefBool(DKKeyHideMusicButtonText);
    NSNumber *original = objc_getAssociatedObject(label, &kDKMusicButtonTextHiddenKey);
    if (enabled && DKIsMusicButtonText(label.text)) {
        if (!original) {
            objc_setAssociatedObject(label, &kDKMusicButtonTextHiddenKey, @(label.hidden),
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        label.hidden = YES;
    } else if (original) {
        label.hidden = original.boolValue;
        objc_setAssociatedObject(label, &kDKMusicButtonTextHiddenKey, nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void DKSyncMusicButtonTextTree(UIView *root) {
    if ([root isKindOfClass:UILabel.class]) DKSyncMusicButtonText((UILabel *)root);
    for (UIView *subview in root.subviews) DKSyncMusicButtonTextTree(subview);
}

%hook AWEPlayInteractionStyleOneMusicView

- (void)layoutSubviews {
    %orig;
    DKSyncMusicButtonTextTree((UIView *)self);
}

%end

%hook AWEPlayInteractionListenFeedView

- (void)layoutSubviews {
    %orig;
    DKSyncMusicButtonTextTree((UIView *)self);
}

%end

%hook AWEMusicCoverButton

- (void)layoutSubviews {
    %orig;
    DKSyncMusicButtonText(self.guidanceLabel);
}

%end

%hook AWEPlayInteractionSingleSongMusicStyleView

- (void)layoutSubviews {
    %orig;
    DKSyncMusicButtonText(self.listenTitleLabel);
    DKSyncMusicButtonText(self.playInteractionLabel);
}

%end

#pragma mark - 设置项注册

%ctor {
    DKSettingsRegisterItem(@"播放体验", ^AWESettingItemModel *{
        return DKMakeSwitch(DKKeyHideMusicInfo, @"移除文案下方\"去汽水听\"", @"隐藏视频底部的音乐信息栏（含汽水音乐引导和歌曲名）");
    });
    DKSettingsRegisterItem(@"播放体验", ^AWESettingItemModel *{
        return DKMakeSwitch(DKKeyHideMusicButtonText, @"隐藏音乐按钮文字", @"隐藏右下角音乐按钮上的“拍同款”“听抖音”等文字，保留按钮本体");
    });
}
