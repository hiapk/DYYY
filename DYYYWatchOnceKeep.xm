#import "AwemeHeaders.h"
#import "DYYYWatchOnceKeepPolicy.h"

// 抖音 39.8.0 / build 398016：只阻止有效接收文字、图片、视频的本次消费。
// 保留查看页退出、定时器/播放器释放、KVO 及正常资源回填；也不改写原生的过期判定。
%group DYYYWatchOnceKeep

%hook AWEIMWatchOnceImageMessage
- (void)setWatchEnd:(BOOL)value {
    if ([DYYYWatchOnceKeepPolicy shouldBlockEndValue:value forMessage:self]) return;
    %orig;
}
%end

%hook AWEIMWatchOnceVideoMessage
- (void)setWatchEnd:(BOOL)value {
    if ([DYYYWatchOnceKeepPolicy shouldBlockEndValue:value forMessage:self]) return;
    %orig;
}
%end

%hook AWEIMWatchOnceTextMessage
- (void)setWatchEnd:(BOOL)value {
    // 文字通过独立的 TextWatchEnd 记录结束状态，不能只拦图片/视频的模型。
    if ([DYYYWatchOnceKeepPolicy shouldBlockEndValue:value forMessage:self]) return;
    %orig;
}

- (void)setReadState:(NSUInteger)state {
    // 即使消费请求失败，原生延时任务也会写入 2；该状态会隐藏文字并留下结束记录。
    if ([DYYYWatchOnceKeepPolicy shouldBlockTextReadState:state forMessage:self]) return;
    %orig;
}

- (void)fillContentWith:(id)message {
    [DYYYWatchOnceKeepPolicy observeTextMessage:self sourceMessage:message];
    %orig;
}
%end

%hook AWEIMMessage
- (void)setWatchEndFlag:(BOOL)value {
    // 原生此方法同时写内存与磁盘；只拦目标消息的 YES 写入，不清空已有消费记录。
    if ([DYYYWatchOnceKeepPolicy shouldBlockEndValue:value forMessage:self]) return;
    %orig;
}
%end

%hook AWEIMWatchOnceDataManager
- (void)fetchWatchOnceTextReadInfo:(NSArray *)messages complete:(void (^)(NSArray *))complete {
    if (![DYYYWatchOnceKeepPolicy isEnabled] || ![DYYYWatchOnceKeepPolicy isRuntimeReady] || !complete) {
        %orig;
        return;
    }
    NSArray *requestedMessages = [messages isKindOfClass:NSArray.class] ? [messages copy] : nil;
    void (^observedCompletion)(NSArray *) = ^(NSArray *statuses) {
        // 必须先记录服务端判定，再让原生回调写状态；保持结果和回调线程不变。
        [DYYYWatchOnceKeepPolicy recordTextReadStatuses:statuses forMessages:requestedMessages];
        complete(statuses);
    };
    %orig(messages, observedCompletion);
}

- (void)markMessageWatchOnceAlreadyConsume:(id)conversationShortID
                             messageArray:(NSArray *)messageArray
                                 complete:(void (^)(NSNumber *, NSError *))complete {
    [DYYYWatchOnceKeepPolicy consumeMessages:messageArray completion:complete
                                   forward:^(NSArray *messages, DYYYWatchOnceConsumeCompletion callback) {
        %orig(conversationShortID, messages, callback);
    }];
}
%end

%hook AWEIMAwemeMediaDisplayViewController_WatchOnceImage
- (void)p_fillMessage:(AWEIMWatchOnceImageMessage *)message withContent:(id)detailInfo {
    if ([DYYYWatchOnceKeepPolicy shouldBlockResourceClearForMessage:message detailInfo:detailInfo]) return;
    %orig;
}
%end

%hook AWEIMAwemeMediaDisplayViewController_WatchOnceVideo
- (void)p_fillMessage:(AWEIMWatchOnceVideoMessage *)message withContent:(id)detailInfo {
    if ([DYYYWatchOnceKeepPolicy shouldBlockResourceClearForMessage:message detailInfo:detailInfo]) return;
    %orig;
}
%end

%end

%ctor {
    Class message = objc_getClass("AWEIMMessage");
    Class image = objc_getClass("AWEIMWatchOnceImageMessage");
    Class video = objc_getClass("AWEIMWatchOnceVideoMessage");
    Class text = objc_getClass("AWEIMWatchOnceTextMessage");
    Class manager = objc_getClass("AWEIMWatchOnceDataManager");
    BOOL compatible = message && image && video && text && manager;
    NSArray<NSString *> *boolArgument = @[@(@encode(BOOL))];
    for (Class cls in @[image ?: NSObject.class, video ?: NSObject.class, text ?: NSObject.class]) {
        compatible = compatible && [DYYYWatchOnceKeepPolicy supportsInstanceMethodOnClass:cls
            selector:@selector(setWatchEnd:) returnType:@encode(void) argumentTypes:boolArgument];
        for (NSString *name in @[@"sendFromMe", @"recalled", @"isInvalided", @"watchEndFlag", @"watchEnd"]) {
            compatible = compatible && [DYYYWatchOnceKeepPolicy supportsInstanceMethodOnClass:cls
                selector:NSSelectorFromString(name) returnType:@encode(BOOL) argumentTypes:@[]];
        }
    }
    compatible = compatible && [DYYYWatchOnceKeepPolicy supportsInstanceMethodOnClass:message
        selector:@selector(setWatchEndFlag:) returnType:@encode(void) argumentTypes:boolArgument];
    compatible = compatible && [DYYYWatchOnceKeepPolicy supportsInstanceMethodOnClass:manager
        selector:@selector(markMessageWatchOnceAlreadyConsume:messageArray:complete:)
        returnType:@encode(void) argumentTypes:@[@"@", @"@", @"@?"]];
    compatible = compatible && [DYYYWatchOnceKeepPolicy supportsInstanceMethodOnClass:text
        selector:@selector(setReadState:) returnType:@encode(void) argumentTypes:@[@(@encode(NSUInteger))]];
    compatible = compatible && [DYYYWatchOnceKeepPolicy supportsInstanceMethodOnClass:text
        selector:@selector(fillContentWith:) returnType:@encode(void) argumentTypes:@[@"@"]];
    compatible = compatible && [DYYYWatchOnceKeepPolicy supportsInstanceMethodOnClass:manager
        selector:@selector(fetchWatchOnceTextReadInfo:complete:) returnType:@encode(void) argumentTypes:@[@"@", @"@?"]];
    for (NSString *name in @[@"AWEIMAwemeMediaDisplayViewController_WatchOnceImage", @"AWEIMAwemeMediaDisplayViewController_WatchOnceVideo"]) {
        compatible = compatible && [DYYYWatchOnceKeepPolicy supportsInstanceMethodOnClass:NSClassFromString(name)
            selector:@selector(p_fillMessage:withContent:) returnType:@encode(void) argumentTypes:@[@"@", @"@"]];
    }
    for (NSString *name in @[@"AWEIMWatchOnceImageDetailInfo", @"AWEIMWatchOnceVideoDetailInfo"]) {
        compatible = compatible && [DYYYWatchOnceKeepPolicy supportsInstanceMethodOnClass:NSClassFromString(name)
            selector:NSSelectorFromString(@"showOnceInfo") returnType:@encode(id) argumentTypes:@[]];
    }
    if (!compatible) {
        NSLog(@"[DYYY] 仅看一次：当前版本缺少必要接口或签名改变，整组 Hook 未启用");
        return;
    }
    %init(DYYYWatchOnceKeep);
    [DYYYWatchOnceKeepPolicy setRuntimeReady:YES];
}
