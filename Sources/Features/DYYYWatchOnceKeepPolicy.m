#import "DYYYWatchOnceKeepPolicy.h"

#import <objc/message.h>
#import <objc/runtime.h>
#import <string.h>

NSString *const DYYYKeepWatchOnceMessageKey = @"DYYYKeepWatchOnceMessage";
NSErrorDomain const DYYYWatchOnceKeepErrorDomain = @"com.dyyy.watch-once.keep";

static const NSInteger kDYYYWatchOnceBlockedErrorCode = -9601;
static BOOL gDYYYWatchOnceRuntimeReady = NO;
static char kDYYYWatchOnceTextUnavailableKey;

@interface DYYYWatchOnceKeepPolicy ()
+ (nullable DYYYWatchOnceConsumeCompletion)failureCompletion:(nullable DYYYWatchOnceConsumeCompletion)completion;
+ (void)logBlockedConsumptionIfNeeded;
+ (BOOL)isTextMessage:(nullable id)message;
@end

@implementation DYYYWatchOnceKeepPolicy

#pragma mark - 开关与运行时能力

+ (BOOL)isEnabled {
    return [NSUserDefaults.standardUserDefaults boolForKey:DYYYKeepWatchOnceMessageKey];
}

+ (BOOL)isRuntimeReady {
    @synchronized(self) {
        return gDYYYWatchOnceRuntimeReady;
    }
}

+ (void)setRuntimeReady:(BOOL)ready {
    @synchronized(self) {
        gDYYYWatchOnceRuntimeReady = ready;
    }
}

+ (BOOL)supportsInstanceMethodOnClass:(Class)cls
                            selector:(SEL)selector
                          returnType:(const char *)returnType
                       argumentTypes:(NSArray<NSString *> *)argumentTypes {
    Method method = cls ? class_getInstanceMethod(cls, selector) : NULL;
    if (!method) return NO;
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
    if (signature.numberOfArguments != argumentTypes.count + 2 || strcmp(signature.methodReturnType, returnType) != 0) return NO;
    for (NSUInteger index = 0; index < argumentTypes.count; index++) {
        if (strcmp([signature getArgumentTypeAtIndex:index + 2], argumentTypes[index].UTF8String) != 0) return NO;
    }
    return YES;
}

#pragma mark - 消息范围

+ (BOOL)isTextMessage:(id)message {
    Class cls = NSClassFromString(@"AWEIMWatchOnceTextMessage");
    return cls && [message isKindOfClass:cls];
}

+ (BOOL)shouldPreserveMessage:(id)message {
    if (!message || ![self isEnabled] || ![self isRuntimeReady]) return NO;

    Class imageClass = NSClassFromString(@"AWEIMWatchOnceImageMessage");
    Class videoClass = NSClassFromString(@"AWEIMWatchOnceVideoMessage");
    if (!(imageClass && [message isKindOfClass:imageClass]) && !(videoClass && [message isKindOfClass:videoClass]) && ![self isTextMessage:message]) return NO;
    if ([objc_getAssociatedObject(message, &kDYYYWatchOnceTextUnavailableKey) boolValue]) return NO;

    // 所有判定仍读取原生状态。尤其不能 Hook watchEnd getter 恒返回 NO：
    // 媒体 getter 会检查时间与业务不可用状态，文字 getter 则读取独立消费记录。
    // 已消费、撤回、失效及自己发出的消息均透传，未知接口同样不处理。
    @try {
        for (NSString *name in @[@"sendFromMe", @"recalled", @"isInvalided", @"watchEndFlag", @"watchEnd"]) {
            SEL selector = NSSelectorFromString(name);
            if (![self supportsInstanceMethodOnClass:object_getClass(message) selector:selector returnType:@encode(BOOL) argumentTypes:@[]]) return NO;
            if (((BOOL (*)(id, SEL))objc_msgSend)(message, selector)) return NO;
        }
    } @catch (NSException *exception) {
        NSLog(@"[DYYY] 仅看一次：读取消息状态异常，本次交回原生处理 %@", exception);
        return NO;
    }
    return YES;
}

+ (BOOL)shouldBlockEndValue:(BOOL)value forMessage:(id)message {
    return value && [self shouldPreserveMessage:message];
}

