//
//  DKHideMusicInfo.xm
//  功能：播放页精简 —— 文案下方「去汽水听」音乐信息栏的移除闸门。
//
//  实现：
//   - Hook AWEPlayInteractionViewController 的 hideMusicInfo getter。
//   - 「去汽水听」为移除时返回 YES，令抖音走自身隐藏逻辑；整行的隐藏 / 移除另由播放页精简处理。
//   - 设置项登记在 DKPlaybackCleanSettings.xm。
//

#import "DouyinHeaders.h"
#import "DKUtils.h"
#import "DKKeys.h"
#import "DKSettings.h"
#import <objc/runtime.h>

static char kDKMusicButtonTextHiddenKey;

%hook AWEPlayInteractionViewController

- (BOOL)hideMusicInfo {
    if (DKPrefDisplayMode(DKKeyPlaybackMusicInfoMode) == DKDisplayModeRemove) return YES;
    return %orig;
}

%end

static BOOL DKIsMusicButtonText(NSString *text) {
    if (text.length == 0) return NO;
    return [text isEqualToString:@"听抖音"]
        || [text isEqualToString:@"拍同款"]
        || [text isEqualToString:@"玩同款"]
        || [text isEqualToString:@"听完整版"]
        || [text isEqualToString:@"听合集"]
        || [text containsString:@"听合集"];
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
    DKSettingsRegister(DKKeyHideMusicButtonText, ^AWESettingItemModel *{
        return DKMakeSwitch(DKKeyHideMusicButtonText, @"隐藏音乐按钮文字", @"隐藏右下角音乐按钮上的“拍同款”“听抖音”等文字，保留按钮本体");
    });
}
