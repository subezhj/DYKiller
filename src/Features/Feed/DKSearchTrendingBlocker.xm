//
//  DKSearchTrendingBlocker.xm
//  在搜索中间页的榜单 Tab 创建前短路，避免启动对应 AnnieX/Lynx 容器、
//  榜单请求、图片解码和磁盘缓存。仅作用于 AWESearchMiddleNATabViewComponent。
//

#import "DKKeys.h"
#import "DKSettings.h"
#import "DKUtils.h"

@interface AWESearchMiddleNATabViewComponent : UIView
+ (BOOL)shouldShowTab;
+ (CGSize)sizeWithViewModel:(id)viewModel width:(double)width;
- (void)configUI;
- (void)componentWillDisplay;
@end

static BOOL DKHideSearchTrendingBoardOn(void) {
    return DKPrefBool(DKKeyHideSearchTrendingBoard);
}

%hook AWESearchMiddleNATabViewComponent

+ (BOOL)shouldShowTab {
    if (DKHideSearchTrendingBoardOn()) return NO;
    return %orig;
}

+ (CGSize)sizeWithViewModel:(id)viewModel width:(double)width {
    if (DKHideSearchTrendingBoardOn()) return CGSizeZero;
    return %orig;
}

- (void)configUI {
    if (DKHideSearchTrendingBoardOn()) {
        UIView *view = (UIView *)self;
        view.hidden = YES;
        view.userInteractionEnabled = NO;
        return;
    }
    %orig;
}

- (void)componentWillDisplay {
    if (DKHideSearchTrendingBoardOn()) return;
    %orig;
}

%end

%ctor {
    DKSettingsRegisterItem(@"搜索", ^AWESettingItemModel *{
        return DKMakeSwitch(
            DKKeyHideSearchTrendingBoard,
            @"屏蔽搜索榜单",
            @"阻止抖音热榜、城市榜、直播榜等 Tab 及其 Lynx 资源加载；开启后重启抖音生效"
        );
    });
}
