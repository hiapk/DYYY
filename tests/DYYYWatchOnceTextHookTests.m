#import "AwemeHeaders.h"
#import "DYYYWatchOnceKeepPolicy.h"

// 模拟已核对的文字链路：TextWatchEnd 跨消息对象保留，readState 写入会触发 setWatchEnd:。
// 运行实际 Logos Hook；此模拟验证状态写入与聊天对象重建，不冒充真机 UI 验收。
static BOOL gDYYYTextConsumed = NO;
static BOOL gDYYYTextOutgoing = NO;
static NSUInteger gDYYYTextConsumeRequests = 0;
static NSArray *gDYYYTextReadStatuses;
static BOOL gDYYYDeferTextQuery = NO;
static void (^gDYYYDeferredTextQuery)(NSArray *);

@interface DYYYWatchOnceTextSource : NSObject
@property(nonatomic, copy) NSDictionary *syncedExtInternal;
@end
@implementation DYYYWatchOnceTextSource
@end

@implementation AWEIMMessage
- (BOOL)sendFromMe { return gDYYYTextOutgoing; }
@end
@implementation AWEIMTextMessage
@end
@implementation AWEIMWatchOnceImageMessage
@end
@implementation AWEIMWatchOnceVideoMessage
@end

@implementation AWEIMWatchOnceTextMessage
@synthesize readState = _readState;
- (BOOL)watchEnd { return gDYYYTextConsumed; }
- (void)setWatchEnd:(BOOL)value { if (value) gDYYYTextConsumed = YES; }
- (void)setReadState:(NSUInteger)value {
    // 实际实现以位标志合并 1/2/4，并在非零时写入 TextWatchEnd。
    _readState |= value;
    if (_readState != 0) [self setWatchEnd:YES];
}
- (void)fillContentWith:(id)message {
    // 实际 fillContentWith: 以 s:once_view_done 的存在性判断服务端已消费。
    if ([message syncedExtInternal][@"s:once_view_done"] != nil) {
        [self setReadState:2];
        [self setWatchEnd:YES];
    }
}
@end

@implementation AWEIMWatchOnceDataManager
- (void)markMessageWatchOnceAlreadyConsume:(id)conversationShortID messageArray:(NSArray *)messages complete:(void (^)(NSNumber *, NSError *))complete {
    gDYYYTextConsumeRequests++;
    if (complete) complete(@0, nil);
}
- (void)fetchWatchOnceTextReadInfo:(NSArray *)messages complete:(void (^)(NSArray *))complete {
    if (gDYYYDeferTextQuery) gDYYYDeferredTextQuery = [complete copy];
    else if (complete) complete(gDYYYTextReadStatuses);
}
@end

@implementation AWEIMAwemeMediaDisplayViewController_WatchOnceImage
- (void)p_fillMessage:(AWEIMWatchOnceImageMessage *)message withContent:(id)detailInfo {}
@end
@implementation AWEIMAwemeMediaDisplayViewController_WatchOnceVideo
- (void)p_fillMessage:(AWEIMWatchOnceVideoMessage *)message withContent:(id)detailInfo {}
@end
@implementation AWEIMWatchOnceImageDetailInfo
@end
@implementation AWEIMWatchOnceVideoDetailInfo
@end

#define CHECK(...) NSCAssert((__VA_ARGS__), @"测试失败：%s", #__VA_ARGS__)

