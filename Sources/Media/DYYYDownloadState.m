#import "DYYYDownloadState.h"
#import <math.h>

@interface DYYYDownloadState ()
@property(nonatomic, copy, readwrite) NSArray<NSURL *> *candidates;
@property(nonatomic, assign, readwrite) NSUInteger attemptIndex;
@property(nonatomic, assign, readwrite) BOOL cancelled;
@property(nonatomic, assign, readwrite) BOOL transferFinished;
@property(nonatomic, assign, readwrite) int64_t writtenBytes;
@property(nonatomic, assign, readwrite) int64_t expectedBytes;
@property(nonatomic, assign, readwrite) double bytesPerSecond;
@property(nonatomic, assign) BOOL retryEnabled;
@property(nonatomic, assign) NSTimeInterval lastSampleTime;
@property(nonatomic, assign) int64_t lastSampleBytes;
@end

@implementation DYYYDownloadState

+ (NSArray<NSURL *> *)normalizedCandidates:(NSArray *)values {
    if (![values isKindOfClass:NSArray.class]) return @[];
    NSMutableArray *result = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (id value in values) {
        NSURL *url = [value isKindOfClass:NSURL.class] ? value :
            ([value isKindOfClass:NSString.class] ? [NSURL URLWithString:[value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]] : nil);
        NSString *scheme = url.scheme.lowercaseString;
        if (!url.host.length || !([scheme isEqualToString:@"https"] || [scheme isEqualToString:@"http"])) continue;
        // 不剥离签名参数、不重新拼接 URL，不因域名相同而错误合并不同签名。
        if ([seen containsObject:url.absoluteString]) continue;
        [seen addObject:url.absoluteString];
        [result addObject:url];
    }
    return [result copy];
}

- (instancetype)initWithCandidates:(NSArray *)candidates retryEnabled:(BOOL)enabled {
    self = [super init];
    if (self) {
        _candidates = [self.class normalizedCandidates:candidates];
        _retryEnabled = enabled;
    }
    return self;
}

- (BOOL)acceptsTask:(id)task {
    @synchronized(self) {
        return task && self.activeTask == task && !self.cancelled && !self.transferFinished;
    }
}

- (void)beginTask:(id)task atTime:(NSTimeInterval)time {
    @synchronized(self) {
        if (self.cancelled || self.transferFinished || self.candidates.count == 0) return;
        self.activeTask = task;
        self.writtenBytes = 0;
        self.expectedBytes = 0;
        self.bytesPerSecond = 0;
        self.lastSampleTime = time;
        self.lastSampleBytes = 0;
    }
}

- (NSURL *)retryURLForTask:(id)task error:(NSError *)error statusCode:(NSInteger)statusCode {
    @synchronized(self) {
        if (![self acceptsTask:task] || !self.retryEnabled || self.attemptIndex + 1 >= MIN((NSUInteger)3, self.candidates.count)) return nil;
        if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) return nil;
        if (!error && statusCode < 400) return nil;
        self.attemptIndex++;
        self.activeTask = nil;
        return self.candidates[self.attemptIndex];
    }
}

- (BOOL)finishTask:(id)task {
    @synchronized(self) {
        if (![self acceptsTask:task]) return NO;
        self.transferFinished = YES;
        self.activeTask = nil;
        return YES;
    }
}

- (BOOL)cancel {
    @synchronized(self) {
        BOOL pending = !self.cancelled && !self.transferFinished;
        self.cancelled = YES;
        self.transferFinished = YES;
        self.activeTask = nil;
        return pending;
    }
}

- (void)updateTask:(id)task written:(int64_t)written expected:(int64_t)expected atTime:(NSTimeInterval)time {
    @synchronized(self) {
        if (![self acceptsTask:task]) return;
        self.writtenBytes = MAX((int64_t)0, written);
        self.expectedBytes = MAX((int64_t)0, expected);
        NSTimeInterval elapsed = time - self.lastSampleTime;
        if (elapsed >= 0.25 && isfinite(elapsed)) {
            double instant = MAX((int64_t)0, self.writtenBytes - self.lastSampleBytes) / elapsed;
            self.bytesPerSecond = self.bytesPerSecond > 0 ? self.bytesPerSecond * 0.35 + instant * 0.65 : instant;
            self.lastSampleTime = time;
            self.lastSampleBytes = self.writtenBytes;
        }
    }
}

@end
