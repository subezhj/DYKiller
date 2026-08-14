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

%hook AWEPlayInteractionViewController

- (BOOL)hideMusicInfo {
    if (DKPrefBool(DKKeyHideMusicInfo)) return YES;
    return %orig;
}

%end

static void DKSyncMusicButtonText(UILabel *label) {
    if (label) label.hidden = DKPrefBool(DKKeyHideMusicButtonText);
}

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
