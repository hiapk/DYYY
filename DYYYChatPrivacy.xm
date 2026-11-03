#import "AwemeHeaders.h"
#import "DYYYChatPrivacyGuard.h"

// 抖音 39.8.0 私信的已读（MarkConversationRead 等）与“正在输入”（SendInputStatus）请求，
// 均由 TIMXPBAutoFallbackRequest 组装 TIMXPBNRequest 后经 -send 走 WebSocket / HTTP 发出。
// 在此按请求体字段拦截：本地已读与未读数照常更新，仅不告知服务器；对方的已读状态照常显示。

%group DYYYChatPrivacyRequest
%hook TIMXPBAutoFallbackRequest
- (void)send {
    DYYYChatPrivacyRequestKind kind = [DYYYChatPrivacyGuard blockedKindForRequestObject:self.requestObject];
    if (kind == DYYYChatPrivacyRequestKindNone) {
        %orig;
        return;
    }

    [DYYYChatPrivacyGuard logBlockedKindIfNeeded:kind];
    // 按普通网络失败回调，宿主保留“未上报”状态；异步回调避免调用方在 send 返回前收到结果。
    // 正常发送时请求由网络任务持有，这里同样强引用到回调结束，保证调用方的完成回调一定执行。
    NSError *error = [DYYYChatPrivacyGuard blockedErrorForKind:kind];
    TIMXPBAutoFallbackRequest *request = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            [request callFailureBlockWithError:error errorObj:nil];
        } @catch (NSException *exception) {
            NSLog(@"[DYYY] 私信隐私：失败回调异常 %@", exception);
        }
    });
}
%end
%end

%ctor {
    Class request = objc_getClass("TIMXPBAutoFallbackRequest");
    Class requestObject = objc_getClass("TIMXPBNRequest");
    if (request && requestObject && class_getInstanceMethod(request, @selector(send)) &&
        class_getInstanceMethod(request, @selector(requestObject)) &&
        class_getInstanceMethod(request, @selector(callFailureBlockWithError:errorObj:))) {
        %init(DYYYChatPrivacyRequest);
    } else {
        NSLog(@"[DYYY] 私信隐私：当前抖音版本缺少 TIMX 请求接口，未启用");
    }
}