+ (BOOL)shouldBlockResourceClearForMessage:(id)message detailInfo:(id)detailInfo {
    if ([self isTextMessage:message] || ![self shouldPreserveMessage:message] || !detailInfo) return NO;
    SEL selector = NSSelectorFromString(@"showOnceInfo");
    if (![self supportsInstanceMethodOnClass:object_getClass(detailInfo) selector:selector returnType:@encode(id) argumentTypes:@[]]) return NO;
    @try {
        // 原生 p_dismissWatchOnceMediaDisplayer 用新建的空详情调用 p_fillMessage:withContent:，
        // 会将模型里的资源标识及密钥字段清空。只跳过这一清空动作，正常详情仍原样回填。
        // 不额外复制、落盘或记录这些字段；查看页、定时器和播放器仍由原生释放。
        return ((id (*)(id, SEL))objc_msgSend)(detailInfo, selector) == nil;
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

#pragma mark - 文字消费与真实失效

+ (BOOL)shouldBlockTextReadState:(NSUInteger)state forMessage:(id)message {
    // readState 是位标志。只处理已核对的原生 2/4 写入，未知值仍交回原生。
    return (state == 2 || state == 4) && [self isTextMessage:message] && [self shouldPreserveMessage:message];
}

+ (void)recordTextReadStatuses:(NSArray *)statuses forMessages:(NSArray *)messages {
    if (![self isEnabled] || ![self isRuntimeReady] || ![statuses isKindOfClass:NSArray.class] ||
        ![messages isKindOfClass:NSArray.class] || statuses.count != messages.count) return;
    // /has_read 返回与请求消息同序的 read_status。保留原数组，不伪造“未读”结果。
    for (NSUInteger index = 0; index < messages.count; index++) {
        id status = statuses[index];
        id message = messages[index];
        if ([self isTextMessage:message] && [status isKindOfClass:NSNumber.class] && [status boolValue]) {
            objc_setAssociatedObject(message, &kDYYYWatchOnceTextUnavailableKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}

+ (void)observeTextMessage:(id)message sourceMessage:(id)sourceMessage {
    if (![self isEnabled] || ![self isRuntimeReady] || ![self isTextMessage:message]) return;
    BOOL unavailable = YES;
    SEL selector = NSSelectorFromString(@"syncedExtInternal");
    // 无法识别输入时不保护该对象；不能吞掉未知格式的真实失效同步。
    if (sourceMessage && [self supportsInstanceMethodOnClass:object_getClass(sourceMessage) selector:selector returnType:@encode(id) argumentTypes:@[]]) {
        @try {
            id ext = ((id (*)(id, SEL))objc_msgSend)(sourceMessage, selector);
            if (!ext || [ext isKindOfClass:NSDictionary.class]) {
                // 与原生 fillContentWith: 一致，判断键是否存在，不把字符串 "0" 当成未消费。
                unavailable = [ext objectForKey:@"s:once_view_done"] != nil;
            }
        } @catch (__unused NSException *exception) {
        }
    }
    if (unavailable) objc_setAssociatedObject(message, &kDYYYWatchOnceTextUnavailableKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - 消费上报

+ (void)consumeMessages:(NSArray *)messages
             completion:(DYYYWatchOnceConsumeCompletion)completion
                forward:(DYYYWatchOnceConsumeForward)forward {
    if (![self isEnabled] || ![self isRuntimeReady] || ![messages isKindOfClass:NSArray.class] || messages.count == 0) {
        forward(messages, completion);
        return;
    }

    NSMutableArray *forwardedMessages = [NSMutableArray arrayWithCapacity:messages.count];
    for (id message in messages) {
        if (![self shouldPreserveMessage:message]) [forwardedMessages addObject:message];
    }
    if (forwardedMessages.count == messages.count) {
        forward(messages, completion);
        return;
    }

    [self logBlockedConsumptionIfNeeded];
    DYYYWatchOnceConsumeCompletion failedCompletion = [self failureCompletion:completion];
    if (forwardedMessages.count > 0) {
        // 不能因为一个批次混入目标消息，就丢掉普通消息或发送方的消费上报。
        // 接口只有聚合结果：部分被拦时报告失败，不谎报整批成功；未拦消息的服务端上报仍执行。
        forward([forwardedMessages copy], failedCompletion);
    } else if (failedCompletion) {
        failedCompletion(nil, nil);
    }
}

+ (DYYYWatchOnceConsumeCompletion)failureCompletion:(DYYYWatchOnceConsumeCompletion)completion {
    if (!completion) return nil;
    NSObject *completionLock = [NSObject new];
    __block BOOL completed = NO;
    return ^(NSNumber *statusCode, NSError *error) {
        @synchronized(completionLock) {
            if (completed) return;
            completed = YES;
        }
        NSError *failure = error ?: [NSError errorWithDomain:DYYYWatchOnceKeepErrorDomain
                                                       code:kDYYYWatchOnceBlockedErrorCode
                                                   userInfo:@{NSLocalizedDescriptionKey : @"本次仅看一次消费上报已被 DYYY 拦截"}];
        NSNumber *failureCode = error ? (statusCode ?: @(failure.code)) : @(kDYYYWatchOnceBlockedErrorCode);
        // 不同步重入调用方；只回调一次，且不复用 TIMX 请求对象的方法或伪造成功。
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(failureCode, failure);
        });
    };
}

+ (void)logBlockedConsumptionIfNeeded {
    static BOOL logged = NO;
    @synchronized(self) {
        if (logged) return;
        logged = YES;
    }
    NSLog(@"[DYYY] 仅看一次：已拦截有效接收文字/图片/视频的消费上报；实际展示仍需真机验证");
}

@end
