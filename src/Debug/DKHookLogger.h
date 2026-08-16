//
//  DKHookLogger.h
//  DYKiller
//  记录全量功能 Hook 事件、性能指标（CPU/RAM/电池）与图层日志，
//  在导出调试 zip 时落盘至 probe/hook_events.txt 与 probe/performance.txt。
//

#ifndef DKHookLogger_h
#define DKHookLogger_h

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/// 记录一次关键 Hook 执行事件
void DKLogHookEvent(NSString *feature, NSString *hookName, NSString *details);

/// 获取全量 Hook 事件日志文本（用于落盘到 probe/hook_events.txt）
NSString *DKGetHookLogsText(void);

/// 获取性能、CPU、内存、图层与功耗评估报告（用于落盘到 probe/performance.txt）
NSString *DKGetPerformanceMetricsReport(void);

#ifdef __cplusplus
}
#endif

#endif /* DKHookLogger_h */
