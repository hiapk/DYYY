#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 私信隐私：阻止向服务器上报已读与“正在输入”状态。
// 抖音 39.8.0 私信请求统一经 TIMXPBAutoFallbackRequest -send 发出，请求体为 TIMXPBNRequestBody，
// 按请求体中实际存在的字段识别请求类型，不依赖调用方。

FOUNDATION_EXPORT NSString *const DYYYDisableReadReceiptUploadKey;
FOUNDATION_EXPORT NSString *const DYYYDisableInputStatusUploadKey;
FOUNDATION_EXPORT NSErrorDomain const DYYYChatPrivacyErrorDomain;

typedef NS_OPTIONS(NSUInteger, DYYYChatPrivacyRequestKind) {
    DYYYChatPrivacyRequestKindNone = 0,
    DYYYChatPrivacyRequestKindReadReceipt = 1 << 0,
    DYYYChatPrivacyRequestKindInputStatus = 1 << 1,
};

@interface DYYYChatPrivacyGuard : NSObject

+ (BOOL)isReadReceiptUploadDisabled;
+ (BOOL)isInputStatusUploadDisabled;

// 识别请求体包含的上报类型；body 为 TIMXPBNRequestBody。
+ (DYYYChatPrivacyRequestKind)requestKindForRequestBody:(nullable id)body;

// 结合开关返回需要拦截的类型；requestObject 为 TIMXPBNRequest。
+ (DYYYChatPrivacyRequestKind)blockedKindForRequestObject:(nullable id)requestObject;
+ (DYYYChatPrivacyRequestKind)blockedKindForRequestObject:(nullable id)requestObject
                                      readReceiptDisabled:(BOOL)readReceiptDisabled
                                      inputStatusDisabled:(BOOL)inputStatusDisabled;

// 被拦截请求的失败回调错误；宿主按普通网络失败处理，开关关闭后可重新上报。
+ (NSError *)blockedErrorForKind:(DYYYChatPrivacyRequestKind)kind;

// 每种类型每次启动只记一次日志，避免输入时刷屏。
+ (void)logBlockedKindIfNeeded:(DYYYChatPrivacyRequestKind)kind;

@end

NS_ASSUME_NONNULL_END
