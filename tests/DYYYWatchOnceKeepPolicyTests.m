#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "DYYYWatchOnceKeepPolicy.h"

// 模拟原生模型：getter 自行判过期，setter 只接受 YES，不具备恢复能力。
@interface DYYYWatchOnceTestMessage : NSObject
@property(nonatomic, assign) BOOL sendFromMe;
@property(nonatomic, assign) BOOL recalled;
@property(nonatomic, assign) BOOL isInvalided;
@property(nonatomic, assign) BOOL watchEndFlag;
@property(nonatomic, assign) BOOL expired;
@property(nonatomic, assign) BOOL unavailable;
@property(nonatomic, assign) BOOL storedEnd;
- (BOOL)watchEnd;
- (void)setWatchEnd:(BOOL)value;
@end

@implementation DYYYWatchOnceTestMessage
- (BOOL)watchEnd {
    if (self.expired || self.unavailable) self.storedEnd = YES;
    return self.storedEnd;
}
- (void)setWatchEnd:(BOOL)value {
    if (value) self.storedEnd = YES;
}
@end

@interface DYYYWatchOnceTestDetailInfo : NSObject
@property(nonatomic, strong) id showOnceInfo;
@end
@implementation DYYYWatchOnceTestDetailInfo
@end

#define CHECK(...) NSCAssert((__VA_ARGS__), @"测试失败：%s", #__VA_ARGS__)

