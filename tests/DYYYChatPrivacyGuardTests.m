#import <Foundation/Foundation.h>
#import "DYYYAdChapterSkipPolicy.h"
#import "DYYYChatPrivacyGuard.h"

// 模拟 TIMXPBNRequest / TIMXPBNRequestBody：仅实现 has 前缀标记，与 protobuf 生成类的调用方式一致。
@interface DYYYTestRequestBody : NSObject
@property(nonatomic) BOOL hasMarkConversationReadBody;
@property(nonatomic) BOOL hasBatchMarkReadBody;
@property(nonatomic) BOOL hasMarkConversationMessageReadRequestBody;
@property(nonatomic) BOOL hasMarkMessageReadRequestBody;
@property(nonatomic) BOOL hasMarkStrangerConversationReadBody;
@property(nonatomic) BOOL hasMarkStrangerAllConversationReadBody;
@property(nonatomic) BOOL hasSendInputStatusBody;
@property(nonatomic) BOOL hasSendMessageBody;
@end
@implementation DYYYTestRequestBody
@end

@interface DYYYTestRequest : NSObject
@property(nonatomic, strong) DYYYTestRequestBody *body;
@property(nonatomic) BOOL hasBody;
@end
@implementation DYYYTestRequest
@end

// 旧版本或其他请求对象可能没有 body，识别时不得抛异常。
@interface DYYYTestBodylessRequest : NSObject
@property(nonatomic) BOOL hasBody;
@end
@implementation DYYYTestBodylessRequest
@end

#define CHECK(...) NSCAssert((__VA_ARGS__), @"测试失败：%s", #__VA_ARGS__)

static DYYYTestRequest *Request(void (^configure)(DYYYTestRequestBody *body)) {
    DYYYTestRequest *request = [DYYYTestRequest new];
    request.body = [DYYYTestRequestBody new];
    request.hasBody = YES;
    if (configure) configure(request.body);
    return request;
}

static DYYYChatPrivacyRequestKind Blocked(id request, BOOL read, BOOL input) {
    return [DYYYChatPrivacyGuard blockedKindForRequestObject:request readReceiptDisabled:read inputStatusDisabled:input];
}

