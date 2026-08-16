//
//  DKDebugInspector.h
//  DYKiller
//

#ifndef DKDebugInspector_h
#define DKDebugInspector_h

#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

void DKDebugInspectorInstall(void);
void DKDebugInspectorRefreshOverlay(void);

/// 唤起或隐藏 FLEX++ 视图调试工具面板；若成功唤起返回 YES，若未加载 FLEX dylib 返回 NO。
BOOL DKToggleFLEXExplorer(void);

#ifdef __cplusplus
}
#endif

#endif /* DKDebugInspector_h */