int main(void) {
    @autoreleasepool {
        // 使用运行时假类，避免在测试中另外声明宿主私有接口。
        Class imageClass = objc_allocateClassPair(DYYYWatchOnceTestMessage.class, "AWEIMWatchOnceImageMessage", 0);
        Class videoClass = objc_allocateClassPair(DYYYWatchOnceTestMessage.class, "AWEIMWatchOnceVideoMessage", 0);
        CHECK(imageClass && videoClass);
        objc_registerClassPair(imageClass);
        objc_registerClassPair(videoClass);

        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        id previousSetting = [defaults objectForKey:DYYYKeepWatchOnceMessageKey];
        @try {
            [defaults removeObjectForKey:DYYYKeepWatchOnceMessageKey];
            [DYYYWatchOnceKeepPolicy setRuntimeReady:YES];
            DYYYWatchOnceTestMessage *image = [imageClass new];
            DYYYWatchOnceTestMessage *video = [videoClass new];
            CHECK(![DYYYWatchOnceKeepPolicy isEnabled]);
            CHECK(![DYYYWatchOnceKeepPolicy shouldPreserveMessage:image]);
            [defaults setBool:YES forKey:DYYYKeepWatchOnceMessageKey];

            // 首个回归：启用后阻止有效接收消息的消费写入，且不阻止其他写入。
            CHECK([DYYYWatchOnceKeepPolicy shouldBlockEndValue:YES forMessage:image]);
            CHECK([DYYYWatchOnceKeepPolicy shouldPreserveMessage:video]);
            CHECK(![DYYYWatchOnceKeepPolicy shouldBlockEndValue:NO forMessage:image]);
            CHECK(![DYYYWatchOnceKeepPolicy shouldPreserveMessage:[DYYYWatchOnceTestMessage new]]);
            CHECK(![DYYYWatchOnceKeepPolicy shouldPreserveMessage:nil]);
            CHECK(![DYYYWatchOnceKeepPolicy shouldPreserveMessage:@42]);

            // setter 被拦也不能屏蔽原生 getter 的过期、不可用判定。
            for (NSString *flag in @[@"expired", @"unavailable", @"storedEnd", @"watchEndFlag", @"recalled", @"isInvalided", @"sendFromMe"]) {
                DYYYWatchOnceTestMessage *invalid = [imageClass new];
                [invalid setValue:@YES forKey:flag];
                CHECK(![DYYYWatchOnceKeepPolicy shouldPreserveMessage:invalid]);
            }
            image.expired = YES;
            [image setWatchEnd:NO];
            CHECK(image.watchEnd);
            CHECK(![DYYYWatchOnceKeepPolicy shouldBlockEndValue:YES forMessage:image]);
            image = [imageClass new];

            // 原生退出使用空详情清空模型资源字段；保留此分支，仍允许正常详情回填与失效清理。
            DYYYWatchOnceTestDetailInfo *detail = [DYYYWatchOnceTestDetailInfo new];
            CHECK([DYYYWatchOnceKeepPolicy shouldBlockResourceClearForMessage:image detailInfo:detail]);
            detail.showOnceInfo = [NSObject new];
            CHECK(![DYYYWatchOnceKeepPolicy shouldBlockResourceClearForMessage:image detailInfo:detail]);
            detail.showOnceInfo = nil;
            image.recalled = YES;
            CHECK(![DYYYWatchOnceKeepPolicy shouldBlockResourceClearForMessage:image detailInfo:detail]);
            image.recalled = NO;
            CHECK(![DYYYWatchOnceKeepPolicy shouldBlockResourceClearForMessage:image detailInfo:nil]);
            CHECK(![DYYYWatchOnceKeepPolicy shouldBlockResourceClearForMessage:image detailInfo:@42]);

            [DYYYWatchOnceKeepPolicy setRuntimeReady:NO];
            CHECK(![DYYYWatchOnceKeepPolicy shouldPreserveMessage:image]);
            [DYYYWatchOnceKeepPolicy setRuntimeReady:YES];

            // ABI 变化时不能把对象返回值当 BOOL 调用，也不能忽略缺失方法。
            CHECK([DYYYWatchOnceKeepPolicy supportsInstanceMethodOnClass:imageClass selector:@selector(watchEnd) returnType:@encode(BOOL) argumentTypes:@[]]);
            CHECK([DYYYWatchOnceKeepPolicy supportsInstanceMethodOnClass:imageClass selector:@selector(setWatchEnd:) returnType:@encode(void) argumentTypes:@[@(@encode(BOOL))]]);
            CHECK(![DYYYWatchOnceKeepPolicy supportsInstanceMethodOnClass:imageClass selector:@selector(description) returnType:@encode(BOOL) argumentTypes:@[]]);
            CHECK(![DYYYWatchOnceKeepPolicy supportsInstanceMethodOnClass:Nil selector:@selector(watchEnd) returnType:@encode(BOOL) argumentTypes:@[]]);
            CHECK(![DYYYWatchOnceKeepPolicy supportsInstanceMethodOnClass:imageClass selector:@selector(setWatchEnd:) returnType:@encode(void) argumentTypes:@[@"@"]]);
            CHECK(![DYYYWatchOnceKeepPolicy supportsInstanceMethodOnClass:imageClass selector:NSSelectorFromString(@"missingWatchEnd") returnType:@encode(BOOL) argumentTypes:@[]]);

            __block NSUInteger sends = 0;
            __block NSUInteger callbacks = 0;
            __block NSNumber *result = nil;
            __block NSError *failure = nil;
            DYYYWatchOnceConsumeCompletion completion = ^(NSNumber *code, NSError *error) {
                CHECK(NSThread.isMainThread);
                callbacks++;
                result = code;
                failure = error;
            };
            DYYYWatchOnceConsumeForward unexpectedForward = ^(NSArray *messages, DYYYWatchOnceConsumeCompletion callback) {
                sends++;
            };

            // 整批保留：不发网络请求，异步完成一次失败回调，不能卡住调用方。
            [DYYYWatchOnceKeepPolicy consumeMessages:@[image, video] completion:completion forward:unexpectedForward];
            CHECK(sends == 0 && callbacks == 0);
            NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2];
            while (!callbacks && deadline.timeIntervalSinceNow > 0) {
                [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
            }
            CHECK(callbacks == 1 && result.integerValue < 0);
            CHECK([failure.domain isEqualToString:DYYYWatchOnceKeepErrorDomain]);

            // 混合批次：普通消息照常发出；底层即使重复完成也只通知上层一次。
            callbacks = 0;
            NSObject *ordinary = [NSObject new];
            DYYYWatchOnceTestMessage *outgoing = [videoClass new];
            outgoing.sendFromMe = YES;
            [DYYYWatchOnceKeepPolicy consumeMessages:@[image, ordinary, video, outgoing] completion:completion forward:^(NSArray *messages, DYYYWatchOnceConsumeCompletion callback) {
                sends++;
                CHECK([messages isEqualToArray:@[ordinary, outgoing]]);
                CHECK(callback != nil);
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
                    callback(@0, nil);
                    callback(@0, nil);
                });
            }];
            deadline = [NSDate dateWithTimeIntervalSinceNow:2];
            while (!callbacks && deadline.timeIntervalSinceNow > 0) {
                [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
            }
            [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
            CHECK(sends == 1 && callbacks == 1 && result.integerValue < 0 && failure != nil);

            // 混合批次真正网络失败时保留原始错误，不用插件错误掩盖排查依据。
            callbacks = 0;
            NSError *networkError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
            [DYYYWatchOnceKeepPolicy consumeMessages:@[image, ordinary] completion:completion forward:^(NSArray *messages, DYYYWatchOnceConsumeCompletion callback) {
                CHECK([messages isEqualToArray:@[ordinary]]);
                callback(nil, networkError);
            }];
            deadline = [NSDate dateWithTimeIntervalSinceNow:2];
            while (!callbacks && deadline.timeIntervalSinceNow > 0) {
                [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
            }
            CHECK(callbacks == 1 && failure == networkError && result.integerValue == networkError.code);

            [DYYYWatchOnceKeepPolicy consumeMessages:@[image] completion:nil forward:unexpectedForward];
            CHECK(sends == 1);

            // 开关关闭、普通消息、空批次均原样透传，原生回调语义保持不变。
            [defaults setBool:NO forKey:DYYYKeepWatchOnceMessageKey];
            NSArray *original = @[image];
            [DYYYWatchOnceKeepPolicy consumeMessages:original completion:completion forward:^(NSArray *messages, DYYYWatchOnceConsumeCompletion callback) {
                CHECK(messages == original && callback == completion);
                sends++;
            }];
            CHECK(sends == 2 && ![DYYYWatchOnceKeepPolicy shouldPreserveMessage:image]);
            [defaults setBool:YES forKey:DYYYKeepWatchOnceMessageKey];
            for (NSArray *batch in @[@[], @[ordinary]]) {
                [DYYYWatchOnceKeepPolicy consumeMessages:batch completion:nil forward:^(NSArray *messages, DYYYWatchOnceConsumeCompletion callback) {
                    CHECK(messages == batch && callback == nil);
                    sends++;
                }];
            }
            CHECK(sends == 4);
            NSLog(@"仅看一次策略测试通过；未验证抖音真机调用及媒体资源生命周期");
        } @finally {
            if (previousSetting) [defaults setObject:previousSetting forKey:DYYYKeepWatchOnceMessageKey];
            else [defaults removeObjectForKey:DYYYKeepWatchOnceMessageKey];
            [DYYYWatchOnceKeepPolicy setRuntimeReady:NO];
        }
    }
    return 0;
}