int main(void) {
    @autoreleasepool {
        NSArray<NSString *> *readFlags = @[
            @"hasMarkConversationReadBody", @"hasBatchMarkReadBody", @"hasMarkConversationMessageReadRequestBody",
            @"hasMarkMessageReadRequestBody", @"hasMarkStrangerConversationReadBody", @"hasMarkStrangerAllConversationReadBody"
        ];

        // 各类已读请求体都识别为已读上报，且只在已读开关开启时拦截。
        for (NSString *flag in readFlags) {
            DYYYTestRequest *request = Request(^(DYYYTestRequestBody *body) { [body setValue:@YES forKey:flag]; });
            CHECK([DYYYChatPrivacyGuard requestKindForRequestBody:request.body] == DYYYChatPrivacyRequestKindReadReceipt);
            CHECK(Blocked(request, YES, NO) == DYYYChatPrivacyRequestKindReadReceipt);
            CHECK(Blocked(request, NO, YES) == DYYYChatPrivacyRequestKindNone);
            CHECK(Blocked(request, NO, NO) == DYYYChatPrivacyRequestKindNone);
        }

        // 输入状态只受输入状态开关控制。
        DYYYTestRequest *input = Request(^(DYYYTestRequestBody *body) { body.hasSendInputStatusBody = YES; });
        CHECK(Blocked(input, NO, YES) == DYYYChatPrivacyRequestKindInputStatus);
        CHECK(Blocked(input, YES, NO) == DYYYChatPrivacyRequestKindNone);

        // 发送消息等其他请求不受影响。
        DYYYTestRequest *message = Request(^(DYYYTestRequestBody *body) { body.hasSendMessageBody = YES; });
        CHECK(Blocked(message, YES, YES) == DYYYChatPrivacyRequestKindNone);
        CHECK(Blocked(Request(nil), YES, YES) == DYYYChatPrivacyRequestKindNone);

        // hasBody 为 NO 时即使 body 有残留字段也不拦截；无 body 接口、nil 与非请求对象安全返回。
        DYYYTestRequest *emptyBody = Request(^(DYYYTestRequestBody *body) { body.hasMarkConversationReadBody = YES; });
        emptyBody.hasBody = NO;
        CHECK(Blocked(emptyBody, YES, YES) == DYYYChatPrivacyRequestKindNone);
        DYYYTestBodylessRequest *bodyless = [DYYYTestBodylessRequest new];
        bodyless.hasBody = YES;
        CHECK(Blocked(bodyless, YES, YES) == DYYYChatPrivacyRequestKindNone);
        CHECK(Blocked(nil, YES, YES) == DYYYChatPrivacyRequestKindNone);
        CHECK(Blocked(@"request", YES, YES) == DYYYChatPrivacyRequestKindNone);
        CHECK([DYYYChatPrivacyGuard requestKindForRequestBody:@42] == DYYYChatPrivacyRequestKindNone);

        // 开关从 NSUserDefaults 读取，默认关闭。
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        [defaults removeObjectForKey:DYYYDisableReadReceiptUploadKey];
        [defaults removeObjectForKey:DYYYDisableInputStatusUploadKey];
        DYYYTestRequest *read = Request(^(DYYYTestRequestBody *body) { body.hasMarkConversationReadBody = YES; });
        CHECK([DYYYChatPrivacyGuard blockedKindForRequestObject:read] == DYYYChatPrivacyRequestKindNone);
        [defaults setBool:YES forKey:DYYYDisableReadReceiptUploadKey];
        CHECK([DYYYChatPrivacyGuard blockedKindForRequestObject:read] == DYYYChatPrivacyRequestKindReadReceipt);
        CHECK([DYYYChatPrivacyGuard blockedKindForRequestObject:input] == DYYYChatPrivacyRequestKindNone);
        [defaults setBool:YES forKey:DYYYDisableInputStatusUploadKey];
        CHECK([DYYYChatPrivacyGuard blockedKindForRequestObject:input] == DYYYChatPrivacyRequestKindInputStatus);
        [defaults removeObjectForKey:DYYYDisableReadReceiptUploadKey];
        [defaults removeObjectForKey:DYYYDisableInputStatusUploadKey];

        // 失败回调错误码不得与宿主跳过回调的 2228 或正数业务码重合。
        NSError *error = [DYYYChatPrivacyGuard blockedErrorForKind:DYYYChatPrivacyRequestKindReadReceipt];
        CHECK([error.domain isEqualToString:DYYYChatPrivacyErrorDomain]);
        CHECK(error.code < 0 && error.code != 2228);
        CHECK([DYYYChatPrivacyGuard blockedErrorForKind:DYYYChatPrivacyRequestKindInputStatus].code != error.code);

        // 广告章节：开启时用全部广告章节替换自动跳过序号。
        NSArray *all = @[ @1, @3, @4 ];
        CHECK([[DYYYAdChapterSkipPolicy autoSkipIndexesWithOriginal:@[ @3 ] allAdIndexes:all enabled:YES] isEqualToArray:all]);
        CHECK([[DYYYAdChapterSkipPolicy autoSkipIndexesWithOriginal:nil allAdIndexes:all enabled:YES] isEqualToArray:all]);
        // 关闭、没有广告章节或序号格式异常时保持原值。
        CHECK([[DYYYAdChapterSkipPolicy autoSkipIndexesWithOriginal:@[ @3 ] allAdIndexes:all enabled:NO] isEqualToArray:@[ @3 ]]);
        CHECK([DYYYAdChapterSkipPolicy autoSkipIndexesWithOriginal:nil allAdIndexes:all enabled:NO] == nil);
        CHECK([[DYYYAdChapterSkipPolicy autoSkipIndexesWithOriginal:@[ @3 ] allAdIndexes:@[] enabled:YES] isEqualToArray:@[ @3 ]]);
        CHECK([DYYYAdChapterSkipPolicy autoSkipIndexesWithOriginal:nil allAdIndexes:nil enabled:YES] == nil);
        CHECK([[DYYYAdChapterSkipPolicy autoSkipIndexesWithOriginal:@[ @3 ] allAdIndexes:@[ @1, @"x" ] enabled:YES] isEqualToArray:@[ @3 ]]);
        CHECK([DYYYAdChapterSkipPolicy autoSkipIndexesWithOriginal:nil allAdIndexes:(NSArray *)@"1,3" enabled:YES] == nil);
        [defaults removeObjectForKey:DYYYAutoSkipAdChapterKey];
        CHECK(![DYYYAdChapterSkipPolicy isEnabled]);

        NSLog(@"私信隐私与广告章节测试通过");
    }
    return 0;
}
