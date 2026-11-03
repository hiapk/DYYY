#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const DYYYKeepWatchOnceMessageKey;
FOUNDATION_EXPORT NSErrorDomain const DYYYWatchOnceKeepErrorDomain;

// 39.8.0 的专用消费接口回调为 (状态码对象, 错误)，不是 TIMX 请求的 failureBlock。
typedef void (^DYYYWatchOnceConsumeCompletion)(NSNumber *_Nullable statusCode, NSError *_Nullable error);
typedef void (^DYYYWatchOnceConsumeForward)(NSArray *_Nullable messages, DYYYWatchOnceConsumeCompletion _Nullable completion);

@interface DYYYWatchOnceKeepPolicy : NSObject

+ (BOOL)isEnabled;
+ (BOOL)isRuntimeReady;
+ (void)setRuntimeReady:(BOOL)ready;

// 仅处理原生仍判定有效的接收方文字、图片、视频；不改写 getter，也不恢复已经失效的消息。
+ (BOOL)shouldPreserveMessage:(nullable id)message;
+ (BOOL)shouldBlockEndValue:(BOOL)value forMessage:(nullable id)message;
+ (BOOL)shouldBlockResourceClearForMessage:(nullable id)message detailInfo:(nullable id)detailInfo;

// 文字 2/4 状态会结束展示/消费；1 为原生阅读过程，保持原样。
+ (BOOL)shouldBlockTextReadState:(NSUInteger)state forMessage:(nullable id)message;
// 真实服务端失效必须先于原生回调/回填记录，避免被本地消费拦截误挡。
+ (void)recordTextReadStatuses:(nullable NSArray *)statuses forMessages:(nullable NSArray *)messages;
+ (void)observeTextMessage:(id)message sourceMessage:(nullable id)sourceMessage;

// 混合批次继续发送其他消息；只要有被保留的消息，聚合结果就不能伪装为全部消费成功。
+ (void)consumeMessages:(nullable NSArray *)messages
             completion:(nullable DYYYWatchOnceConsumeCompletion)completion
                forward:(DYYYWatchOnceConsumeForward)forward;

// 注册 Hook 前核对 ABI；缺类、缺方法或参数类型改变时整组停用。
+ (BOOL)supportsInstanceMethodOnClass:(nullable Class)cls
                            selector:(SEL)selector
                          returnType:(const char *)returnType
                       argumentTypes:(NSArray<NSString *> *)argumentTypes;

@end

NS_ASSUME_NONNULL_END
