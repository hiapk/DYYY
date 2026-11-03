#import "DYYYChatPrivacyGuard.h"

#import <objc/message.h>
#import <objc/runtime.h>

NSString *const DYYYDisableReadReceiptUploadKey = @"DYYYDisableReadReceiptUpload";
NSString *const DYYYDisableInputStatusUploadKey = @"DYYYDisableInputStatusUpload";
NSErrorDomain const DYYYChatPrivacyErrorDomain = @"com.dyyy.chat.privacy";

// TIMXPBNRequestBody 中与已读相关的请求体：单会话、批量、按消息、陌生人会话及陌生人全部已读。
static NSString *const kDYYYReadReceiptBodyFlags[] = {
    @"hasMarkConversationReadBody",
    @"hasBatchMarkReadBody",
    @"hasMarkConversationMessageReadRequestBody",
    @"hasMarkMessageReadRequestBody",
    @"hasMarkStrangerConversationReadBody",
    @"hasMarkStrangerAllConversationReadBody",
};

static NSString *const kDYYYInputStatusBodyFlag = @"hasSendInputStatusBody";

@implementation DYYYChatPrivacyGuard

#pragma mark - 开关

+ (BOOL)isReadReceiptUploadDisabled {
    return [NSUserDefaults.standardUserDefaults boolForKey:DYYYDisableReadReceiptUploadKey];
}

+ (BOOL)isInputStatusUploadDisabled {
    return [NSUserDefaults.standardUserDefaults boolForKey:DYYYDisableInputStatusUploadKey];
}

#pragma mark - 请求识别

// 请求体为 protobuf 消息，has 前缀属性在运行时动态解析，因此按选择子调用而非读取实例变量。
+ (BOOL)object:(id)object hasFlag:(NSString *)flagName {
    SEL selector = NSSelectorFromString(flagName);
    if (!object || ![object respondsToSelector:selector]) return NO;
    NSMethodSignature *signature = [object methodSignatureForSelector:selector];
    if (signature.numberOfArguments != 2 || signature.methodReturnLength != sizeof(BOOL)) return NO;
    @try {
        return ((BOOL (*)(id, SEL))objc_msgSend)(object, selector);
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

+ (DYYYChatPrivacyRequestKind)requestKindForRequestBody:(id)body {
    if (!body) return DYYYChatPrivacyRequestKindNone;

    DYYYChatPrivacyRequestKind kind = DYYYChatPrivacyRequestKindNone;
    for (NSUInteger index = 0; index < sizeof(kDYYYReadReceiptBodyFlags) / sizeof(kDYYYReadReceiptBodyFlags[0]); index++) {
        if ([self object:body hasFlag:kDYYYReadReceiptBodyFlags[index]]) {
            kind |= DYYYChatPrivacyRequestKindReadReceipt;
            break;
        }
    }
    if ([self object:body hasFlag:kDYYYInputStatusBodyFlag]) {
        kind |= DYYYChatPrivacyRequestKindInputStatus;
    }
    return kind;
}

+ (DYYYChatPrivacyRequestKind)blockedKindForRequestObject:(id)requestObject {
    BOOL readReceiptDisabled = [self isReadReceiptUploadDisabled];
    BOOL inputStatusDisabled = [self isInputStatusUploadDisabled];
    if (!readReceiptDisabled && !inputStatusDisabled) return DYYYChatPrivacyRequestKindNone;
    return [self blockedKindForRequestObject:requestObject
                         readReceiptDisabled:readReceiptDisabled
                         inputStatusDisabled:inputStatusDisabled];
}

+ (DYYYChatPrivacyRequestKind)blockedKindForRequestObject:(id)requestObject
                                      readReceiptDisabled:(BOOL)readReceiptDisabled
                                      inputStatusDisabled:(BOOL)inputStatusDisabled {
    if (!requestObject || (!readReceiptDisabled && !inputStatusDisabled)) return DYYYChatPrivacyRequestKindNone;
    if (![self object:requestObject hasFlag:@"hasBody"]) return DYYYChatPrivacyRequestKindNone;

    SEL bodySelector = NSSelectorFromString(@"body");
    if (![requestObject respondsToSelector:bodySelector]) return DYYYChatPrivacyRequestKindNone;
    id body = nil;
    @try {
        body = ((id (*)(id, SEL))objc_msgSend)(requestObject, bodySelector);
    } @catch (__unused NSException *exception) {
        return DYYYChatPrivacyRequestKindNone;
    }

    DYYYChatPrivacyRequestKind kind = [self requestKindForRequestBody:body];
    DYYYChatPrivacyRequestKind blocked = DYYYChatPrivacyRequestKindNone;
    if (readReceiptDisabled && (kind & DYYYChatPrivacyRequestKindReadReceipt)) {
        blocked |= DYYYChatPrivacyRequestKindReadReceipt;
    }
    if (inputStatusDisabled && (kind & DYYYChatPrivacyRequestKindInputStatus)) {
        blocked |= DYYYChatPrivacyRequestKindInputStatus;
    }
    return blocked;
}

#pragma mark - 回调与日志

+ (NSError *)blockedErrorForKind:(DYYYChatPrivacyRequestKind)kind {
    NSString *reason = (kind & DYYYChatPrivacyRequestKindReadReceipt) ? @"已读上报已被 DYYY 拦截" : @"输入状态上报已被 DYYY 拦截";
    // 宿主部分逻辑只比较错误码，使用负数避免与 TIMX 的业务错误码（如 2228 跳过回调）重合。
    return [NSError errorWithDomain:DYYYChatPrivacyErrorDomain
                               code:-(NSInteger)(9500 + kind)
                           userInfo:@{NSLocalizedDescriptionKey : reason}];
}

+ (void)logBlockedKindIfNeeded:(DYYYChatPrivacyRequestKind)kind {
    static NSUInteger loggedKinds = DYYYChatPrivacyRequestKindNone;
    @synchronized(self) {
        if ((loggedKinds & kind) == kind) return;
        loggedKinds |= kind;
    }
    NSLog(@"[DYYY] 私信隐私：已拦截%@%@",
          (kind & DYYYChatPrivacyRequestKindReadReceipt) ? @"已读上报 " : @"",
          (kind & DYYYChatPrivacyRequestKindInputStatus) ? @"输入状态上报" : @"");
}

@end