int main(void) {
    @autoreleasepool {
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        id previous = [defaults objectForKey:DYYYKeepWatchOnceMessageKey];
        @try {
            CHECK([DYYYWatchOnceKeepPolicy isRuntimeReady]);
            [defaults setBool:YES forKey:DYYYKeepWatchOnceMessageKey];
            AWEIMWatchOnceDataManager *manager = [AWEIMWatchOnceDataManager new];
            DYYYWatchOnceTextSource *fresh = [DYYYWatchOnceTextSource new];
            fresh.syncedExtInternal = @{};
            gDYYYTextReadStatuses = @[@NO];

            // 反复进出五次，每次使用新消息对象，确保不是仅保住第一次展示的内存对象。
            for (NSUInteger entry = 1; entry <= 5; entry++) {
                AWEIMWatchOnceTextMessage *text = [AWEIMWatchOnceTextMessage new];
                [text fillContentWith:fresh];
                CHECK(!text.watchEnd);
                __block BOOL queried = NO;
                [manager fetchWatchOnceTextReadInfo:@[text] complete:^(NSArray *statuses) {
                    CHECK(![statuses.firstObject boolValue]);
                    queried = YES;
                }];
                CHECK(queried && [DYYYWatchOnceKeepPolicy shouldPreserveMessage:text]);
                [text setReadState:1];
                [text setReadState:2];
                [text setWatchEnd:YES];
                __block BOOL completed = NO;
                [manager markMessageWatchOnceAlreadyConsume:@"test-conversation" messageArray:@[text] complete:^(NSNumber *code, NSError *error) {
                    CHECK(error != nil && code.integerValue < 0);
                    completed = YES;
                }];
                NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2];
                while (!completed && deadline.timeIntervalSinceNow > 0) {
                    [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
                }
                CHECK(completed && gDYYYTextConsumeRequests == 0);
                CHECK(!text.watchEnd && (text.readState & 2) == 0);
            }

            // 请求数组之后被调用方修改，也不能把真实失效结果记到另一条消息上。
            AWEIMWatchOnceTextMessage *requested = [AWEIMWatchOnceTextMessage new];
            AWEIMWatchOnceTextMessage *replacement = [AWEIMWatchOnceTextMessage new];
            NSMutableArray *mutableRequest = [NSMutableArray arrayWithObject:requested];
            gDYYYDeferTextQuery = YES;
            [manager fetchWatchOnceTextReadInfo:mutableRequest complete:^(NSArray *statuses) {}];
            mutableRequest[0] = replacement;
            CHECK(gDYYYDeferredTextQuery != nil);
            gDYYYDeferredTextQuery(@[@YES]);
            gDYYYDeferredTextQuery = nil;
            gDYYYDeferTextQuery = NO;
            CHECK(![DYYYWatchOnceKeepPolicy shouldPreserveMessage:requested]);
            CHECK([DYYYWatchOnceKeepPolicy shouldPreserveMessage:replacement]);

            // 不能把服务端真实不可用状态也挡掉；回调仍接收原始查询结果。
            AWEIMWatchOnceTextMessage *serverEnded = [AWEIMWatchOnceTextMessage new];
            gDYYYTextReadStatuses = @[@YES];
            [manager fetchWatchOnceTextReadInfo:@[serverEnded] complete:^(NSArray *statuses) {
                CHECK(statuses == gDYYYTextReadStatuses);
                [serverEnded setWatchEnd:YES];
                [serverEnded setReadState:2];
            }];
            CHECK(serverEnded.watchEnd && (serverEnded.readState & 2) != 0);

            gDYYYTextConsumed = NO;
            DYYYWatchOnceTextSource *expiredSource = [DYYYWatchOnceTextSource new];
            expiredSource.syncedExtInternal = @{@"s:once_view_done": @"0"};
            AWEIMWatchOnceTextMessage *expired = [AWEIMWatchOnceTextMessage new];
            [expired fillContentWith:expiredSource];
            CHECK(expired.watchEnd && (expired.readState & 2) != 0);

            gDYYYTextConsumed = NO;
            AWEIMWatchOnceTextMessage *recalled = [AWEIMWatchOnceTextMessage new];
            recalled.recalled = YES;
            [recalled setReadState:2];
            CHECK(recalled.watchEnd);

            gDYYYTextConsumed = NO;
            gDYYYTextOutgoing = YES;
            AWEIMWatchOnceTextMessage *outgoing = [AWEIMWatchOnceTextMessage new];
            [outgoing setReadState:2];
            CHECK(outgoing.watchEnd);
            gDYYYTextOutgoing = NO;

            // 关闭开关后恢复原生消费；重新打开不能复活已经写入的消费记录。
            gDYYYTextConsumed = NO;
            [defaults setBool:NO forKey:DYYYKeepWatchOnceMessageKey];
            AWEIMWatchOnceTextMessage *disabled = [AWEIMWatchOnceTextMessage new];
            [disabled setReadState:2];
            CHECK(disabled.watchEnd);
            __block BOOL nativeCompleted = NO;
            [manager markMessageWatchOnceAlreadyConsume:@"test-conversation" messageArray:@[disabled] complete:^(NSNumber *code, NSError *error) {
                CHECK(error == nil && code.integerValue == 0);
                nativeCompleted = YES;
            }];
            CHECK(nativeCompleted && gDYYYTextConsumeRequests == 1);
            [defaults setBool:YES forKey:DYYYKeepWatchOnceMessageKey];
            CHECK(![DYYYWatchOnceKeepPolicy shouldPreserveMessage:disabled]);
            NSLog(@"仅看一次文字：五次聊天对象重建、消费上报与真实失效回归通过；仍需真机验收");
        } @finally {
            if (previous) [defaults setObject:previous forKey:DYYYKeepWatchOnceMessageKey];
            else [defaults removeObjectForKey:DYYYKeepWatchOnceMessageKey];
        }
    }
    return 0;
}
