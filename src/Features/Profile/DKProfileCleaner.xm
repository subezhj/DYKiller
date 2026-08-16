//
//  DKProfileCleaner.xm
//  DYKiller
//
//  移除个人主页中的干扰元素
//

#import <UIKit/UIKit.h>
#import <Logos/Logos.h>
#import "../../Shared/DKKeys.h"
#import "../../Shared/DKUtils.h"
#import "../../Headers/DouyinHeaders.h"
#import "../../Settings/DKSettings.h"

#pragma mark - Hook 1: 移除作品空态引导

%hook AWEUserProfileUGCContributionGuideEmptyCollectionViewCell

+ (double)viewHeight {
    if (DKPrefBool(DKKeyProfileHideUGCGuide)) {
        return 0.0;
    }
    return %orig;
}

- (void)configWithUserModel:(id)arg0 context:(id)arg1 {
    %orig;
    if (DKPrefBool(DKKeyProfileHideUGCGuide)) {
        self.bodyView.hidden = YES;
    } else {
        self.bodyView.hidden = NO;
    }
}

%end

#pragma mark - Hook 2: 移除个人主页新访客入口

%hook AWEUserHomeVisitorButton

- (void)layoutSubviews {
    %orig;
    if (DKPrefBool(DKKeyProfileHideVisitorGuide)) {
        self.hidden = YES;
    }
}

- (void)setHidden:(BOOL)hidden {
    if (DKPrefBool(DKKeyProfileHideVisitorGuide)) {
        %orig(YES);
    } else {
        %orig(hidden);
    }
}

%end

%hook AWEUserHomeVisitorButtonAccessView

- (void)layoutSubviews {
    %orig;
    if (DKPrefBool(DKKeyProfileHideVisitorGuide)) {
        self.hidden = YES;
    }
}

%end

#pragma mark - 注册设置

%ctor {
    DKSettingsRegisterItem(@"个人主页", ^{
        return DKMakeSwitch(DKKeyProfileHideUGCGuide, @"移除个人主页发作品区域", @"隐藏「作品」下方的去发布等引导元素");
    });
    DKSettingsRegisterItem(@"个人主页", ^{
        return DKMakeSwitch(DKKeyProfileHideVisitorGuide, @"隐藏个人主页新访客", @"隐藏个人主页顶部的“新访客”提示卡片与入口");
    });
}
