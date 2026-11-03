#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 单个逻辑下载的尝试与统计模型；网络请求、相册保存和任务字典仍由 DYYYManager 编排。
@interface DYYYDownloadState : NSObject
@property(nonatomic, copy, readonly) NSArray<NSURL *> *candidates;
@property(nonatomic, assign, readonly) NSUInteger attemptIndex;
@property(nonatomic, strong, nullable) id activeTask;
@property(nonatomic, strong, nullable) NSURLSession *session;
@property(nonatomic, assign, readonly) BOOL cancelled;
@property(nonatomic, assign, readonly) BOOL transferFinished;
@property(nonatomic, assign, readonly) int64_t writtenBytes;
@property(nonatomic, assign, readonly) int64_t expectedBytes;
@property(nonatomic, assign, readonly) double bytesPerSecond;

+ (NSArray<NSURL *> *)normalizedCandidates:(NSArray *)values;
- (instancetype)initWithCandidates:(NSArray *)candidates retryEnabled:(BOOL)enabled;
- (BOOL)acceptsTask:(id)task;
- (nullable NSURL *)retryURLForTask:(id)task error:(nullable NSError *)error statusCode:(NSInteger)statusCode;
- (BOOL)finishTask:(id)task;
- (BOOL)cancel;
- (void)beginTask:(id)task atTime:(NSTimeInterval)time;
- (void)updateTask:(id)task written:(int64_t)written expected:(int64_t)expected atTime:(NSTimeInterval)time;
@end

NS_ASSUME_NONNULL_END
